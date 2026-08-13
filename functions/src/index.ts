/**
 * Organisation invite-code redemption and account creation.
 *
 * **TEMPORARY INFRASTRUCTURE — retired at Mission 6/7. See ADR-036.**
 *
 * ADR-015 fixes the backend runtime as AWS Lambda behind API Gateway. This is
 * a Firebase Cloud Function, and the contradiction is deliberate and recorded:
 * writing a Firebase custom claim needs a credential that can act on the
 * project, and running the Admin SDK outside Google means holding a
 * service-account private key. That key could grant `admin` on any
 * organisation to any account, and a leak would be a silent, total
 * authorization bypass. Inside Cloud Functions the runtime authenticates
 * through the metadata server, so no such key ever exists.
 *
 * ## The order matters, and it changed
 *
 * Mission 2.9's security review (F1) found that creating the account before
 * validating the code let an unauthenticated caller enumerate registered email
 * addresses: a taken address failed differently from a free one, and no valid
 * code was needed to ask. **The code is validated first now.** An invalid or
 * expired code creates nothing, so there is nothing to delete and nothing to
 * tell apart — the caller gets one error either way.
 *
 * ## The invite code is optional
 *
 * Amendment A-056: without a code an account joins `DEFAULT_ORG_ID`; with one
 * it joins that code's organisation and spends a use, exactly as before. The
 * project's distribution is informal APK sharing among a trusted group, so a
 * code everybody already has admits nobody it would otherwise exclude.
 *
 * **The role is `collector` on every path, and that is not negotiable here.**
 * It is set at one site below, from a literal. No request field, no branch and
 * no invite code can produce an admin; admin remains a manual bootstrap
 * performed outside the application.
 *
 * ## Unauthenticated, deliberately
 *
 * There is no `request.auth` here because there is no account yet. The
 * original design took the uid from the verified context so a client could
 * never name the account to provision; that property is stronger now rather
 * than weaker, because the function chooses the identity itself.
 *
 * ~~The invite code is the credential gating this endpoint.~~ **A-056: the
 * code is optional and no longer gates anything.** What limits exposure now
 * is that self-signup can only ever produce a Collector in an organisation
 * with no Tasks assigned to it.
 *
 * ## Passwords
 *
 * A password reaches this function. It goes to `createUser` and nowhere else:
 * never logged, never echoed in an error, never written to Firestore.
 */

import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";

if (getApps().length === 0) {
  initializeApp();
}

/** Where the codes live. Document ID is the code itself. */
const COLLECTION = "org_invite_codes";

/** asia-south1, matching ADR-011's ap-south-1 and the Firestore location. */
const REGION = "asia-south1";

/** Longest code accepted before Firestore is touched at all. */
const MAX_CODE_LENGTH = 64;

/**
 * The organisation an account joins when no invite code is supplied.
 *
 * A literal, deliberately. `org_id` is consumed in exactly two ways today: as
 * an opaque string on the mobile `User`, and as an equality comparison in
 * `firestore.rules`. Nothing looks an organisation up, no `orgs` collection
 * exists, and no code reads one as a structured record — so a Firestore
 * document representing an organisation nothing queries would be structure
 * ahead of need. See amendment A-056.
 *
 * When a real organisation model arrives (Volume 4 Ch. 4.4's `users` table),
 * this constant becomes a row.
 */
const DEFAULT_ORG_ID = "vump-default";

/**
 * `ErrorCode` values from `mobile/lib/core/errors/error_codes.dart`.
 *
 * Carried in `HttpsError.details` rather than in its `code`, because a
 * callable's code is drawn from a fixed gRPC set that cannot express this
 * taxonomy.
 */
const ErrorCode = {
  inviteCodeInvalid: "AUTH_INVITE_CODE_INVALID",
  inviteCodeExpired: "AUTH_INVITE_CODE_EXPIRED",
  validationInvalidInput: "VALIDATION_INVALID_INPUT",
  unknown: "UNKNOWN",
} as const;

interface RedeemRequest {
  /** Optional since A-056. Absent means the default organisation. */
  code?: unknown;
  email?: unknown;
  password?: unknown;
}

interface CodeDocument {
  orgId?: unknown;
  expiresAt?: unknown;
  remainingUses?: unknown;
}

/**
 * Validates an invite code and, only then, creates the account it admits.
 *
 * Returns `{uid, orgId}`. The caller signs in afterwards with the same
 * credentials to obtain a session; the claims are already on the account, so
 * the first token it receives carries them.
 */
export const redeemInviteCode = onCall(
  {region: REGION, enforceAppCheck: false},
  async (request) => {
    const body = request.data as RedeemRequest | undefined;

    const email = normaliseEmail(body?.email);
    const password = typeof body?.password === "string" ? body.password : null;

    // Absent and blank both mean "no code". A caller that omits the field and
    // one that sends an empty string are asking for the same thing, and
    // treating them differently would be a distinction with no meaning.
    const supplied = body?.code;
    const hasCode = typeof supplied === "string" && supplied.trim().length > 0;
    const code = hasCode ? normaliseCode(supplied) : null;

    // Shape is checked before anything else. A code that was supplied but is
    // malformed is still a validation failure — only an absent one is allowed
    // through.
    if (email === null || password === null || password.length === 0 ||
        (hasCode && code === null)) {
      throw new HttpsError(
        "invalid-argument",
        "An email address and password are required, and an invite code " +
          "must be alphanumeric if supplied.",
        {errorCode: ErrorCode.validationInvalidInput},
      );
    }

    // Validate first when there is something to validate. Nothing below this
    // line runs for a bad code, which is what closes F1: there is no
    // account-creation attempt to observe. Without a code there is nothing to
    // reject, so the default organisation is used and no use is spent.
    const orgId = code === null ? DEFAULT_ORG_ID : await readValidCode(code);

    let uid: string;
    try {
      const created = await getAuth().createUser({email, password});
      uid = created.uid;
    } catch (error) {
      throw fromCreateUserError(error);
    }

    try {
      // The single site that assigns a role, and it is a literal. A-056
      // relaxed the invite code; it did not relax this.
      await getAuth().setCustomUserClaims(uid, {
        role: "collector",
        org_id: orgId,
      });
      if (code !== null) {
        await consumeOneUse(code);
      }
    } catch (error) {
      // The account exists but is not usable — no claims, or a use that was
      // not recorded. This is the one place a compensating delete still
      // belongs, and it is inside the failure path rather than around the
      // whole flow.
      await discard(uid);
      throw error;
    }

    logger.info("Account provisioned", {uid, orgId, usedCode: code !== null});
    return {uid, orgId};
  },
);

/**
 * Reads a code and rejects it if it is missing, expired or exhausted.
 *
 * Deliberately separate from consuming it. The read decides whether an account
 * may be created; the decrement happens after the account exists, so a use is
 * never spent on a sign-up that then failed to produce anything.
 */
async function readValidCode(code: string): Promise<string> {
  const snapshot = await getFirestore()
    .collection(COLLECTION)
    .doc(code)
    .get();

  if (!snapshot.exists) {
    throw invalidCode();
  }

  const data = snapshot.data() as CodeDocument;

  const orgId = data.orgId;
  if (typeof orgId !== "string" || orgId.length === 0) {
    logger.error("Invite code document has no orgId", {code});
    throw misconfigured();
  }

  // Compared against the server's clock. A device clock is attacker
  // controlled, so an expiry checked on the caller's time is no expiry.
  const expiresAt = data.expiresAt;
  if (!(expiresAt instanceof Timestamp)) {
    logger.error("Invite code document has no usable expiresAt", {code});
    throw misconfigured();
  }
  if (expiresAt.toMillis() <= Date.now()) {
    throw new HttpsError(
      "failed-precondition",
      "This invite code has expired.",
      {errorCode: ErrorCode.inviteCodeExpired},
    );
  }

  const remainingUses = data.remainingUses;

  // Null means unlimited, matching Mission 2.1's OrgInviteCode.
  if (remainingUses === null || remainingUses === undefined) {
    return orgId;
  }
  if (typeof remainingUses !== "number" || !Number.isInteger(remainingUses)) {
    logger.error("Invite code has a non-integer remainingUses", {code});
    throw misconfigured();
  }
  if (remainingUses <= 0) {
    // Reported as invalid rather than as its own condition: telling a caller
    // a code exists but is used up confirms the code exists.
    throw invalidCode();
  }

  return orgId;
}

/**
 * Spends one use, transactionally.
 *
 * The read happens inside the transaction even though `readValidCode` has
 * already looked: two sign-ups racing for the last use must not both succeed,
 * and only a transactional re-read can decide that. The earlier read gates
 * account creation; this one gates the decrement.
 */
async function consumeOneUse(code: string): Promise<void> {
  const reference = getFirestore().collection(COLLECTION).doc(code);

  await getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) {
      throw invalidCode();
    }

    const remainingUses = (snapshot.data() as CodeDocument).remainingUses;
    if (remainingUses === null || remainingUses === undefined) {
      return;
    }
    if (typeof remainingUses !== "number" || remainingUses <= 0) {
      throw invalidCode();
    }

    transaction.update(reference, {remainingUses: FieldValue.increment(-1)});
  });
}

/** Removes an account whose provisioning failed after it was created. */
async function discard(uid: string): Promise<void> {
  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    logger.error("Could not remove a half-provisioned account", {uid, error});
  }
}

/**
 * Maps an Admin SDK `createUser` failure.
 *
 * **`email-already-exists` is reported as an invalid code, deliberately.**
 * That is the whole of F1's fix: a caller who reaches this point already
 * supplied a valid code, and telling them the address is taken would hand back
 * the enumeration oracle the validation-first ordering just removed. The
 * account is not created either way, and an admin can tell a genuine returning
 * user to sign in instead.
 */
function fromCreateUserError(error: unknown): HttpsError {
  const code = (error as {code?: string} | null)?.code ?? "";

  if (code === "auth/email-already-exists") {
    return invalidCode();
  }
  if (code === "auth/invalid-email" || code === "auth/invalid-password") {
    return new HttpsError(
      "invalid-argument",
      "That email address or password is not acceptable.",
      {errorCode: ErrorCode.validationInvalidInput},
    );
  }

  logger.error("createUser failed", {code});
  return new HttpsError("internal", "The account could not be created.", {
    errorCode: ErrorCode.unknown,
  });
}

/** Covers "no such code", "no uses left", and "that address is taken". */
function invalidCode(): HttpsError {
  return new HttpsError(
    "not-found",
    "This invite code is not valid.",
    {errorCode: ErrorCode.inviteCodeInvalid},
  );
}

function misconfigured(): HttpsError {
  return new HttpsError(
    "internal",
    "This invite code is not configured correctly.",
    {errorCode: ErrorCode.unknown},
  );
}

/**
 * Trims and upper-cases, or null when there is nothing usable.
 *
 * Length and character set are checked here, before Firestore is touched —
 * Volume 8 §8.3 §2 asks for validation "before touching the database", and a
 * document ID containing a slash is a path rather than a key (Mission 2.9's
 * finding F3).
 */
function normaliseCode(raw: unknown): string | null {
  if (typeof raw !== "string") {
    return null;
  }
  const trimmed = raw.trim().toUpperCase();
  if (trimmed.length === 0 || trimmed.length > MAX_CODE_LENGTH) {
    return null;
  }
  // Alphanumeric only. Rejects "/" and "." before they reach `.doc()`, where
  // they would be read as path segments instead of as a key.
  return /^[A-Z0-9]+$/.test(trimmed) ? trimmed : null;
}

function normaliseEmail(raw: unknown): string | null {
  if (typeof raw !== "string") {
    return null;
  }
  const trimmed = raw.trim();
  return trimmed.length === 0 || trimmed.length > 320 ? null : trimmed;
}
