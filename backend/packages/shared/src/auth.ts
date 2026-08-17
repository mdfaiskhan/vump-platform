/**
 * Firebase ID token verification — Volume 4, Chapter 4.7 §1 step 3 and §4.
 *
 * ## This is real, and it needs no secret
 *
 * ADR-036 line 35 records the asymmetry this rests on:
 *
 * > *"token **verification** does not need this. `verifyIdToken` can be
 * > satisfied with Google's public certificates and no secret at all, which is
 * > why ADR-015's plan to verify on Lambda carries no such exposure. Writing
 * > claims is the operation that needs privilege."*
 *
 * Mission 6.2 **tested that claim rather than trusting it**. Initialising the
 * Admin SDK with a `projectId` and no credential, with `GOOGLE_APPLICATION_
 * CREDENTIALS` explicitly unset, and calling `verifyIdToken` with a well-formed
 * unsigned JWT returns:
 *
 * > `Firebase ID token has "kid" claim which does not correspond to a known
 * > public key.`
 *
 * That error is only reachable **after** the SDK has fetched Google's public
 * certificate set and compared the `kid` against it. Credentials were never the
 * blocker. Recorded as amendment A-149.
 *
 * Two consequences worth stating, because both look like defects otherwise:
 *
 * 1. **All seven functions can verify tokens** with the IAM that Mission 6.1
 *    already applied, even though only `auth-verify` holds a grant on
 *    `vump/dev/firebase-service-account-*`. Chapter 4.7 §1 step 3's *"each
 *    Lambda function verifies the token"* is satisfiable as written.
 * 2. **The certificate fetch is an outbound HTTPS call.** ADR-044's Shape B is
 *    what makes that free: no function joins a VPC, so none needs a NAT gateway
 *    to reach `googleapis.com`. Under the VPC-attached design this call is
 *    exactly what would have forced a NAT.
 */
import { initializeApp, getApps, type App } from 'firebase-admin/app';
import { getAuth, type DecodedIdToken } from 'firebase-admin/auth';
import { ApiError } from './errors.js';
import { loadConfig } from './config.js';

let app: App | undefined;

/**
 * The Admin SDK app, created once per cold start.
 *
 * **No `credential` is passed, deliberately.** Supplying one would require a
 * service-account key this function has no grant to read and does not need.
 */
function firebaseApp(): App {
  if (app !== undefined) {
    return app;
  }
  const existing = getApps();
  app =
    existing.length > 0 && existing[0] !== undefined
      ? existing[0]
      : initializeApp({ projectId: loadConfig().firebaseProjectId });
  return app;
}

/** The caller's identity, as established by the token alone. */
export interface TokenIdentity {
  /** Firebase `uid` — the join key to `users.firebase_uid` (Chapter 4.4). */
  readonly firebaseUid: string;
  /** The `role` custom claim, if the token carries one (Chapter 4.7 §2). */
  readonly roleClaim: string | undefined;
  readonly email: string | undefined;
}

/**
 * Extracts the bearer token from an `Authorization` header.
 *
 * Case-insensitive on the scheme: API Gateway does not normalise header values,
 * and `bearer` is as valid as `Bearer` per RFC 7235.
 */
export function bearerToken(header: string | undefined): string {
  if (header === undefined || header === '') {
    throw ApiError.tokenMissing();
  }
  const match = /^bearer\s+(.+)$/i.exec(header.trim());
  const token = match?.[1]?.trim();
  if (token === undefined || token === '') {
    throw ApiError.tokenMissing();
  }
  return token;
}

/**
 * Verifies [token] — signature, expiry and issuer — and returns its identity.
 *
 * Chapter 4.7 §1 step 3: *"an invalid or expired token is rejected with a 401
 * before any database query runs"*. Nothing in this function touches the
 * database, which is what makes that ordering structural rather than a matter
 * of handler discipline.
 */
export async function verifyToken(token: string): Promise<TokenIdentity> {
  let decoded: DecodedIdToken;
  try {
    decoded = await getAuth(firebaseApp()).verifyIdToken(token);
  } catch (cause) {
    // The SDK's message can name the project and the failure mode. It is not
    // returned to the caller; ApiError carries a fixed message and the cause
    // stays for the log.
    throw ApiError.tokenInvalid(cause);
  }

  // `DecodedIdToken` carries an index signature typed `any`, so a custom claim
  // arrives untyped. Narrowed through `unknown` rather than trusted: the role
  // claim is attacker-adjacent — it comes from a token — and Chapter 4.7 §2
  // treats the `users` table as authoritative where the two disagree.
  const role: unknown = decoded.role;
  return {
    firebaseUid: decoded.uid,
    roleClaim: typeof role === 'string' ? role : undefined,
    email: decoded.email,
  };
}

/** Resets the memoised app. Tests only. */
export function resetFirebaseAppForTest(): void {
  app = undefined;
}
