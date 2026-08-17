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
  test: {
    include: ['**/*.test.ts'],
    exclude: ['**/node_modules/**', '**/dist/**'],
    environment: 'node',
    // Coverage is reported, not gated. ADR-045 records why: Volume 9's targets
    // are Dart-shaped percentages against a four-layer feature structure that a
    // Lambda handler does not have, and a number invented to look like one
    // would be a gate nobody chose.
    coverage: {
      provider: 'v8',
      reporter: ['text-summary'],
      include: ['packages/*/src/**/*.ts', 'functions/*/src/**/*.ts'],
    },
  },
});
