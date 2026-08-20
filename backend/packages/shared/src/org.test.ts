import { describe, it, expect } from 'vitest';

import { resolveOrgId, DEFAULT_ORG_ID, LEGACY_DEFAULT_ORG_CLAIM } from './org.js';
import { ApiError } from './errors.js';

/**
 * `resolveOrgId` — the mapping between a token's `org_id` claim and a real
 * `orgs.id`.
 *
 * Untested until Mission 7.9, which is how a pure function with one import and
 * three branches reached the coverage gate at 37.5%. Nothing here needs a
 * fixture, a mock or a database.
 *
 * The property under test is stated in `org.ts`'s own header and is the whole
 * reason the module exists: **an unrecognised value is refused, never
 * defaulted.** Defaulting would collapse a real organisation's id into
 * `Unassigned` and place the user in the wrong tenant with no error anywhere —
 * BR-20's isolation failing silently, which is the failure it exists to
 * prevent.
 */
describe('resolveOrgId', () => {
  it('maps the legacy literal to the row migration 0009 created', () => {
    // Four live accounts still carry this claim and nothing rewrites them, so
    // this branch is load-bearing rather than historical.
    expect(resolveOrgId(LEGACY_DEFAULT_ORG_CLAIM)).toBe(DEFAULT_ORG_ID);
  });

  it('passes a real uuid through unchanged', () => {
    // The branch Mission 7.6 depended on without any test asserting it: an
    // invite code's organisation reaches `users.org_id` by this path, and
    // A-226 proved it on a device long before this test existed.
    const orgId = '00000000-0000-4000-8000-0000000000d1';
    expect(resolveOrgId(orgId)).toBe(orgId);
  });

  it('lower-cases a uuid, so the same org is one value', () => {
    expect(resolveOrgId('AABBCCDD-1122-4333-8444-556677889900')).toBe(
      'aabbccdd-1122-4333-8444-556677889900',
    );
  });

  it.each([
    ['an unrecognised string', 'some-other-org'],
    ['an empty string', ''],
    ['a uuid missing a section', '00000000-0000-4000-8000'],
    ['a uuid with a non-hex character', '0000000g-0000-4000-8000-000000000001'],
    ['null', null],
    ['undefined', undefined],
    ['a number', 42],
    ['an object', { orgId: 'nice try' }],
  ])('refuses %s rather than defaulting', (_name, claim) => {
    // Every one of these throws. A default would place the account in a tenant
    // provisioning never assigned it, and it would be invisible — the person
    // would simply be let in somewhere.
    expect(() => resolveOrgId(claim)).toThrow(ApiError);
  });

  it('refuses with AUTH_ORG_UNRECOGNISED, not a generic error', () => {
    // The code matters: it is distinct from AUTH_USER_NOT_FOUND because the
    // account may well exist — it is the organisation that does not resolve.
    try {
      resolveOrgId('not-an-org');
      throw new Error('resolveOrgId should have thrown');
    } catch (thrown) {
      expect(thrown).toBeInstanceOf(ApiError);
      expect((thrown as ApiError).code).toBe('AUTH_ORG_UNRECOGNISED');
      expect((thrown as ApiError).status).toBe(401);
    }
  });
});
