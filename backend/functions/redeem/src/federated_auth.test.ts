import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { Credential } from 'firebase-admin/app';

// The three modules the federation path talks to. Mocking them is what makes
// the path reachable at all: `federatedCredential` and `firebaseApp` are not
// exported, and Mission 8.1 does not export them, because a test that needs a
// production change to exist is a test shaping the code around the instrument.
//
// They are reached the way production reaches them — through `federatedAuth()`
// — and the credential is captured from the object `initializeApp` receives.
const initializeApp = vi.fn();
const getApps = vi.fn();
const getAuth = vi.fn();
const fromJSON = vi.fn();

vi.mock('firebase-admin/app', () => ({ initializeApp, getApps }));
vi.mock('firebase-admin/auth', () => ({ getAuth }));
vi.mock('google-auth-library', () => ({ ExternalAccountClient: { fromJSON } }));
vi.mock('@vump/shared', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@vump/shared')>();
  return {
    ...actual,
    loadConfig: () => ({ firebaseProjectId: 'vump-platform-f86af' }),
  };
});

const ENV = {
  GCP_AUDIENCE: '//iam.googleapis.com/projects/1/locations/global/x/providers/y',
  GCP_SERVICE_ACCOUNT_EMAIL: 'redeem@example.iam.gserviceaccount.com',
  GCP_STS_VERIFICATION_URL: 'https://sts.ap-south-1.amazonaws.com?Action=GetCallerIdentity',
};

/** A fresh module instance, because `app` is memoised at module scope. */
async function loadModule() {
  vi.resetModules();
  return import('./firebase.js');
}

function client(overrides: Record<string, unknown> = {}) {
  return {
    getAccessToken: vi.fn().mockResolvedValue({ token: 'ya29-not-a-real-token' }),
    credentials: { expiry_date: Date.now() + 300_000 },
    ...overrides,
  };
}

/** The credential object `firebaseApp()` handed to `initializeApp`. */
/**
 * Narrows a value TypeScript cannot prove is present, and fails loudly.
 *
 * `noUncheckedIndexedAccess` makes every index access `T | undefined`, and
 * `@typescript-eslint/no-non-null-assertion` forbids `!`. Optional chaining
 * covers most sites here because the expected value is a literal, so an
 * absent value fails the assertion anyway. It does NOT cover comparing two
 * possibly-absent values — `expect(a?.x).toBe(b?.x)` passes when both are
 * undefined, which would quietly weaken the test. This throws instead.
 */
function defined<T>(value: T | undefined, what: string): T {
  if (value === undefined) {
    throw new Error(`expected ${what} to be defined`);
  }
  return value;
}

function capturedCredential(): Credential {
  return (defined(initializeApp.mock.calls[0], 'the initializeApp call')[0] as {
    credential: Credential;
  }).credential;
}

beforeEach(() => {
  vi.clearAllMocks();
  Object.assign(process.env, ENV);
  getApps.mockReturnValue([]);
  initializeApp.mockReturnValue({ name: 'redeem' });
  getAuth.mockReturnValue({ createUser: vi.fn() });
  fromJSON.mockReturnValue(client());
  vi.spyOn(console, 'log').mockImplementation(() => undefined);
});

afterEach(() => {
  for (const key of Object.keys(ENV)) {
    Reflect.deleteProperty(process.env, key);
  }
  vi.restoreAllMocks();
});

/**
 * `federatedAuth()` and the credential it builds — the half of `firebase.ts`
 * the coverage gate exempted at 40% because *"the remainder is the live token
 * exchange, which no unit test can reach"*.
 *
 * That remains true of the exchange itself. What is reachable, and was never
 * tested, is everything around it: the memoised app, the reuse of an
 * already-initialised one, the rejection when `fromJSON` refuses the config,
 * and the expiry arithmetic — which is the piece that fails silently. An
 * `expires_in` computed without the skew hands firebase-admin a token it
 * believes is valid for a minute longer than it is, and the symptom is an
 * intermittent 401 on a route that provisions accounts.
 */
describe('federatedAuth — the app', () => {
  it('initialises a named app rather than the default one', async () => {
    // shared/auth.ts holds a credential-less default app. Initialising into
    // it would have the two fight over one name.
    const { federatedAuth } = await loadModule();

    federatedAuth();

    expect(initializeApp).toHaveBeenCalledTimes(1);
    expect(initializeApp.mock.calls[0]?.[1]).toBe('redeem');
    expect(initializeApp.mock.calls[0]?.[0]).toMatchObject({
      projectId: 'vump-platform-f86af',
    });
  });

  it('memoises, so a warm container initialises once', async () => {
    const { federatedAuth } = await loadModule();

    federatedAuth();
    federatedAuth();
    federatedAuth();

    expect(initializeApp).toHaveBeenCalledTimes(1);
    expect(getAuth).toHaveBeenCalledTimes(3);
  });

  it('adopts an app the runtime already holds under the same name', async () => {
    // A second module instance in one container would otherwise throw
    // `app/duplicate-app` on the second initialise.
    const existing = { name: 'redeem' };
    getApps.mockReturnValue([{ name: '[DEFAULT]' }, existing]);

    const { federatedAuth } = await loadModule();
    federatedAuth();

    expect(initializeApp).not.toHaveBeenCalled();
    expect(getAuth).toHaveBeenCalledWith(existing);
  });

  it('refuses when google-auth-library rejects the configuration', async () => {
    // `fromJSON` returns null rather than throwing, so an unchecked call
    // would hand `undefined` to initializeApp and fail much later, as the
    // `app/invalid-credential` that cost A-222 a round of reverse-engineering.
    fromJSON.mockReturnValue(null);

    const { federatedAuth } = await loadModule();

    expect(() => federatedAuth()).toThrow(/rejected by google-auth-library/);
  });
});

describe('federatedAuth — the credential it builds', () => {
  it('returns the access token the exchange produced', async () => {
    const { federatedAuth } = await loadModule();
    federatedAuth();

    const token = await capturedCredential().getAccessToken();

    expect(token.access_token).toBe('ya29-not-a-real-token');
  });

  it('subtracts the skew, so the token is treated as expiring early', async () => {
    // 300s of real life, minus the 60s skew, is 240s of claimed validity.
    fromJSON.mockReturnValue(client({ credentials: { expiry_date: Date.now() + 300_000 } }));

    const { federatedAuth } = await loadModule();
    federatedAuth();

    const token = await capturedCredential().getAccessToken();

    expect(token.expires_in).toBeLessThanOrEqual(240);
    expect(token.expires_in).toBeGreaterThanOrEqual(238);
  });

  it.each([
    ['no expiry at all', {}],
    ['a non-numeric expiry', { expiry_date: 'soon' }],
    ['an expiry already past', { expiry_date: Date.now() - 60_000 }],
  ])('floors expires_in at 1 given %s', async (_name, credentials) => {
    // Never zero or negative: firebase-admin treats a non-positive lifetime
    // as a reason to refuse the credential outright.
    fromJSON.mockReturnValue(client({ credentials }));

    const { federatedAuth } = await loadModule();
    federatedAuth();

    const token = await capturedCredential().getAccessToken();

    expect(token.expires_in).toBe(1);
  });

  it.each([
    ['undefined', undefined],
    ['null', null],
    ['an empty string', ''],
  ])('refuses a token that is %s rather than passing it on', async (_name, token) => {
    // All three are shapes the library can return, and all three would reach
    // Google as an Authorization header of "Bearer ".
    fromJSON.mockReturnValue(client({ getAccessToken: vi.fn().mockResolvedValue({ token }) }));

    const { federatedAuth } = await loadModule();
    federatedAuth();

    await expect(capturedCredential().getAccessToken()).rejects.toThrow(/returned no access token/);
  });
});
