/**
 * `redeem` — invite-code redemption and account creation.
 *
 * Routes served:
 *
 *   POST /v1/auth/redeem   — exempt from the authorizer, and unauthenticated
 *
 * ## Why this function exists
 *
 * It retires ADR-036's Firebase Cloud Function. That decision put redemption
 * outside AWS for one stated reason — "running the Admin SDK outside Google
 * means holding a service-account private key that can grant `admin` on any
 * organisation" — and Mission 7.6 Phase 2 removed the reason rather than
 * accepting it: this function reaches Firebase through Workload Identity
 * Federation, so no key exists anywhere (A-221).
 *
 * ## Why it is its own function and not a route on `auth-verify`
 *
 * A Lambda has exactly one execution role, and these two need opposite
 * privileges. `auth-verify` holds `SELECT` on `users` and must not be able to
 * create Firebase accounts; this function creates Firebase accounts and must
 * not be able to read `users`. One function would hold both, and the
 * separation would be a convention rather than a boundary — the same reasoning
 * A-143 applies to the chunks domain.
 *
 * ADR-015's six domains are unchanged: this is a second role in the
 * `auth-verify` domain, not a seventh domain.
 *
 * ## Why it is unauthenticated
 *
 * Its caller has no Firebase account — creating one is the point. There is no
 * token to verify and no `users` row to look up, so the REQUEST authorizer
 * would refuse every legitimate caller. ADR-048's Mission 7.6 amendment
 * records the exemption and why the exempt list is a named allowlist rather
 * than a count.
 *
 * **What limits exposure is not authentication.** A-056 made the invite code
 * optional, so it gates nothing. What bounds this route is that self-signup
 * can only ever produce a Collector in an organisation with no Tasks assigned
 * to it.
 *
 * ## The order changed when this moved to Postgres, and it matters
 *
 * The Cloud Function validated the code, created the account, set claims, then
 * spent a use. **This spends the use first.**
 *
 * That order re-opened a race the single-document read could not see: two
 * callers both pass the read on the last remaining use, both create accounts,
 * and the second decrement then violates `remaining_uses >= 0` — leaving an
 * account that exists against no use. Spending first makes the decision and
 * the decrement one statement, so exactly one caller can win.
 *
 * It preserves Mission 2.9's F1 fix rather than undoing it: validation still
 * happens before any account exists, so an invalid code creates nothing and
 * there is no enumeration oracle to observe.
 *
 * **A use spent on a sign-up that then fails is not restored.** A compensating
 * increment is itself a write that can fail, and A-056 made the counter
 * non-load-bearing — a code that admits nobody it would otherwise exclude
 * cannot be meaningfully over-spent. A wasted use is an inconvenience; a
 * half-run compensator is a defect.
 *
 * ## Passwords
 *
 * A password reaches this function. It goes to `createUser` and nowhere else:
 * never logged, never echoed in an error, never written to the database.
 */
import type { APIGatewayProxyEvent } from 'aws-lambda';
import {
  ApiError,
  DEFAULT_ORG_ID,
  createRouter,
  execute,
  logger,
  parseBody,
  readString,
  routeKey,
  textParam,
  withoutAuthentication,
  type HandlerResult,
  type RouteTable,
} from '@vump/shared';
import { federatedAuth } from './firebase.js';

/** Longest code accepted before the database is touched at all. */
const MAX_CODE_LENGTH = 64;

/** Longest address accepted. The practical limit on an email address. */
const MAX_EMAIL_LENGTH = 320;

/** Alphanumeric, after upper-casing. See {@link normaliseCode}. */
const CODE_PATTERN = /^[A-Z0-9]+$/;

/**
 * The role every account created here receives.
 *
 * **One site, a literal, and not negotiable.** No request field, no branch and
 * no invite code can produce an admin; admin remains a manual bootstrap
 * performed outside the application. A-056 relaxed the invite code and did not
 * relax this.
 */
const ROLE = 'collector';

/** What the caller receives. The claims are already on the account. */
interface RedeemResult {
  readonly uid: string;
  readonly orgId: string;
}

interface RedeemRequest {
  readonly email: string;
  readonly password: string;
  readonly code: string | null;
}

/**
 * Validates shape before anything else runs.
 *
 * A code that was **supplied but malformed** is a validation failure; only an
 * absent one is allowed through. Absent and blank both mean "no code" — a
 * caller that omits the field and one that sends an empty string are asking
 * for the same thing, and distinguishing them would be a distinction with no
 * meaning.
 */
function parseRequest(event: APIGatewayProxyEvent): RedeemRequest {
  const body = parseBody(event.body);

  const email = normaliseEmail(body.email);
  const password = typeof body.password === 'string' ? body.password : null;

  const supplied = body.code;
  const hasCode = typeof supplied === 'string' && supplied.trim().length > 0;
  const code = hasCode ? normaliseCode(supplied) : null;

  if (email === null || password === null || password.length === 0 || (hasCode && code === null)) {
    throw new ApiError(
      'REQUEST_INVALID',
      'An email address and password are required, and an invite code must be alphanumeric if supplied.',
      400,
    );
  }

  return { email, password, code };
}

/**
 * Spends one use and returns the organisation the code admits.
 *
 * **One statement, deliberately.** PostgreSQL takes a row-level lock for the
 * duration of the UPDATE, so two concurrent redemptions of the same code
 * serialise and exactly one sees a row to update. SELECT ... FOR UPDATE would
 * hold that lock across two Data API round trips for no additional guarantee.
 *
 * NULL minus 1 is NULL, so an unlimited code stays unlimited and the
 * remaining_uses IS NULL branch needs no special case.
 *
 * expires_at > now() is the SERVER's clock. A device clock is attacker
 * controlled, so an expiry checked on the caller's time is no expiry.
 *
 * Zero rows means missing, expired, or exhausted, and all three answer
 * identically — see ApiError.inviteCodeInvalid.
 */
async function spendOneUse(code: string): Promise<string> {
  const result = await execute(
    `UPDATE org_invite_codes
        SET remaining_uses = remaining_uses - 1
      WHERE code = :code
        AND expires_at > now()
        AND (remaining_uses IS NULL OR remaining_uses > 0)
      RETURNING org_id`,
    { parameters: [textParam('code', code)] },
  );

  const row = result.records?.[0];
  if (row === undefined) {
    throw ApiError.inviteCodeInvalid();
  }
  return readString(row, 0, 'org_id');
}

/** Creates the Firebase account, mapping the Admin SDK's failures. */
async function createAccount(email: string, password: string): Promise<string> {
  try {
    const created = await federatedAuth().createUser({ email, password });
    return created.uid;
  } catch (thrown) {
    const code = (thrown as { code?: string } | null)?.code ?? 'unknown';

    if (code === 'auth/email-already-exists') {
      // F1's fix, restated: a caller who reaches here already supplied an
      // acceptable code, and "that address is taken" is the oracle the
      // validation-first ordering exists to remove.
      throw ApiError.inviteCodeInvalid();
    }
    if (code === 'auth/invalid-email' || code === 'auth/invalid-password') {
      throw new ApiError(
        'REQUEST_INVALID',
        'That email address or password is not acceptable.',
        400,
      );
    }

    // **The message, not just the code.** `app/invalid-credential` is raised
    // by firebase-admin for BOTH a malformed credential object and any error
    // this function's own getAccessToken throws — and the wrapper quotes the
    // original in its message and keeps it on `cause`. Logging the code alone
    // discards the only text that tells those apart, which is what made A-222
    // take a round of reverse-engineering to find. Server-side only; the
    // caller still receives the generic 500 below.
    logger.error('createUser failed', {
      firebaseCode: code,
      cause: thrown instanceof Error ? thrown.message : String(thrown),
    });
    throw new ApiError('INTERNAL_ERROR', 'The account could not be created.', 500, {
      cause: thrown,
    });
  }
}

/**
 * Neutralises an account whose provisioning failed after it was created.
 *
 * **Disabled, not deleted**, and the difference is the security argument of
 * the whole federation. Deleting would need firebaseauth.users.delete, and the
 * custom role Phase 2 built holds exactly users.create and users.update —
 * deliberately, so a leaked or misused federated identity cannot destroy
 * accounts. Adding a delete permission to serve a rare failure branch would
 * trade that property for this line.
 *
 * A disabled account cannot sign in, which is the property the Cloud
 * Function's discard actually needed. What is left behind is visible rather
 * than silent.
 *
 * Best-effort: a failure here is logged and never masks the original error,
 * which is the one that explains what went wrong.
 */
async function disable(uid: string): Promise<void> {
  try {
    await federatedAuth().updateUser(uid, { disabled: true });
  } catch (thrown) {
    logger.error('could not disable a half-provisioned account', {
      uid,
      cause: thrown instanceof Error ? thrown.message : String(thrown),
    });
  }
}

/**
 * Trims and upper-cases, or null when there is nothing usable.
 *
 * Alphanumeric only, and checked before the database is touched — Volume 8
 * §8.3 §2 asks for validation "before touching the database". The character
 * restriction is inherited from the Firestore version, where a slash in a
 * document id was read as a path separator (Mission 2.9's F3). It is kept
 * because it is a sound restriction on a human-typed code, not because a
 * parameterised UPDATE needs it.
 */
function normaliseCode(raw: unknown): string | null {
  if (typeof raw !== 'string') {
    return null;
  }
  const trimmed = raw.trim().toUpperCase();
  if (trimmed.length === 0 || trimmed.length > MAX_CODE_LENGTH) {
    return null;
  }
  return CODE_PATTERN.test(trimmed) ? trimmed : null;
}

function normaliseEmail(raw: unknown): string | null {
  if (typeof raw !== 'string') {
    return null;
  }
  const trimmed = raw.trim();
  return trimmed.length === 0 || trimmed.length > MAX_EMAIL_LENGTH ? null : trimmed;
}

const routes: RouteTable = {
  [routeKey('POST', '/v1/auth/redeem')]: withoutAuthentication(
    'POST /v1/auth/redeem',
    async (event): Promise<HandlerResult<RedeemResult>> => {
      const { email, password, code } = parseRequest(event);

      // Nothing below this line runs for a bad code. Spending the use IS the
      // validation — see the header.
      const orgId = code === null ? DEFAULT_ORG_ID : await spendOneUse(code);

      const uid = await createAccount(email, password);

      try {
        await federatedAuth().setCustomUserClaims(uid, { role: ROLE, org_id: orgId });
      } catch (thrown) {
        await disable(uid);
        throw thrown;
      }

      logger.info('account provisioned', { uid, orgId, usedCode: code !== null });
      return { data: { uid, orgId }, status: 201 };
    },
  ),
};

const router = createRouter('redeem', routes);

export const handler = async (event: unknown): Promise<unknown> =>
  router(event as APIGatewayProxyEvent);
