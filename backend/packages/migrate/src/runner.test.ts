import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mkdtemp, writeFile, rm, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// `execute`, the Data API client and the resume wrapper are mocked; the real
// filesystem is not. `loadMigrations` reads directories and hashes bytes, and
// a fake filesystem would test the fake — the same substitution A-212 records,
// where a mock asserted what was sent rather than what Postgres would accept.
const execute = vi.fn();
const send = vi.fn();

vi.mock('@vump/shared', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@vump/shared')>();
  return {
    ...actual,
    execute,
    dataApiClient: () => ({ send }),
    withResumeRetry: (fn: () => Promise<unknown>) => fn(),
  };
});

const { loadMigrations, ensureTrackingTable, appliedMigrations, runMigrations } =
  await import('./runner.js');

const TARGET = {
  resourceArn: 'arn:aws:rds:ap-south-1:1:cluster:vump-dev',
  secretArn: 'arn:aws:secretsmanager:ap-south-1:1:secret:vump-dev',
  database: 'vump',
};

let dir: string;

async function migration(file: string, sql: string) {
  await writeFile(join(dir, file), sql, 'utf8');
}

/** The tracking-table response shape: id, name, checksum, positionally. */
function appliedRow(id: string, name: string, checksum: string) {
  return [{ stringValue: id }, { stringValue: name }, { stringValue: checksum }];
}

beforeEach(async () => {
  vi.clearAllMocks();
  dir = await mkdtemp(join(tmpdir(), 'vump-migrations-'));
  execute.mockResolvedValue({});
  send.mockResolvedValue({ transactionId: 'tx-1' });
});

afterEach(async () => {
  await rm(dir, { recursive: true, force: true });
  vi.restoreAllMocks();
});

/**
 * The migration runner — 0% covered until Mission 8.1, and the largest single
 * entry on the coverage gate's exemption list (open item 127).
 *
 * Two of its properties are the reason it carried a 70% target rather than a
 * waiver. **Ordering decides what runs first**, so a filename that does not
 * sort is refused rather than sorted approximately. And **an applied migration
 * is history**: the checksum comparison is the only thing standing between an
 * edited migration and two databases that ran different SQL under one id, a
 * divergence nothing downstream could detect.
 */

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

describe('loadMigrations', () => {
  it('loads .sql files in ordinal order and hashes their contents', async () => {
    await migration('0002_second.sql', 'SELECT 2;');
    await migration('0001_first.sql', 'SELECT 1;');

    const loaded = await loadMigrations(dir);

    expect(loaded.map((m) => m.id)).toEqual(['0001', '0002']);
    expect(loaded.map((m) => m.name)).toEqual(['first', 'second']);
    // sha256 of "SELECT 1;", pinned as a literal. Recomputing it here with
    // createHash would assert the module agrees with itself — open item 129's
    // exact shape, and the reason `pagination.test.ts` was fixed at 7.10.
    expect(loaded[0]?.checksum).toBe(
      '17db4fd369edb9244b9f91d9aeed145c3d04ad8ba6e95d06247f07a63527d11a',
    );
    expect(loaded[0]?.checksum).not.toBe(loaded[1]?.checksum);
  });

  it('ignores files that are not .sql', async () => {
    await migration('0001_first.sql', 'SELECT 1;');
    await migration('README.md', 'not sql');
    await migration('0002_notes.txt', 'also not sql');

    expect(await loadMigrations(dir)).toHaveLength(1);
  });

  it.each([
    ['no ordinal', 'create_users.sql'],
    ['too few digits', '001_users.sql'],
    ['upper case', '0001_Users.sql'],
    ['a hyphen instead of an underscore', '0001-users.sql'],
    ['no name', '0001_.sql'],
  ])('refuses a filename with %s', async (_why, file) => {
    await migration(file, 'SELECT 1;');

    // The message says why, because the person hitting it is about to rename
    // a file and needs to know the rule rather than guess it.
    await expect(loadMigrations(dir)).rejects.toThrow(/ordering is the/);
  });

  it('refuses two migrations sharing one ordinal', async () => {
    // Same ordinal, different names: both sort, neither is first.
    await migration('0001_users.sql', 'SELECT 1;');
    await migration('0001_orgs.sql', 'SELECT 2;');

    await expect(loadMigrations(dir)).rejects.toThrow(/Duplicate migration ordinals/);
  });

  it('returns an empty list for a directory with no migrations', async () => {
    await mkdir(join(dir, 'nested'));

    expect(await loadMigrations(dir)).toEqual([]);
  });

  it('gives identical SQL identical checksums, and different SQL different ones', async () => {
    await migration('0001_a.sql', 'SELECT 1;');
    await migration('0002_b.sql', 'SELECT 1;');
    await migration('0003_c.sql', 'SELECT 1; -- a comment changes the bytes');

    const [a, b, c] = await loadMigrations(dir);

    expect(defined(a, 'migration a').checksum).toBe(defined(b, 'migration b').checksum);
    expect(c?.checksum).not.toBe(a?.checksum);
  });
});

describe('ensureTrackingTable', () => {
  it('creates the table only if it is absent', async () => {
    await ensureTrackingTable(TARGET);

    const [sql, options] = defined(execute.mock.calls[0], 'the first execute call');
    expect(sql).toContain('CREATE TABLE IF NOT EXISTS');
    expect(options).toEqual({ target: TARGET });
  });
});

describe('appliedMigrations', () => {
  it('reads the tracking rows into a map keyed by id', async () => {
    execute.mockResolvedValue({
      records: [appliedRow('0001', 'first', 'abc'), appliedRow('0002', 'second', 'def')],
    });

    const applied = await appliedMigrations(TARGET);

    expect(applied.get('0001')).toEqual({ name: 'first', checksum: 'abc' });
    expect(applied.size).toBe(2);
  });

  it('returns an empty map when the table is empty or absent from the response', async () => {
    execute.mockResolvedValue({ records: [] });
    expect((await appliedMigrations(TARGET)).size).toBe(0);

    execute.mockResolvedValue({});
    expect((await appliedMigrations(TARGET)).size).toBe(0);
  });

  it('drops a row missing any of the three columns rather than half-reading it', async () => {
    // A partial row would produce an entry whose checksum is undefined, and
    // the comparison in runMigrations would then skip a migration it should
    // have refused.
    execute.mockResolvedValue({
      records: [appliedRow('0001', 'first', 'abc'), [{ stringValue: '0002' }, {}, {}]],
    });

    const applied = await appliedMigrations(TARGET);

    expect(applied.size).toBe(1);
    expect(applied.has('0002')).toBe(false);
  });
});

describe('runMigrations', () => {
  /** Wires `execute` so the tracking read returns `rows`. */
  function trackingHolds(rows: unknown[]) {
    execute.mockImplementation((sql: string) =>
      Promise.resolve(sql.includes('SELECT id, name, checksum') ? { records: rows } : {}),
    );
  }

  it('applies a new migration inside one transaction and records it', async () => {
    await migration('0001_users.sql', 'CREATE TABLE users (id int);');
    trackingHolds([]);

    const result = await runMigrations(dir, TARGET);

    expect(result.applied.map((m) => m.id)).toEqual(['0001']);
    expect(result.skipped).toEqual([]);

    // Begin and commit, in that order, around the work.
    expect(send).toHaveBeenCalledTimes(2);
    const inserted = execute.mock.calls.find(([sql]) => String(sql).includes('INSERT INTO'));
    expect(inserted?.[1]).toMatchObject({ transactionId: 'tx-1' });
  });

  it('records the statement count it actually ran', async () => {
    await migration('0001_two.sql', 'SELECT 1;\nSELECT 2;');
    trackingHolds([]);

    await runMigrations(dir, TARGET);

    const inserted = execute.mock.calls.find(([sql]) => String(sql).includes('INSERT INTO'));
    const params = (inserted?.[1] as { parameters: { name: string; value: unknown }[] }).parameters;
    expect(params.find((p) => p.name === 'statements')?.value).toEqual({ longValue: 2 });
  });

  it('skips a migration already applied with the same checksum', async () => {
    await migration('0001_users.sql', 'SELECT 1;');
    const [loaded] = await loadMigrations(dir);
    trackingHolds([appliedRow('0001', 'users', defined(loaded, 'the loaded migration').checksum)]);

    const onSkip = vi.fn();
    const result = await runMigrations(dir, TARGET, { onSkip });

    expect(result.skipped.map((m) => m.id)).toEqual(['0001']);
    expect(result.applied).toEqual([]);
    expect(onSkip).toHaveBeenCalledOnce();
    // Nothing was begun, so nothing was re-run.
    expect(send).not.toHaveBeenCalled();
  });

  it('refuses a migration edited since it was applied', async () => {
    // The forward-only guarantee. Without this, one database has the old SQL
    // and another the new, both recorded under id 0001, and nothing anywhere
    // would report a difference.
    await migration('0001_users.sql', 'SELECT 1; -- edited after the fact');
    trackingHolds([appliedRow('0001', 'users', 'the-checksum-from-before')]);

    await expect(runMigrations(dir, TARGET)).rejects.toThrow(/has changed since it was applied/);
    expect(send).not.toHaveBeenCalled();
  });

  it('names both checksums in the refusal', async () => {
    await migration('0001_users.sql', 'SELECT 1;');
    trackingHolds([appliedRow('0001', 'users', 'old-checksum')]);

    await expect(runMigrations(dir, TARGET)).rejects.toThrow(/old-checksum/);
  });

  it('reports progress through the events it was given', async () => {
    await migration('0001_users.sql', 'SELECT 1;\nSELECT 2;');
    trackingHolds([]);

    const onStart = vi.fn();
    const onDone = vi.fn();
    await runMigrations(dir, TARGET, { onStart, onDone });

    expect(onStart).toHaveBeenCalledWith(expect.objectContaining({ id: '0001' }), 2);
    expect(onDone).toHaveBeenCalledWith(expect.objectContaining({ id: '0001' }));
  });

  it('rolls back and wraps the failure when a statement fails', async () => {
    await migration('0001_users.sql', 'THIS IS NOT SQL;');
    execute.mockImplementation((sql: string) => {
      if (sql.includes('SELECT id, name, checksum')) return Promise.resolve({ records: [] });
      if (sql.includes('THIS IS NOT SQL')) {
        return Promise.reject(new Error('syntax error at or near "THIS"'));
      }
      return Promise.resolve({});
    });

    await expect(runMigrations(dir, TARGET)).rejects.toThrow(
      /0001_users failed and was rolled back: syntax error/,
    );

    // Begin, then rollback — never commit.
    expect(send).toHaveBeenCalledTimes(2);
    const commands = send.mock.calls.map(([c]) => (c as object).constructor.name);
    expect(commands).toEqual(['BeginTransactionCommand', 'RollbackTransactionCommand']);
  });

  it('keeps the original failure as the cause', async () => {
    await migration('0001_users.sql', 'BOOM;');
    const cause = new Error('permission denied for table users');
    execute.mockImplementation((sql: string) => {
      if (sql.includes('SELECT id, name, checksum')) return Promise.resolve({ records: [] });
      if (sql.includes('BOOM')) return Promise.reject(cause);
      return Promise.resolve({});
    });

    await expect(runMigrations(dir, TARGET)).rejects.toMatchObject({ cause });
  });

  it('refuses to proceed when BeginTransaction returns no transactionId', async () => {
    // Running the statements outside a transaction would apply half a
    // migration and record none of it.
    await migration('0001_users.sql', 'SELECT 1;');
    trackingHolds([]);
    send.mockResolvedValue({});

    await expect(runMigrations(dir, TARGET)).rejects.toThrow(
      /BeginTransaction returned no transactionId/,
    );
  });

  it('applies several migrations in ordinal order, stopping at the first failure', async () => {
    await migration('0001_a.sql', 'SELECT 1;');
    await migration('0002_b.sql', 'FAIL;');
    await migration('0003_c.sql', 'SELECT 3;');
    execute.mockImplementation((sql: string) => {
      if (sql.includes('SELECT id, name, checksum')) return Promise.resolve({ records: [] });
      if (sql.includes('FAIL')) return Promise.reject(new Error('nope'));
      return Promise.resolve({});
    });

    await expect(runMigrations(dir, TARGET)).rejects.toThrow(/0002_b failed/);

    // 0003 must not have been attempted: a later migration may depend on the
    // one that failed.
    expect(execute.mock.calls.some(([sql]) => String(sql).includes('SELECT 3'))).toBe(false);
  });
});
