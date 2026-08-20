/**
 * Resolving a verified token into the caller's `users` row.
 *
 * ## Which half of Chapter 4.7 this is
 *
 * Chapter 4.7 appears to contradict itself. §1 step 4 says the backend *"looks
 * up (**or creates, on first login**) the matching users row"*; §4's
 * pseudocode says `user = db.users.findByFirebaseUid(...)` /
 * `if user is null: reject(401)`.
 *
 * ADR-048 resolves it by observing that the two describe **different
 * components**, not competing behaviours:
 *
 *   - {@link lookupCaller} is §4's pseudocode. It reads, and refuses when the
 *     row is absent. This is what the Lambda authorizer runs, in front of
 *     fourteen of the fifteen routes.
 *   - {@link provisionCaller} is §1 step 4's *"or creates"*. It runs **only**
 *     in `POST /v1/auth/verify`, which is exempt from the authorizer precisely
 *     so that a first-time caller has one door that is not locked against
 *     them.
 *
 * Applying "reject" uniformly would have deadlocked the platform: four live
 * Firebase accounts existed, `users` was empty, nothing else wrote to it, and
 * `redeemInviteCode` created Firebase accounts without an Aurora row. Every
 * account — existing and future — would have been refused at every door
 * including the one meant to let them in. A-166.
 *
 * **The function is gone since Mission 7.6 and the argument is unchanged.**
 * `POST /v1/auth/redeem` likewise creates a Firebase account without an Aurora
 * row — deliberately, because `provisionCaller` below is what writes that row
 * on first sign-in (A-226 proved the sequence on a device). The deadlock this
 * paragraph describes is therefore still the one being avoided; only the
 * runtime creating the accounts has changed.
 */
import { execute } from './data-api.js';
import { ApiError } from './errors.js';
import { resolveOrgId } from './org.js';
import type { TokenIdentity } from './auth.js';

/** The caller, once both the token and the `users` row are known. */
export interface ResolvedCaller {
  readonly userId: string;
  readonly orgId: string;
  readonly role: string;
}

/** Reads the three fields a `users` row contributes to the request context. */
function readRow(record: readonly { stringValue?: string }[]): ResolvedCaller {
  const [id, orgId, role] = record;
  if (
    id?.stringValue === undefined ||
    orgId?.stringValue === undefined ||
    role?.stringValue === undefined
  ) {
    // A NOT NULL column came back null, which means the query and the schema
    // disagree. Failing loudly beats returning a half-built caller.
    throw new Error('users row is missing a NOT NULL column');
  }
  return { userId: id.stringValue, orgId: orgId.stringValue, role: role.stringValue };
}

/**
 * Chapter 4.7 §4: look the caller up, and refuse if there is no row.
 *
 * Never creates. The authorizer runs this, and an authorizer that writes is a
 * side effect on a path API Gateway may cache and may replay.
 *
 * @throws {ApiError} 401 `AUTH_USER_NOT_FOUND` when no row matches.
 */
export async function lookupCaller(identity: TokenIdentity): Promise<ResolvedCaller> {
  const found = await execute('SELECT id, org_id, role FROM users WHERE firebase_uid = :uid', {
    parameters: [{ name: 'uid', value: { stringValue: identity.firebaseUid } }],
  });

  const record = found.records?.[0];
  if (record === undefined) {
    throw ApiError.userNotFound();
  }
  return readRow(record);
}

/**
 * Chapter 4.7 §1 step 4: look the caller up, creating the row on first login.
 *
 * The insert is the narrowest one the schema allows. `role` comes from the
 * token's own custom claim, which Chapter 4.7 §2 sets *"at account
 * provisioning time… a client can never claim its own role"*; `org_id` comes
 * from {@link resolveOrgId}, which maps the legacy literal and **refuses**
 * anything it does not recognise rather than defaulting.
 *
 * `ON CONFLICT (firebase_uid) DO NOTHING` plus a re-read makes two concurrent
 * first logins converge on one row instead of one of them failing on the
 * unique constraint. The re-read is what returns the winner's id, whichever
 * request created it.
 */
export async function provisionCaller(identity: TokenIdentity): Promise<ResolvedCaller> {
  const role = identity.roleClaim;
  if (role !== 'admin' && role !== 'collector') {
    // Not a defaultable condition. Guessing `collector` would grant an
    // identity that provisioning never issued — the same reasoning
    // `AuthRepositoryImpl._toUser` applies on the device.
    throw ApiError.userNotFound();
  }

  const orgId = resolveOrgId(identity.orgIdClaim);
  const email = identity.email;
  if (email === undefined || email.length === 0) {
    throw ApiError.userNotFound();
  }

  await execute(
    `INSERT INTO users (org_id, email, firebase_uid, role)
     VALUES (:orgId::uuid, :email, :uid, :role)
     ON CONFLICT (firebase_uid) DO NOTHING`,
    {
      parameters: [
        { name: 'orgId', value: { stringValue: orgId } },
        { name: 'email', value: { stringValue: email } },
        { name: 'uid', value: { stringValue: identity.firebaseUid } },
        { name: 'role', value: { stringValue: role } },
      ],
    },
  );

  return lookupCaller(identity);
}
