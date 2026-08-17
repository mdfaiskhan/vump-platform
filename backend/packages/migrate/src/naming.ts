/**
 * Names shared between the bootstrap command and anything that needs to know
 * them.
 *
 * Separate from `bootstrap.ts` deliberately: that module ends in a top-level
 * `await main()`, so re-exporting from it would run the bootstrap as a side
 * effect of importing the package. Pure functions belong where importing them
 * does nothing.
 */

/** The database role for a function. `-` is not legal in an unquoted role. */
export function roleFor(functionName: string): string {
  return `vump_${functionName.replace(/-/g, '_')}`;
}

/** The secret name for a function, per ADR-016's `vump/{env}/{name}`. */
export function secretNameFor(slug: string, functionName: string): string {
  return `vump/${slug}/db-${functionName}`;
}
