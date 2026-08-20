/**
 * The Firebase Admin app this function acts through, authenticated by
 * Workload Identity Federation rather than by a service-account key.
 *
 * ## What this replaces
 *
 * ADR-036 kept invite-code redemption inside a Cloud Function because "running
 * the Admin SDK outside Google means holding a service-account private key
 * that can grant `admin` on any organisation". Mission 7.6 Phase 2 removed the
 * key rather than accepting it: the Lambda SigV4-signs an STS
 * `GetCallerIdentity` request with the credentials AWS already gave it, Google
 * verifies that signature and reads the caller's role ARN out of it, and no
 * key exists at any point. See A-221.
 *
 * ## Why a NAMED app
 *
 * `@vump/shared`'s `auth.ts` memoises a process-wide default app created with
 * **no credential** — correct there, because verifying a token needs none. It
 * reuses `getApps()[0]`, so whichever app is constructed first wins the
 * default slot.
 *
 * If this function used the default slot, the outcome would depend on
 * construction order rather than on configuration, and the failing case is
 * silent: `createUser` on a credential-less app fails at runtime with an
 * authentication error that names neither cause. A named app cannot collide.
 *
 * ## Why the credential is adapted rather than passed through
 *
 * `firebase-admin`'s `Credential` wants `{access_token, expires_in}`;
 * `google-auth-library`'s `getAccessToken()` returns `{token}` and keeps the
 * expiry on `client.credentials.expiry_date`. The shim below is that
 * translation and nothing more.
 *
 * `applicationDefault()` would also work — it delegates to `GoogleAuth`, which
 * understands external accounts — but only by reading a file named by
 * `GOOGLE_APPLICATION_CREDENTIALS`, and Lambda's only writable directory is
 * `/tmp`. Building the client in code keeps Terraform the single source of the
 * audience and writes nothing to disk.
 */
import { ExternalAccountClient } from 'google-auth-library';
import { getApps, initializeApp, type App, type Credential } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';
import { loadConfig, logger } from '@vump/shared';

/** Distinguishes this app from `@vump/shared`'s credential-less default. */
const APP_NAME = 'redeem';

/**
 * Refreshed a minute early.
 *
 * `expires_in` is consumed by the Admin SDK to decide when to ask again; a
 * value computed from a clock that has already drifted past the real expiry
 * would produce a token rejected on arrival. Reporting slightly less life than
 * the token has costs one extra refresh and cannot produce that.
 */
const EXPIRY_SKEW_MS = 60_000;

let app: App | undefined;

function requireEnv(name: string): string {
  const value = process.env[name];
  if (value === undefined || value.length === 0) {
    // Thrown at cold start rather than at the first Firebase call, so a
    // misconfigured deployment fails on its first request with a message
    // naming the variable instead of a 403 from Identity Toolkit.
    throw new Error(`${name} is not set. Terraform supplies it — see lambda_extra_environment.`);
  }
  return value;
}

/**
 * The external-account configuration, built from Terraform's outputs.
 *
 * **Nothing here is a credential.** The audience names a workload identity
 * pool and the email names a service account; both are inert without an AWS
 * identity whose role ARN satisfies the pool's attribute condition.
 *
 * **Exported for its test, and that is the point rather than a concession.**
 * Every field below is one whose wrongness fails at runtime as a 403 naming
 * neither side — the shape A-222 and A-223 cost a bisection each to find. This
 * is the only part of this module testable without a live token exchange, so
 * it is the only part where a wrong value can be caught before deployment.
 */
export function externalAccountOptions() {
  const audience = requireEnv('GCP_AUDIENCE');
  const serviceAccount = requireEnv('GCP_SERVICE_ACCOUNT_EMAIL');
  const verificationUrl = requireEnv('GCP_STS_VERIFICATION_URL');

  return {
    type: 'external_account',
    audience,
    subject_token_type: 'urn:ietf:params:aws:token-type:aws4_request',
    token_url: 'https://sts.googleapis.com/v1/token',

    // **Required, not optional.** Phase 2 granted the custom role to the
    // SERVICE ACCOUNT and gave the pool principal `roles/iam.workloadIdentityUser`
    // over it. Without this URL the token is the pool principal's own, which
    // holds no permission at all, and the failure surfaces as a 403 from
    // Identity Toolkit that names neither side.
    service_account_impersonation_url: `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${serviceAccount}:generateAccessToken`,

    credential_source: {
      environment_id: 'aws1',

      // `region_url` and `url` are deliberately absent. Both read the EC2
      // metadata server at 169.254.169.254, which **Lambda does not have**.
      // google-auth-library falls back to AWS_ACCESS_KEY_ID,
      // AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN and AWS_REGION, all four of
      // which the execution role populates. Supplying either field would make
      // the client try the metadata server first and hang until it timed out.
      regional_cred_verification_url: verificationUrl,
    },
  };
}

/**
 * Adapts a `google-auth-library` client to the Admin SDK's `Credential`.
 *
 * The client caches and refreshes the federated token itself, so this is
 * called per Firebase request and does an exchange only when the cached token
 * has expired.
 */
function federatedCredential(): Credential {
  const client = ExternalAccountClient.fromJSON(externalAccountOptions());
  if (client === null) {
    // `fromJSON` returns null rather than throwing when the shape is not an
    // external account. Silence here would surface much later as a Firebase
    // permission error.
    throw new Error('The external-account configuration was rejected by google-auth-library.');
  }

  return {
    async getAccessToken() {
      const { token } = await client.getAccessToken();
      if (token === undefined || token === null || token.length === 0) {
        throw new Error('Workload Identity Federation returned no access token.');
      }

      const expiryDate = client.credentials.expiry_date;
      const remainingMs =
        typeof expiryDate === 'number' ? expiryDate - Date.now() - EXPIRY_SKEW_MS : 0;

      return {
        access_token: token,
        // Never negative, and never zero-as-a-lie: a non-positive value makes
        // the SDK treat the token as already expired and ask again, which is
        // the safe direction when the expiry is missing or already past.
        expires_in: Math.max(1, Math.floor(remainingMs / 1000)),
      };
    },
  };
}

/** The Admin SDK app, created once per cold start. */
function firebaseApp(): App {
  if (app !== undefined) {
    return app;
  }

  const existing = getApps().find((candidate) => candidate.name === APP_NAME);
  if (existing !== undefined) {
    app = existing;
    return app;
  }

  logger.info('initialising the federated Firebase app', { app: APP_NAME });

  app = initializeApp(
    {
      credential: federatedCredential(),
      projectId: loadConfig().firebaseProjectId,
    },
    APP_NAME,
  );
  return app;
}

/** Firebase Authentication, acting as the federated service account. */
export function federatedAuth(): Auth {
  return getAuth(firebaseApp());
}
