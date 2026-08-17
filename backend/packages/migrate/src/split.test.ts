import { describe, it, expect } from 'vitest';
import { readFile, readdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { splitStatements } from './split.js';

const MIGRATIONS = join(
  dirname(dirname(dirname(dirname(fileURLToPath(import.meta.url))))),
  'migrations',
);

const sqlOf = (s: string): string[] => splitStatements(s).map((x) => x.sql);

describe('splitStatements', () => {
  it('splits on semicolons', () => {
    expect(sqlOf('SELECT 1; SELECT 2')).toEqual(['SELECT 1', 'SELECT 2']);
  });

  it('drops a trailing semicolon rather than emitting an empty statement', () => {
    expect(sqlOf('SELECT 1;')).toEqual(['SELECT 1']);
  });

  it('ignores semicolons inside a single-quoted string', () => {
    expect(sqlOf("SELECT 'a;b'; SELECT 2")).toEqual(["SELECT 'a;b'", 'SELECT 2']);
  });

  it('handles a doubled quote inside a string', () => {
    expect(sqlOf("SELECT 'it''s; fine'")).toEqual(["SELECT 'it''s; fine'"]);
  });

  it('ignores semicolons inside a quoted identifier', () => {
    expect(sqlOf('SELECT "odd;name" FROM t')).toEqual(['SELECT "odd;name" FROM t']);
  });

  it('strips line comments, including ones containing a semicolon', () => {
    expect(sqlOf('SELECT 1; -- a; comment\nSELECT 2')).toEqual(['SELECT 1', 'SELECT 2']);
  });

  it('strips block comments and handles PostgreSQL nesting', () => {
    expect(sqlOf('SELECT 1 /* outer /* inner; */ still */ ; SELECT 2')).toEqual([
      'SELECT 1',
      'SELECT 2',
    ]);
  });

  it('keeps a dollar-quoted body whole — the case a naive split destroys', () => {
    const sql = `CREATE FUNCTION f() RETURNS void LANGUAGE plpgsql AS $fn$
BEGIN
  PERFORM 1;
  PERFORM 2;
END;
$fn$;
SELECT 1`;
    const out = sqlOf(sql);

    expect(out).toHaveLength(2);
    expect(out[0]).toContain('PERFORM 1;');
    expect(out[0]).toContain('PERFORM 2;');
    expect(out[1]).toBe('SELECT 1');
  });

  it('handles untagged $$ bodies', () => {
    expect(
      sqlOf('CREATE FUNCTION f() RETURNS int AS $$ SELECT 1; $$ LANGUAGE sql; SELECT 2'),
    ).toHaveLength(2);
  });

  it('reports the starting line, so a failure names a place', () => {
    const out = splitStatements('SELECT 1;\n\nSELECT 2');
    expect(out[1]?.line).toBe(3);
  });

  it('refuses an unterminated dollar-quoted block rather than guessing', () => {
    expect(() => splitStatements('CREATE FUNCTION f() AS $fn$ BEGIN')).toThrow(/Unterminated/);
  });

  it('refuses an unterminated string', () => {
    expect(() => splitStatements("SELECT 'oops")).toThrow(/Unterminated/);
  });

  it('refuses an unterminated block comment', () => {
    expect(() => splitStatements('SELECT 1 /* oops')).toThrow(/Unterminated/);
  });

  it('returns nothing for a comment-only file', () => {
    expect(sqlOf('-- just a comment\n\n')).toEqual([]);
  });
});

describe('the real migration files', () => {
  it('every file splits into at least one statement and none is blank', async () => {
    const files = (await readdir(MIGRATIONS)).filter((f) => f.endsWith('.sql')).sort();
    expect(files.length).toBeGreaterThan(0);

    for (const file of files) {
      const statements = splitStatements(await readFile(join(MIGRATIONS, file), 'utf8'));
      expect(statements.length, `${file} should produce statements`).toBeGreaterThan(0);
      for (const s of statements) {
        expect(s.sql.trim(), `${file} produced a blank statement`).not.toBe('');
      }
    }
  });

  it('no split statement still contains an unbalanced dollar quote', async () => {
    // The specific corruption this splitter exists to prevent: a function body
    // cut in half leaves an odd number of $tag$ markers.
    const files = (await readdir(MIGRATIONS)).filter((f) => f.endsWith('.sql'));
    for (const file of files) {
      for (const s of splitStatements(await readFile(join(MIGRATIONS, file), 'utf8'))) {
        const tags = s.sql.match(/\$[A-Za-z_]*\$/g) ?? [];
        expect(
          tags.length % 2,
          `${file}: "${s.sql.slice(0, 40)}…" has an odd dollar-quote count`,
        ).toBe(0);
      }
    }
  });

  it('the PL/pgSQL migration keeps each function body in one statement', async () => {
    const sql = await readFile(join(MIGRATIONS, '0006_integrity_rules.sql'), 'utf8');
    const statements = splitStatements(sql);

    const functions = statements.filter((s) => s.sql.startsWith('CREATE FUNCTION'));
    expect(functions).toHaveLength(3);
    for (const f of functions) {
      expect(f.sql).toContain('END;');
    }
  });
});
