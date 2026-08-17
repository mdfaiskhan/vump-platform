/**
 * `vump-migrate` — applies the migrations in `backend/migrations/`.
 *
 * Run deliberately, by a human, never by CI. Same rule as `terraform apply`
 * (folder-structure.md §1.3): a pipeline that can migrate a database is a
 * pipeline that can drop one.
 *
 * Resolves the cluster and the **master** credential from AWS rather than from
 * environment variables, because a migration creates roles and grants and is
 * the one caller that legitimately needs the master credential. The per-function
 * credentials it creates are deliberately less privileged than itself.
 */
import { RDSClient, DescribeDBClustersCommand } from '@aws-sdk/client-rds';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { StatementTarget } from '@vump/shared';
import { runMigrations, loadMigrations } from './runner.js';

const MIGRATIONS_DIR = join(
  dirname(dirname(dirname(dirname(fileURLToPath(import.meta.url))))),
  'migrations',
);

async function resolveTarget(region: string, clusterId: string): Promise<StatementTarget> {
  const rds = new RDSClient({ region });
  const out = await rds.send(new DescribeDBClustersCommand({ DBClusterIdentifier: clusterId }));
  const cluster = out.DBClusters?.[0];

  const resourceArn = cluster?.DBClusterArn;
  const secretArn = cluster?.MasterUserSecret?.SecretArn;
  const database = cluster?.DatabaseName;

  if (resourceArn === undefined || secretArn === undefined || database === undefined) {
    throw new Error(
      `Cluster ${clusterId} in ${region} did not report an ARN, a master secret and a database ` +
        'name. Has Mission 6.1 been applied?',
    );
  }
  return { resourceArn, secretArn, database };
}

async function main(): Promise<void> {
  const region = process.env.AWS_REGION ?? 'ap-south-1';
  const slug = process.env.VUMP_ENV ?? 'dev';
  const clusterId = `vump-${slug}-aurora`;
  const dryRun = process.argv.includes('--dry-run');

  const migrations = await loadMigrations(MIGRATIONS_DIR);
  console.log(`migrations : ${String(migrations.length)} file(s) in ${MIGRATIONS_DIR}`);
  console.log(`cluster    : ${clusterId} (${region})`);

  if (dryRun) {
    console.log('\n--dry-run: parsing only, nothing is sent to the database.\n');
    const { splitStatements } = await import('./split.js');
    for (const migration of migrations) {
      const statements = splitStatements(migration.sql);
      console.log(
        `  ${migration.id}_${migration.name.padEnd(28)} ${String(statements.length).padStart(3)} statement(s)`,
      );
    }
    return;
  }

  const target = await resolveTarget(region, clusterId);
  console.log(`database   : ${target.database}\n`);

  const result = await runMigrations(MIGRATIONS_DIR, target, {
    onSkip: (m) => {
      console.log(`  = ${m.id}_${m.name} (already applied)`);
    },
    onStart: (m, n) => {
      console.log(`  + ${m.id}_${m.name} — ${String(n)} statement(s)`);
    },
    onDone: (m) => {
      console.log(`    committed ${m.id}`);
    },
  });

  console.log(
    `\napplied ${String(result.applied.length)}, skipped ${String(result.skipped.length)}`,
  );
}

await main();
