/**
 * Resolving the `org_id` custom claim to a real `orgs.id`.
 *
 * ## The problem this exists for
 *
 * ADR-036's `redeemInviteCode` **wrote** `org_id` as a **literal string** —
 * `"vump-default"` — from Mission 2.9, when there was no organisation model to
 * point at. That function is gone: Mission 7.6 replaced it with
 * `POST /v1/auth/redeem`, which writes a real `orgs.id`.
 *
 * **This module is still needed, and the reason is the accounts, not the
 * writer.** Four live Firebase accounts minted by the old function still carry
 * the literal in their claims, and nothing rewrites it — gap-register item 5.
 * Every token they present has to be resolved, so the mapping outlives the
 * thing that created the need for it.
 *
 * Mission 6.3 gave `users.org_id` the type `uuid NOT NULL REFERENCES
 * orgs(id)`, and a literal satisfies neither half of that. Deferred item 12.
 *
 * Migration `0009` inserts the row the literal was always standing in for.
 * This module is the mapping between the two, and it is an **explicit lookup
 * rather than a fallback**.
 *
 * ## Why unknown values are rejected instead of defaulted
 *
 * Defaulting an unrecognised `org_id` to the default organisation would be the
 * convenient choice and the wrong one: the moment a real organisation exists,
 * a token carrying its id would be silently collapsed into `Unassigned`, and
 * the user would be placed in the wrong tenant with no error anywhere. BR-20's
 * isolation would fail quietly, which is the failure mode it exists to prevent.
 *
 * So: the literal maps, a real uuid passes through, and anything else throws.
 */
import { ApiError } from './errors.js';

/**
 * The `Unassigned` organisation created by migration `0009`.
 *
 * Deliberately reserved-looking. It is a valid uuid (version 4, variant 8) and
 * obviously synthetic, so it reads as a constant rather than as real data.
 */
export const DEFAULT_ORG_ID = '00000000-0000-4000-8000-000000000001';

/**
 * The legacy claim value that {@link DEFAULT_ORG_ID} stands in for.
 *
 * Matches `DEFAULT_ORG_ID` in `functions/src/index.ts`. The two must agree,
 * and nothing checks that they do — the same class of gap A-153 records.
 */
export const LEGACY_DEFAULT_ORG_CLAIM = 'vump-default';

/** A uuid in any version, lower- or upper-case. */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Maps an `org_id` claim to the `orgs.id` it denotes.
 *
 * @throws {ApiError} 401 when the claim is absent, or present and neither the
 * legacy literal nor a uuid. An account whose org cannot be identified is not
 * provisioned for this application, which is the same condition
 * `ErrorCode.authUnauthenticated` already covers.
 */
export function resolveOrgId(claim: unknown): string {
  if (claim === LEGACY_DEFAULT_ORG_CLAIM) {
    return DEFAULT_ORG_ID;
  }
  if (typeof claim === 'string' && UUID.test(claim)) {
    return claim.toLowerCase();
  }
  throw ApiError.orgUnrecognised();
}
