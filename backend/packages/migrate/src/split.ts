/**
 * Splits a migration file into individual statements.
 *
 * ## Why this exists at all
 *
 * The Data API rejects multi-statement SQL: `SELECT 1; SELECT 2` returns
 * `ValidationException: Multistatements aren't supported`. Measured against the
 * live cluster, not inferred. So something has to split, and a naive
 * `sql.split(';')` is wrong in a way that matters here — `0006_integrity_rules`
 * defines PL/pgSQL functions whose bodies are full of semicolons inside
 * `$fn$ … $fn$`, and splitting on those produces fragments that are not SQL.
 *
 * ## What it understands
 *
 * - `'single quoted'` strings, including `''` escapes
 * - `"quoted identifiers"`
 * - `$$ … $$` and `$tag$ … $tag$` dollar-quoted bodies, matched by tag
 * - `-- line comments` and `/* block comments *\/`, including nesting, which
 *   PostgreSQL allows and most splitters get wrong
 *
 * It is a lexer rather than a parser: it needs to know where a statement ends,
 * not what it means.
 */

/** A statement and where it came from, for error messages worth reading. */
export interface Statement {
  readonly sql: string;
  /** 1-based line in the source file where the statement begins. */
  readonly line: number;
}

const DOLLAR_TAG = /^\$[A-Za-z_]*\$/;

/**
 * Splits [source] into executable statements, dropping comments and blanks.
 *
 * Throws when the file ends inside a string, a dollar-quoted body or a block
 * comment — an unterminated construct means the split is guesswork, and
 * guessing produces a half-statement that fails against the database with a
 * message pointing nowhere useful.
 */
export function splitStatements(source: string): Statement[] {
  const statements: Statement[] = [];

  let buffer = '';
  let startLine = 1;
  let line = 1;
  let i = 0;

  const push = (): void => {
    const sql = buffer.trim();
    if (sql !== '') {
      statements.push({ sql, line: startLine });
    }
    buffer = '';
  };

  while (i < source.length) {
    const ch = source[i] ?? '';
    const next = source[i + 1] ?? '';
    const rest = source.slice(i);

    // -- line comment
    if (ch === '-' && next === '-') {
      const end = source.indexOf('\n', i);
      i = end === -1 ? source.length : end;
      continue;
    }

    // /* block comment */ — nesting is legal in PostgreSQL
    if (ch === '/' && next === '*') {
      let depth = 0;
      const opened = line;
      while (i < source.length) {
        if (source[i] === '/' && source[i + 1] === '*') {
          depth++;
          i += 2;
        } else if (source[i] === '*' && source[i + 1] === '/') {
          depth--;
          i += 2;
          if (depth === 0) break;
        } else {
          if (source[i] === '\n') line++;
          i++;
        }
      }
      if (depth !== 0) {
        throw new Error(`Unterminated block comment opened on line ${String(opened)}.`);
      }
      continue;
    }

    // $tag$ dollar-quoted body
    const dollar = DOLLAR_TAG.exec(rest);
    if (ch === '$' && dollar !== null) {
      const tag = dollar[0];
      const opened = line;
      const close = source.indexOf(tag, i + tag.length);
      if (close === -1) {
        throw new Error(
          `Unterminated dollar-quoted block ${tag} opened on line ${String(opened)}.`,
        );
      }
      const body = source.slice(i, close + tag.length);
      buffer += body;
      line += (body.match(/\n/g) ?? []).length;
      i = close + tag.length;
      continue;
    }

    // 'string' or "identifier"
    if (ch === "'" || ch === '"') {
      const quote = ch;
      const opened = line;
      buffer += ch;
      i++;
      let closed = false;
      while (i < source.length) {
        const c = source[i] ?? '';
        if (c === '\n') line++;
        buffer += c;
        i++;
        if (c === quote) {
          if (source[i] === quote) {
            // Doubled quote is an escaped literal, not a terminator.
            buffer += quote;
            i++;
            continue;
          }
          closed = true;
          break;
        }
      }
      if (!closed) {
        throw new Error(`Unterminated ${quote} literal opened on line ${String(opened)}.`);
      }
      continue;
    }

    if (ch === ';') {
      push();
      i++;
      // The next statement starts after any whitespace that follows.
      startLine = line;
      continue;
    }

    if (ch === '\n') {
      line++;
      if (buffer.trim() === '') {
        startLine = line;
      }
    }

    buffer += ch;
    i++;
  }

  push();
  return statements;
}
