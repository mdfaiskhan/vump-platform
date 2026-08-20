import { fileURLToPath } from 'node:url';

import { defineConfig } from 'vitest/config';

/**
 * Vitest, chosen in Mission 6.2.1.
 *
 * `aws-sdk-client-mock` is the reason the choice needed testing rather than
 * assuming: it is Jest-shaped by reputation. Verified against Vitest 4.1.10 and
 * `aws-sdk-client-mock` 4.1.0 before this file was written — stubbing a
 * command, inspecting recorded calls, rejecting, and `reset()` between tests
 * all work. Recorded as amendment A-149.
 */
export default defineConfig({
  // `@vump/shared` resolves to SOURCE here, not to `dist/`.
  //
  // Its `main` is `./dist/index.js`, so without this every function test
  // exercises the shared package as compiled JavaScript. The tests pass either
  // way — but coverage's `include` below names `src/**/*.ts`, so all of that
  // execution lands on files coverage is not watching and is attributed to
  // nothing.
  //
  // **The effect was large and entirely an artefact.** Measured at Mission 7.9
  // before and after: `row.ts` 0% -> 76%, `request.ts` 0% -> 71%,
  // `transaction.ts` 0% -> 88%, `handler.ts` 73% -> 100%, and the repository
  // total 66.33% -> 75.02%. Every file reading 0% was one with no co-located
  // test — not one that nothing executed.
  //
  // A threshold set on the unaliased numbers would have been a gate on a
  // measurement error: it would fail files that are well covered and pass a
  // codebase whose real figure it had never seen.
  resolve: {
    alias: {
      '@vump/shared': fileURLToPath(new URL('./packages/shared/src/index.ts', import.meta.url)),
    },
  },
  test: {
    include: ['**/*.test.ts'],
    exclude: ['**/node_modules/**', '**/dist/**'],
    environment: 'node',
    // Coverage is GATED as of Mission 7.9 — see `scripts/check-coverage.mjs`,
    // which owns the thresholds and the exemptions. ADR-045 recorded the gate
    // as deliberately absent and named the condition for revisiting it:
    // "A numeric gate becomes reasonable when 6.3 gives the handlers real
    // behaviour to cover." That condition was met at 6.3 and again at 7.3.
    //
    // The thresholds are NOT here because Vitest cannot express them: it has
    // one number, read as a repository total or — with `perFile` — as a
    // uniform per-file floor, never both, and its glob entries aggregate
    // rather than applying per file. The script explains that at length.
    coverage: {
      provider: 'v8',
      // `json-summary` is what `scripts/check-coverage.mjs` reads; `text` is
      // what a human reads when the gate fails and wants to know which file.
      reporter: ['text-summary', 'json-summary'],
      include: ['packages/*/src/**/*.ts', 'functions/*/src/**/*.ts'],
    },
  },
});
