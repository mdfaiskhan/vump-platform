import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { ExecuteStatementCommandOutput, Field } from '@aws-sdk/client-rds-data';

// Only the Data API is mocked. `resolveOrgId` and `ApiError` run for real,
// because provisionCaller's contract is partly theirs — an unrecognised
// organisation must be refused rather than defaulted, and org.test.ts proves
// the refusal in isolation. Mocking it here would let this file pass while the
// two disagreed.
vi.mock('./data-api.js', () => ({ execute: vi.fn() }));

const { execute } = await import('./data-api.js');
const { lookupCaller, provisionCaller } = await import('./caller.js');
const { ApiError } = await import('./errors.js');
const { DEFAULT_ORG_ID, LEGACY_DEFAULT_ORG_CLAIM } = await import('./org.js');

const ORG = '00000000-0000-4000-8000-0000000000d1';
const USER = '11111111-1111-4111-8111-111111111111';

const IDENTITY = {
  firebaseUid: 'firebase-uid-1',
  email: 'collector@example.com',
  roleClaim: 'collector',
  orgIdClaim: ORG,
};

/** One `users` row as the Data API returns it: positional, all strings. */
function row(id = USER, orgId = ORG, role = 'collector'): Field[] {
  return [{ stringValue: id }, { stringValue: orgId }, { stringValue: role }];
}

/**
 * A Data API response as the SDK actually types it.
 *
 * `ExecuteStatementCommandOutput` requires `$metadata`, so a bare object
 * literal does not satisfy it. Omitting `records` entirely is a distinct
 * case from an empty array — the first is what a statement returning no
 * result set looks like, and `lookupCaller` refuses both.
 */
function out(records?: Field[][]): ExecuteStatementCommandOutput {
  return records === undefined ? { $metadata: {} } : { $metadata: {}, records };
}

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

beforeEach(() => {
  vi.clearAllMocks();
  vi.spyOn(console, 'log').mockImplementation(() => undefined);
  vi.spyOn(console, 'error').mockImplementation(() => undefined);
});

afterEach(() => vi.restoreAllMocks());

/**
 * `lookupCaller` and `provisionCaller`, at 0% until Mission 8.1 and exempted
 * from the coverage gate at that figure since 7.9.
 *
 * Chapter 4.7 §1 step 4 lives here, which is why the exemption carried an 80%
 * target rather than 50%. Every rejection below is a rejection of a token that
 * Firebase itself accepted — this is the layer that decides whether an
 * authenticated principal is a known one, and each branch refuses rather than
 * defaults.
 */
describe('lookupCaller', () => {
  it('reads the row positionally into a caller', async () => {
    vi.mocked(execute).mockResolvedValue(out([row()]));

    await expect(lookupCaller(IDENTITY)).resolves.toEqual({
      userId: USER,
      orgId: ORG,
      role: 'collector',
    });
  });

  it('queries by firebase_uid, not by email', async () => {
    // The email on a token can change; the uid cannot. Looking up by email
    // would rebind an account to whoever last claimed the address.
    vi.mocked(execute).mockResolvedValue(out([row()]));

    await lookupCaller(IDENTITY);

    const [sql, options] = defined(vi.mocked(execute).mock.calls[0], 'the first execute call');
    expect(sql).toContain('WHERE firebase_uid = :uid');
    expect(options?.parameters).toEqual([
      { name: 'uid', value: { stringValue: 'firebase-uid-1' } },
    ]);
  });

  it.each<[string, ExecuteStatementCommandOutput]>([
    ['no records array at all', out()],
    ['an empty records array', out([])],
  ])('refuses when the query returns %s', async (_name, response) => {
    vi.mocked(execute).mockResolvedValue(response);

    await expect(lookupCaller(IDENTITY)).rejects.toThrow(ApiError);
  });

  it('refuses with AUTH_USER_NOT_FOUND and a 401, not a 404', async () => {
    // The distinction is deliberate: the caller is unauthenticated as far as
    // this system is concerned, not looking at a missing resource.
    vi.mocked(execute).mockResolvedValue(out([]));

    await expect(lookupCaller(IDENTITY)).rejects.toMatchObject({
      code: 'AUTH_USER_NOT_FOUND',
      status: 401,
    });
  });

  // `{ isNull: true }` is what the Data API actually returns for a NULL
  // column; `Field` is a tagged union and an empty object matches no member.
  // `caller.ts` tests `?.stringValue === undefined`, which both satisfy, so
  // the branch under test is unchanged and the mock is now the truthful one.
  it.each<[string, Field[]]>([
    ['id', [{ isNull: true }, { stringValue: ORG }, { stringValue: 'collector' }]],
    ['org_id', [{ stringValue: USER }, { isNull: true }, { stringValue: 'collector' }]],
    ['role', [{ stringValue: USER }, { stringValue: ORG }, { isNull: true }]],
  ])('throws loudly when the %s column comes back null', async (_name, broken) => {
    // A NOT NULL column returning null means the query and the schema
    // disagree. The file's own comment: failing loudly beats returning a
    // half-built caller — a caller with a blank orgId would read another
    // tenant's rows.
    vi.mocked(execute).mockResolvedValue(out([broken]));

    await expect(lookupCaller(IDENTITY)).rejects.toThrow('users row is missing a NOT NULL column');
  });
});

describe('provisionCaller — what it refuses before it writes', () => {
  it.each([
    ['a role the token does not carry', undefined],
    ['an empty role', ''],
    ['an unrecognised role', 'superuser'],
    ['a role that only differs by case', 'Collector'],
  ])('refuses %s without touching the database', async (_name, roleClaim) => {
    await expect(provisionCaller({ ...IDENTITY, roleClaim })).rejects.toThrow(ApiError);

    // The ordering is the point: nothing is inserted for a claim this layer
    // does not recognise.
    expect(vi.mocked(execute)).not.toHaveBeenCalled();
  });

  it.each([
    ['no email', undefined],
    ['an empty email', ''],
  ])('refuses %s without touching the database', async (_name, email) => {
    await expect(provisionCaller({ ...IDENTITY, email })).rejects.toThrow(ApiError);

    expect(vi.mocked(execute)).not.toHaveBeenCalled();
  });

  it('refuses an unrecognised organisation rather than defaulting it', async () => {
    // resolveOrgId runs for real here. A default would place a new account in
    // a tenant provisioning never assigned it, invisibly.
    await expect(provisionCaller({ ...IDENTITY, orgIdClaim: 'not-an-org' })).rejects.toMatchObject({
      code: 'AUTH_ORG_UNRECOGNISED',
    });

    expect(vi.mocked(execute)).not.toHaveBeenCalled();
  });
});

describe('provisionCaller — the write', () => {
  it('inserts then reads back, and returns the row the database holds', async () => {
    // The returned caller comes from the SELECT, not from the claims. On a
    // conflict the INSERT does nothing and the existing row wins, which is
    // what makes a second sign-in idempotent instead of a duplicate.
    vi.mocked(execute)
      .mockResolvedValueOnce(out())
      .mockResolvedValueOnce(out([row(USER, ORG, 'admin')]));

    await expect(provisionCaller({ ...IDENTITY, roleClaim: 'admin' })).resolves.toEqual({
      userId: USER,
      orgId: ORG,
      role: 'admin',
    });

    expect(vi.mocked(execute)).toHaveBeenCalledTimes(2);
    expect(vi.mocked(execute).mock.calls[0]?.[0]).toContain(
      'ON CONFLICT (firebase_uid) DO NOTHING',
    );
  });

  it('binds the resolved organisation, not the raw claim', async () => {
    // The legacy literal maps to the row migration 0009 created. Writing the
    // claim through unchanged would create a users row pointing at no org.
    vi.mocked(execute)
      .mockResolvedValueOnce(out())
      .mockResolvedValueOnce(out([row()]));

    await provisionCaller({ ...IDENTITY, orgIdClaim: LEGACY_DEFAULT_ORG_CLAIM });

    const insert = vi.mocked(execute).mock.calls[0]?.[1];
    expect(insert?.parameters).toContainEqual({
      name: 'orgId',
      value: { stringValue: DEFAULT_ORG_ID },
    });
  });

  it('accepts both roles the system recognises', async () => {
    for (const role of ['collector', 'admin']) {
      vi.mocked(execute)
        .mockResolvedValueOnce(out())
        .mockResolvedValueOnce(out([row(USER, ORG, role)]));

      await expect(provisionCaller({ ...IDENTITY, roleClaim: role })).resolves.toMatchObject({
        role,
      });
      vi.mocked(execute).mockReset();
    }
  });

  it('refuses if the row is still absent after the insert', async () => {
    // ON CONFLICT DO NOTHING plus a read that finds nothing means the write
    // was rejected by something other than a conflict — a grant, most likely.
    // Returning a caller here would invent one.
    vi.mocked(execute).mockResolvedValueOnce(out()).mockResolvedValueOnce(out([]));

    await expect(provisionCaller(IDENTITY)).rejects.toMatchObject({
      code: 'AUTH_USER_NOT_FOUND',
    });
  });
});
