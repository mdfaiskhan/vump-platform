// Bundles each function into a single file with esbuild.
//
// One bundle per function, tree-shaken, so that ADR-015's cold-start argument
// survives the shared package: "the AWS SDK for JavaScript v3 is modular, so
// each function bundles only the clients it uses — which keeps cold-start cost
// proportional to what a function actually does". A workspace with shared code
// only keeps that property if the bundler drops what each entry point does not
// reach, which is what `bundle: true` plus `treeShaking` does here.
//
// Output goes to `artifacts/<function>/index.mjs`. Terraform zips that
// directory — see infrastructure/terraform/modules/api-gateway.

import { build } from 'esbuild';
import { readdir, rm, mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const functionsDir = join(root, 'functions');
const outRoot = join(root, 'artifacts');

// The Lambda runtime is nodejs24.x — chosen in Mission 6.2.1 after checking
// what Lambda actually supports today. nodejs22.x deprecates 30 Apr 2027 and
// nodejs26.x is public preview, so 24 is the only GA runtime with a horizon
// worth building on. Keep this in step with `engines` and the Terraform.
const TARGET = 'node24';

async function main() {
  await rm(outRoot, { recursive: true, force: true });
  await mkdir(outRoot, { recursive: true });

  const names = (await readdir(functionsDir, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();

  if (names.length === 0) {
    throw new Error('No functions found under backend/functions/.');
  }

  for (const name of names) {
    const outfile = join(outRoot, name, 'index.mjs');
    const result = await build({
      entryPoints: [join(functionsDir, name, 'src', 'index.ts')],
      outfile,
      bundle: true,
      treeShaking: true,
      platform: 'node',
      target: TARGET,
      format: 'esm',
      sourcemap: false,
      minify: false,
      // The v3 SDK ships in the runtime, but AWS recommends bundling it so an
      // automatic runtime update cannot change the SDK under a function. The
      // Lambda docs are explicit: "we recommend that you always include the SDK
      // modules your code uses (along with any dependencies) in your function's
      // deployment package".
      external: [],
      // ESM output needs this shim: some transitive CommonJS dependencies call
      // require(), which does not exist in an ESM bundle.
      banner: {
        js: [
          "import { createRequire as __createRequire } from 'node:module';",
          'const require = __createRequire(import.meta.url);',
        ].join('\n'),
      },
      logLevel: 'warning',
      metafile: true,
    });

    const bytes = Object.values(result.metafile.outputs).reduce((sum, o) => sum + o.bytes, 0);
    console.log(`  ${name.padEnd(14)} ${(bytes / 1024).toFixed(0).padStart(6)} KiB`);
  }

  console.log(`\nBundled ${String(names.length)} function(s) to artifacts/`);
}

await main();
