import { describe, it, expect, beforeEach, afterEach } from 'vitest';

import { externalAccountOptions } from './firebase.js';

/**
 * The external-account configuration, which is the only part of `firebase.ts`
 * testable without a live token exchange.
 *
 * ## Why this file exists at all
 *
 * Mission 7.6 spent two live failures and a three-step bisection on fields of
 * exactly this kind. A-222 was an attribute mapping that could never match its
 * binding; A-223 was a permission set that named what the caller CALLS rather
 * than what those calls REQUIRE. Both failed at runtime as a 403 naming neither
 * side, because **a wrong value here is indistinguishable from a right one
 * until Google refuses it.**
 *
 * These assertions cannot catch a wrong *audience* — only a live exchange can.
 * What they can catch is a field silently dropped, renamed, or given the form
 * that looks correct and is not: the lower-case `aws1`, the impersonation URL,
 * and the two metadata-server fields whose ABSENCE is the load-bearing part.
 *
 * Stated plainly so this file is not mistaken for proof of federation: it tests
 * the shape of a config object. A-226's device redemption is what proves the
 * federation works.
 */
const ENV = {
  GCP_AUDIENCE:
    '//iam.googleapis.com/projects/434336914712/locations/global/' +
    'workloadIdentityPools/vump-dev-aws/providers/aws-lambda',
  GCP_SERVICE_ACCOUNT_EMAIL: 'vump-dev-redeem@vump-platform-f86af.iam.gserviceaccount.com',
  GCP_STS_VERIFICATION_URL:
    'https://sts.ap-south-1.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15',
};

beforeEach(() => {
  Object.assign(process.env, ENV);
});

afterEach(() => {
  for (const key of Object.keys(ENV)) {
    Reflect.deleteProperty(process.env, key);
  }
});

describe('externalAccountOptions', () => {
  it('builds the impersonation URL from the service account', () => {
    // **Required, not optional**, and the failure mode if it is missing is the
    // one worth pinning: the token becomes the POOL PRINCIPAL's rather than
    // the service account's, and the pool principal holds no permission at
    // all. Phase 2 granted the custom role to the service account and gave the
    // pool principal workloadIdentityUser over it, so without this line the
    // whole grant is bypassed and nothing says so.
    expect(externalAccountOptions().service_account_impersonation_url).toBe(
      'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/' +
        'vump-dev-redeem@vump-platform-f86af.iam.gserviceaccount.com' +
        ':generateAccessToken',
    );
  });

  it('omits region_url and url, which is what makes Lambda work', () => {
    // Not an oversight and not a default. Both fields read the EC2 metadata
    // server at 169.254.169.254, which **Lambda does not have**;
    // google-auth-library falls back to the AWS_* variables the execution role
    // populates only when neither field is present. Supplying either would
    // make the client try the metadata server first and hang until it timed
    // out — a failure that looks like a slow network, not a config error.
    const source = externalAccountOptions().credential_source;

    expect(source).not.toHaveProperty('region_url');
    expect(source).not.toHaveProperty('url');
    expect(source.regional_cred_verification_url).toBe(ENV.GCP_STS_VERIFICATION_URL);
  });

  it("uses lower-case 'aws1', which the library's own regex requires", () => {
    // Google's documentation writes this as `AWS1`. google-auth-library
    // validates it against /^(aws)(\d+)$/ — case-sensitive — and throws
    // 'No valid AWS "credential_source" provided' on the documented spelling.
    // Verified against the installed source at Mission 7.6 Phase 4.
    expect(externalAccountOptions().credential_source.environment_id).toBe('aws1');
  });

  it('declares the external-account type and the AWS subject token type', () => {
    // `ExternalAccountClient.fromJSON` returns NULL rather than throwing when
    // `type` is not 'external_account', so a wrong value here surfaces much
    // later as a Firebase permission error.
    const options = externalAccountOptions();

    expect(options.type).toBe('external_account');
    expect(options.subject_token_type).toBe('urn:ietf:params:aws:token-type:aws4_request');
    expect(options.token_url).toBe('https://sts.googleapis.com/v1/token');
  });

  it('passes the audience through untouched', () => {
    // The one field this test cannot validate the CONTENT of — it carries the
    // GCP project number and only Google can say whether it names a real pool.
    // What is asserted is that nothing here reshapes it.
    expect(externalAccountOptions().audience).toBe(ENV.GCP_AUDIENCE);
  });

  it.each(Object.keys(ENV))('refuses to build without %s', (name) => {
    // Fails at cold start naming the variable, rather than at the first
    // Firebase call as a 403 from Identity Toolkit that names nothing.
    //
    // `Reflect.deleteProperty`, not `process.env[name] = undefined`: Node
    // coerces an assigned `undefined` to the STRING "undefined", which
    // `requireEnv` accepts as a perfectly good value. The assignment idiom is
    // used elsewhere in this repository's `afterEach` blocks and works there
    // only because each `beforeEach` overwrites the key again.
    Reflect.deleteProperty(process.env, name);

    expect(() => externalAccountOptions()).toThrow(name);
  });

  it('refuses an empty value as firmly as a missing one', () => {
    // An unset Terraform output arrives as an empty string, not as undefined.
    process.env.GCP_AUDIENCE = '';

    expect(() => externalAccountOptions()).toThrow('GCP_AUDIENCE');
  });
});
