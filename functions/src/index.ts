/**
 * Organisation invite-code redemption.
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
 * When the real backend lands this becomes a `/v1/...` route and this file is
 * deleted. What must survive the port: the transaction, the server-derived
 * uid, and the ordering of the two writes. Nothing else belongs in this
 * runtime — it is one function doing one job, not a backend.
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

/**
 * `ErrorCode` values from `mobile/lib/core/errors/error_codes.dart`.
 *
 * Carried in `HttpsError.details` rather than in its `code`, because a
 * callable's code is drawn from a fixed gRPC set that cannot express this
 * taxonomy. The mobile side reads `details.errorCode` and maps it; the gRPC
 * code is left meaningful for anything that only understands that.
 */
const ErrorCode = {
  inviteCodeInvalid: "AUTH_INVITE_CODE_INVALID",
  inviteCodeExpired: "AUTH_INVITE_CODE_EXPIRED",
  unauthenticated: "AUTH_UNAUTHENTICATED",
  validationInvalidInput: "VALIDATION_INVALID_INPUT",
  unknown: "UNKNOWN",
} as const;

interface RedeemRequest {
  code?: unknown;
}

interface CodeDocument {
  orgId?: unknown;
  expiresAt?: unknown;
  remainingUses?: unknown;
}

/**
 * Validates an invite code, consumes one use, and provisions the caller.
 *
 * The caller's uid comes from the verified auth context and never from the
 * request body. Accepting one as a parameter would let any signed-in account
 * provision claims for any other — the rule Volume 4 Chapter 4.7 §2 states as
 * "a client can never claim its own role", applied at the only other point
 * where claims are written.
 */
export const redeemInviteCode = onCall(
  {region: REGION, enforceAppCheck: false},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in before redeeming an invite code.",
        {errorCode: ErrorCode.unauthenticated},
      );
    }

    const code = normaliseCode((request.data as RedeemRequest | undefined)?.code);
    if (code === null) {
      throw new HttpsError(
        "invalid-argument",
        "An invite code is required.",
        {errorCode: ErrorCode.validationInvalidInput},
      );
    }

    const orgId = await consumeOneUse(code);

    // Deliberately after the transaction commits, and the ordering is a real
    // trade-off rather than an oversight. setCustomUserClaims is not a
    // Firestore operation and cannot join the transaction, so the two writes
    // cannot be atomic. Claims-first fails open — membership granted on a code
    // that then fails to decrement. This fails closed: a use is consumed and
    // nobody is added, which an admin fixes by issuing another code.
    await getAuth().setCustomUserClaims(uid, {role: "collector", org_id: orgId});

    // The claim reaches the client on its next token refresh, not on the token
    // it is holding now. The caller must force one before reading its own
    // role — see AuthRepositoryImpl.
    logger.info("Invite code redeemed", {uid, orgId});

    return {orgId};
  },
);

/**
 * Runs the check-and-decrement as one Firestore transaction.
 *
 * The read must happen inside the transaction. Reading first and writing after
 * would let two people redeeming the last use both observe `remainingUses: 1`
 * and both succeed; inside a transaction Firestore aborts and retries when the
 * document changed underneath, which is what makes check-then-write atomic
 * rather than merely adjacent.
 */
async function consumeOneUse(code: string): Promise<string> {
  const reference = getFirestore().collection(COLLECTION).doc(code);

  return getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);

    if (!snapshot.exists) {
      throw invalidCode();
    }

    const data = snapshot.data() as CodeDocument;

    const orgId = data.orgId;
    if (typeof orgId !== "string" || orgId.length === 0) {
      // A malformed document is this side's fault, not the caller's, so it is
      // logged as such rather than reported as a bad code.
      logger.error("Invite code document has no orgId", {code});
      throw new HttpsError(
        "internal",
        "This invite code is not configured correctly.",
        {errorCode: ErrorCode.unknown},
      );
    }

    // Compared against the server's clock. A device clock is attacker
    // controlled, so an expiry checked on the caller's time is no expiry.
    const expiresAt = data.expiresAt;
    if (!(expiresAt instanceof Timestamp)) {
      logger.error("Invite code document has no usable expiresAt", {code});
      throw new HttpsError(
        "internal",
        "This invite code is not configured correctly.",
        {errorCode: ErrorCode.unknown},
      );
    }
    if (expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError(
        "failed-precondition",
        "This invite code has expired.",
        {errorCode: ErrorCode.inviteCodeExpired},
      );
    }

    const remainingUses = data.remainingUses;

    // Null means unlimited, matching Mission 2.1's OrgInviteCode, where the
    // field is nullable precisely so that is expressible. Treating null as
    // zero would silently make every unlimited code dead on arrival.
    if (remainingUses === null || remainingUses === undefined) {
      return orgId;
    }

    if (typeof remainingUses !== "number" || !Number.isInteger(remainingUses)) {
      logger.error("Invite code has a non-integer remainingUses", {code});
      throw new HttpsError(
        "internal",
        "This invite code is not configured correctly.",
        {errorCode: ErrorCode.unknown},
      );
    }

    if (remainingUses <= 0) {
      // Reported as invalid rather than as its own condition. Telling a caller
      // that a code exists but is used up confirms the code exists, which is
      // the enumeration signal the read rule denies.
      throw invalidCode();
    }

    transaction.update(reference, {
      remainingUses: FieldValue.increment(-1),
    });

    return orgId;
  });
}

/** Covers both "no such code" and "no uses left" — see the call sites. */
function invalidCode(): HttpsError {
  return new HttpsError(
    "not-found",
    "This invite code is not valid.",
    {errorCode: ErrorCode.inviteCodeInvalid},
  );
}

/** Trims and upper-cases, or null when there is nothing usable. */
function normaliseCode(raw: unknown): string | null {
  if (typeof raw !== "string") {
    return null;
  }
  const trimmed = raw.trim().toUpperCase();
  return trimmed.length === 0 ? null : trimmed;
}
