// The backend coverage gate — Gap 15, Mission 7.9.
//
// Reads `coverage/coverage-summary.json` and enforces two thresholds:
//
//   * the repository, at GLOBAL_LINES
//   * every file individually, at PER_FILE_LINES, except those named in EXEMPT
//
// ## Why this is a script and not `coverage.thresholds`
//
// Vitest can express either of those, not both. `thresholds: { lines: N }` is a
// repository total; adding `perFile: true` reinterprets the SAME number as a
// per-file floor and there is no second number. Glob entries look like the
// escape hatch and are not: measured at Mission 7.9, a glob threshold is
// checked against the AGGREGATE of the files it matches, so
// `'packages/shared/src/**.ts': { lines: 50 }` passed while `caller.ts` sat at
// 0% and `authorizer.ts` at 9% — the group average carried them. Glob entries
// also cannot carry `perFile`; the type is `Pick<Thresholds, …>` without it.
//
// So the built-in could enforce a global number, or a uniform per-file number
// with no exemptions, but not the shape this gate needs.
//
// The second reason is that the exemptions are the interesting part. Here they
// are a list with a named target and a reason each, printed on every run.
// Inside a config object they would be four numbers nobody reads again.
import { readFileSync } from 'node:fs';

/** The repository must not fall below this. Measured at 77.7% when set. */
const GLOBAL_LINES = 70;

/** No single file may fall below this, exemptions aside. */
const PER_FILE_LINES = 50;

/**
 * Files coverage does not measure, because they are not measurable.
 *
 * Both end in a top-level `await main()`, so importing them RUNS them —
 * `naming.ts` exists precisely because of that, and says so: *"re-exporting
 * from it would run the bootstrap as a side effect of importing."* They are
 * scripts, not modules, and the same category as `main.dart` on the Flutter
 * side, which its coverage also cannot meaningfully cover.
 *
 * They are excluded from BOTH thresholds — including the global one — because
 * leaving 63 uncoverable lines in the denominator would make the repository
 * figure a measure of how much entry-point code exists.
 */
const NOT_MEASURABLE = ['packages/migrate/src/bootstrap.ts', 'packages/migrate/src/cli.ts'];

/**
 * Files below the per-file floor, each with the reason and its real target.
 *
 * **Empty as of Mission 8.1, and open item 127 is closed with it.** The list
 * held four entries when Mission 7.9 created it, every one of them testable
 * and exempt only because that mission chose not to take the work on in one
 * session. It said so at the time, and the entries carried targets rather than
 * waivers so the debt stayed legible.
 *
 * All four cleared their targets at Mission 8.1: `authorizer.ts` and
 * `caller.ts` to 100%, `runner.ts` to 98.21% against 70%, and `firebase.ts` to
 * 100% against 40%.
 *
 * **`firebase.ts` is the one worth reading twice.** Its target was 40% rather
 * than 50% because *"the ceiling here is real, not a matter of effort"* — the
 * remainder being a live token exchange no unit test can reach. That was half
 * right. The exchange is still unreachable; the code AROUND it was not, and it
 * was reached without exporting anything, by capturing the credential object
 * `initializeApp` receives and driving it directly. A ceiling estimated from
 * outside a file is a guess, and this one was 60 points low.
 *
 * Keep the mechanism below even while this is empty: an exemption is a floor
 * of its own, so anything added here fails the gate the moment it clears its
 * own target, and the list cannot quietly become permanent.
 */
const EXEMPT = {};

const summary = JSON.parse(
  readFileSync(new URL('../coverage/coverage-summary.json', import.meta.url), 'utf8'),
);

// `new URL('..')` keeps a trailing slash, and on Windows its pathname carries a
// leading slash before the drive letter. Both are stripped here rather than
// patched at the call site: getting either wrong makes every lookup in
// NOT_MEASURABLE and EXEMPT miss silently, and the gate then reports the
// entry-point scripts as failures — which is exactly how this was found.
const root = new URL('..', import.meta.url).pathname
  .replace(/^\/([A-Za-z]:)/, '$1')
  .replace(/\/$/, '');

const relative = (key) => key.replace(/\\/g, '/').replace(`${root}/`, '');

let covered = 0;
let total = 0;
const failures = [];
const exempted = [];

for (const [key, entry] of Object.entries(summary)) {
  if (key === 'total') continue;
  const file = relative(key);
  if (NOT_MEASURABLE.includes(file)) continue;

  const { pct, covered: c, total: t } = entry.lines;
  covered += c;
  total += t;

  // A file with no instrumented lines reports 100 and means nothing; skip it
  // rather than let it flatter the count.
  if (t === 0) continue;

  const exemption = EXEMPT[file];
  if (exemption) {
    exempted.push({ file, pct, ...exemption });
    // An exemption is a floor of its own: a file may not fall BELOW what it
    // measured when it was granted one, or the list stops meaning anything.
    if (pct > exemption.target) {
      failures.push(
        `${file} is at ${pct}% and its exemption targets ${exemption.target}% — it has cleared the bar, so remove it from EXEMPT.`,
      );
    }
    continue;
  }

  if (pct < PER_FILE_LINES) {
    failures.push(`${file} at ${pct}% is below the ${PER_FILE_LINES}% per-file floor.`);
  }
}

const globalPct = total === 0 ? 0 : Math.round((covered / total) * 10000) / 100;

console.log(`coverage: ${covered}/${total} lines (${globalPct}%)`);
console.log(`  global floor   ${GLOBAL_LINES}%`);
console.log(`  per-file floor ${PER_FILE_LINES}%`);
console.log(`  not measurable ${NOT_MEASURABLE.length} entry-point scripts`);

if (exempted.length > 0) {
  console.log(`\n  ${exempted.length} file(s) exempt from the per-file floor (open item 127):`);
  for (const e of exempted.sort((a, b) => a.file.localeCompare(b.file))) {
    console.log(`    ${e.file} — ${e.pct}%, target ${e.target}%`);
    console.log(`      ${e.why}`);
  }
}

if (globalPct < GLOBAL_LINES) {
  failures.push(`the repository is at ${globalPct}%, below the ${GLOBAL_LINES}% global floor.`);
}

if (failures.length > 0) {
  console.error('\ncoverage gate FAILED:');
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}

console.log('\ncoverage gate passed.');
