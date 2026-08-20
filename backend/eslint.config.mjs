// ESLint for the backend.
//
// ADR-021 governs static analysis for `mobile/` and says so explicitly:
// "backend/ is empty and is Node/TypeScript per ADR-015 … A root config would
// govern nothing." This is the backend's own configuration, and ADR-045 is the
// record that governs it.
//
// The posture is ADR-021's, not its rule list: strictness is adopted while the
// tree is small, because "strictness is cheap now and expensive later, and it
// never gets cheaper".

import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['**/dist/**', '**/node_modules/**', '**/*.d.ts', 'artifacts/**'],
  },

  js.configs.recommended,

  // Type-aware linting, scoped to TypeScript.
  //
  // Scoped rather than global because the type-aware rules need a file to be
  // part of a TypeScript project, and `scripts/*.mjs` is not in any tsconfig.
  // Applying them everywhere fails at load with "you have used a rule which
  // requires type information" — an error about the config, reported against
  // the file, which is a confusing place to start debugging.
  //
  // The non-type-aware set cannot see an unawaited promise or an `any` crossing
  // a module boundary, which is most of what matters in a handler that awaits
  // I/O — so scoping it down is not a softening.
  {
    files: ['**/*.ts'],
    extends: [...tseslint.configs.strictTypeChecked, ...tseslint.configs.stylisticTypeChecked],
    languageOptions: {
      parserOptions: {
        projectService: {
          // Two files belong to no package: the Vitest config, which
          // configures the runner rather than shipping, and the route
          // inventory test, which spans all seven functions and so cannot sit
          // inside any one of them. tsconfig.tools.json gives both a real type
          // context, so they are checked with the same strictness as the rest
          // rather than exempted.
          allowDefaultProject: ['vitest.config.ts', 'functions/routes.test.ts'],
          defaultProject: 'tsconfig.tools.json',
        },
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // A floating promise in a handler is a request that returns before its
      // work finishes.
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',

      // Matches the tsconfig's noUnusedLocals/noUnusedParameters. The
      // underscore escape is kept for deliberately-ignored parameters, which
      // the scaffold has several of.
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],

      // Volume 8, Chapter 8.3 §2 requires strict validation before a query
      // runs; `any` at a boundary is how validation gets skipped by accident.
      '@typescript-eslint/no-explicit-any': 'error',

      // console is the CloudWatch transport — see packages/shared/src/logger.ts.
      // Allowed there and nowhere else.
      'no-console': 'error',
    },
  },

  {
    // console is the CloudWatch transport in the logger, and the actual output
    // of the two migration commands — a CLI that cannot print is not a CLI.
    files: [
      'packages/shared/src/logger.ts',
      'packages/migrate/src/cli.ts',
      'packages/migrate/src/bootstrap.ts',
    ],
    rules: { 'no-console': 'off' },
  },

  {
    // Tests assert on parsed JSON, which is `any` by construction.
    files: ['**/*.test.ts'],
    rules: {
      '@typescript-eslint/no-unsafe-assignment': 'off',
      '@typescript-eslint/no-unsafe-member-access': 'off',
      '@typescript-eslint/no-unsafe-argument': 'off',
      '@typescript-eslint/no-unsafe-call': 'off',
    },
  },

  {
    // Build tooling: plain Node ESM, not part of a TypeScript project, and its
    // whole job is to print what it built.
    files: ['scripts/**/*.mjs'],
    languageOptions: {
      // `fetch` and `Buffer` are Node 24 globals, added for the deployed-route
      // tests — one calls the live API over HTTP, the other reads an
      // `aws lambda invoke` response payload.
      globals: {
        console: 'readonly',
        process: 'readonly',
        fetch: 'readonly',
        Buffer: 'readonly',
      },
    },
    rules: { 'no-console': 'off' },
  },
);
