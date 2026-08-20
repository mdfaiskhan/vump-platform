import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

const verifyIdToken = vi.fn();
const initializeApp = vi.fn((_options?: unknown) => ({ name: '[DEFAULT]' }));
const getApps = vi.fn(() => [] as unknown[]);

vi.mock('firebase-admin/app', () => ({
  initializeApp: (options: unknown) => initializeApp(options),
  getApps: () => getApps(),
}));

vi.mock('firebase-admin/auth', () => ({
  getAuth: () => ({ verifyIdToken }),
}));

const { verifyToken, resetFirebaseAppForTest, resetConfigForTest } = await import('./index.js');

/**
 * `verifyToken` — the half of `auth.ts` that `bearerToken`'s tests do not reach.
 *
 * Written at Mission 7.9 because the coverage gate found `auth.ts` at 38.88%,
 * with every uncovered line in this function and the memoised app beneath it.
 * The Admin SDK is mocked at the module boundary, which is the same shape
 * `handler.test.ts` uses to mock this module in turn.
 *
 * **`handler.test.ts` mocks `./auth.js` wholesale**, so nothing anywhere
 * exercised this function's own behaviour — the claim narrowing, the error
 * conversion, or the memoisation. Three properties, each load-bearing, none
 * asserted until now.
 */
const ENV = {
  APP_ENV: 'development',
  AWS_REGION: 'ap-south-1',
  CHUNK_BUCKET: 'vump-platform-dev',
  PRESIGN_EXPIRY_SECONDS: '3600',
  DATABASE_CLUSTER_ARN: 'arn:aws:rds:ap-south-1:000000000000:cluster:x',
  DATABASE_CREDENTIALS_SECRET_ARN: 'arn:aws:secretsmanager:ap-south-1:0:secret:x',
  DATABASE_NAME: 'vump_dev',
  FIREBASE_PROJECT_ID: 'vump-platform-f86af',
  UPLOAD_FUNCTION_NAME: 'vump-dev-chunks-upload',
};

beforeEach(() => {
  Object.assign(process.env, ENV);
  resetConfigForTest();
  resetFirebaseAppForTest();
  verifyIdToken.mockReset();
  initializeApp.mockClear();
  getApps.mockReturnValue([]);
});

afterEach(() => {
  for (const key of Object.keys(ENV)) {
    process.env[key] = undefined;
  }
});

describe('verifyToken', () => {
  it('returns the identity a valid token carries', async () => {
    verifyIdToken.mockResolvedValue({
      uid: 'firebase-uid',
      role: 'collector',
      org_id: 'org-42',
      email: 'someone@example.com',
    });

    await expect(verifyToken('a.b.c')).resolves.toEqual({
      firebaseUid: 'firebase-uid',
      roleClaim: 'collector',
      orgIdClaim: 'org-42',
      email: 'someone@example.com',
    });
  });

  it('narrows a non-string role claim to undefined rather than passing it on', async () => {
    // `DecodedIdToken`'s index signature is typed `any`, so a custom claim
    // arrives untyped. The claim is attacker-adjacent — it comes from a token
    // — and a number or an object reaching `provisionCaller` as a role would
    // be a type the rest of the system never checks again.
    for (const role of [42, { admin: true }, null, undefined, ['admin']]) {
      verifyIdToken.mockResolvedValue({ uid: 'u', role, org_id: 'o' });
      const identity = await verifyToken('a.b.c');
      expect(identity.roleClaim).toBeUndefined();
    }
  });

  it('passes org_id through without narrowing it', async () => {
    // Deliberately unlike `role`: `orgIdClaim` is typed `unknown` and
    // `resolveOrgId` is what refuses an unusable value. Narrowing here would
    // put the refusal in two places and make one of them silent.
    verifyIdToken.mockResolvedValue({ uid: 'u', org_id: 99 });
    await expect(verifyToken('a.b.c')).resolves.toMatchObject({
      orgIdClaim: 99,
    });
  });

  it('converts an SDK failure to AUTH_TOKEN_INVALID', async () => {
    verifyIdToken.mockRejectedValue(new Error('Firebase ID token has expired'));

    await expect(verifyToken('a.b.c')).rejects.toMatchObject({
      code: 'AUTH_TOKEN_INVALID',
      status: 401,
    });
  });

  it('does not leak the SDK message to the caller', async () => {
    // The property the code comments on: the SDK's message can name the
    // project and the failure mode. It stays on `cause` for the log.
    const cause = new Error(
      'Firebase ID token has incorrect "aud" claim. Expected ' +
        '"vump-platform-f86af" but got "attacker-project".',
    );
    verifyIdToken.mockRejectedValue(cause);

    await expect(verifyToken('a.b.c')).rejects.toMatchObject({
      message: 'The bearer token is not valid.',
    });
    await expect(verifyToken('a.b.c')).rejects.toMatchObject({ cause });
  });

  it('initialises the Admin app once across many verifications', async () => {
    // A cold start pays this; every request after it must not. The app is
    // memoised in module scope, and nothing asserted that until now.
    verifyIdToken.mockResolvedValue({ uid: 'u' });

    await verifyToken('a.b.c');
    await verifyToken('d.e.f');
    await verifyToken('g.h.i');

    expect(initializeApp).toHaveBeenCalledTimes(1);
  });

  it('adopts an app another module already created', async () => {
    // `redeem` initialises a NAMED app for its federated credential while this
    // one wants the default. If a default already exists, creating a second is
    // an error from the SDK — so this branch is what keeps the two coexisting.
    getApps.mockReturnValue([{ name: '[DEFAULT]' }]);
    verifyIdToken.mockResolvedValue({ uid: 'u' });

    await verifyToken('a.b.c');

    expect(initializeApp).not.toHaveBeenCalled();
  });
});
