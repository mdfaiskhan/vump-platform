import { describe, it, expect } from 'vitest';

import { roleFor, secretNameFor } from './naming.js';

/**
 * The two names shared between `db:bootstrap`, the Terraform and the migrations.
 *
 * Untested until Mission 7.9. Two pure functions, six lines, and the reason
 * they are worth testing is not their complexity — it is that **three separate
 * systems compute the same strings and nothing checks that they agree.**
 *
 * `modules/db-credentials` builds the secret name in HCL as
 * `vump/{env}/db-{function}` and the role as `vump_${replace(key, "-", "_")}`.
 * Migration `0007` and `0012` create those roles by literal name. This module
 * is the third copy, and a drift in any one of them fails at runtime with an
 * authentication error naming nothing — the same class as the drift warning
 * `modules/gcp-federation` carries about a role ARN.
 *
 * These tests pin the shape. They cannot see the Terraform, which is the
 * limitation to state rather than imply.
 */
describe('roleFor', () => {
  it('replaces every hyphen, not just the first', () => {
    // The case that matters: `chunks-upload` has one hyphen and reaches
    // `vump_chunks_upload`. A single-replace bug would produce
    // `vump_chunks-upload`, which is not a legal unquoted PostgreSQL role.
    expect(roleFor('chunks-upload')).toBe('vump_chunks_upload');
    expect(roleFor('chunks-verify')).toBe('vump_chunks_verify');
  });

  it('leaves a hyphenless name alone', () => {
    expect(roleFor('projects')).toBe('vump_projects');
    expect(roleFor('redeem')).toBe('vump_redeem');
  });

  it('produces the eight roles the migrations actually create', () => {
    // Pinned against migration 0007's and 0012's literals. If this list and
    // those files disagree, `db:bootstrap` sets a password on a role that does
    // not exist, and the function it belongs to cannot authenticate.
    expect(
      [
        'auth-verify',
        'projects',
        'tasks',
        'sessions',
        'chunks-upload',
        'chunks-verify',
        'metadata',
        'redeem',
      ].map(roleFor),
    ).toEqual([
      'vump_auth_verify',
      'vump_projects',
      'vump_tasks',
      'vump_sessions',
      'vump_chunks_upload',
      'vump_chunks_verify',
      'vump_metadata',
      'vump_redeem',
    ]);
  });
});

describe('secretNameFor', () => {
  it('follows ADR-016 vump/{env}/{name}', () => {
    expect(secretNameFor('dev', 'redeem')).toBe('vump/dev/db-redeem');
  });

  it('keeps the hyphen the role name drops', () => {
    // Deliberately unlike `roleFor`: a Secrets Manager name permits hyphens
    // and PostgreSQL's unquoted identifier does not, so the two diverge on
    // purpose. A shared normalisation would break one of them.
    expect(secretNameFor('dev', 'chunks-upload')).toBe('vump/dev/db-chunks-upload');
  });

  it('varies by environment', () => {
    expect(secretNameFor('staging', 'tasks')).toBe('vump/staging/db-tasks');
    expect(secretNameFor('prod', 'tasks')).toBe('vump/prod/db-tasks');
  });
});
