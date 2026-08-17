/**
 * `vump-db-bootstrap` — gives each per-function database role a password, and
 * writes it to that function's Secrets Manager secret.
 *
 * ## Why this is a separate command and not a migration
 *
 * Migration `0007` creates the roles **NOLOGIN**. It has to: migrations are
 * committed to git, and `CREATE ROLE … LOGIN PASSWORD '…'` in one would be a
 * credential in source control — which ADR-016 treats as permanent disclosure,
 * because "deleting it in a later commit does not remove it from history".
 *
 * ## Why it is not Terraform either
 *
 * A `random_password` resource would put every database credential into
 * Terraform state. ADR-043 keeps the master password out of state by using
 * `manage_master_user_password`; putting seven others in would undo that for a
 * larger set of credentials.
 *
 * So the password is generated here, sent to PostgreSQL once and to Secrets
 * Manager once, and exists nowhere else — not in a file, not in state, not in
 * this process's output.
 *
 * ## Idempotent, and safe to re-run
 *
 * Re-running rotates every password: it sets a new one on the role and writes
 * the same new value to the secret, in that order, so the two cannot disagree
 * for longer than the gap between two calls. A function reading a cached
 * credential will fail once and succeed on the retry.
 */
import { randomBytes } from 'node:crypto';
import { RDSClient, DescribeDBClustersCommand } from '@aws-sdk/client-rds';
import {
  SecretsManagerClient,
  PutSecretValueCommand,
  DescribeSecretCommand,
} from '@aws-sdk/client-secrets-manager';
import { execute, type StatementTarget } from '@vump/shared';
import { roleFor, secretNameFor } from './naming.js';

/** ADR-015's six domains, with chunks split per A-143. */
const FUNCTIONS = [
  'auth-verify',
  'projects',
  'tasks',
  'sessions',
  'chunks-upload',
  'chunks-verify',
  'metadata',
] as const;

/**
 * A password with no character that needs escaping in a SQL literal.
 *
 * base64url is `A–Z a–z 0–9 - _`, so the value can be interpolated into
 * `ALTER ROLE … PASSWORD '…'` without quoting concerns — there is no quote to
 * escape and no way for the value to end the literal early. 48 bytes is 384
 * bits of entropy.
 */
function generatePassword(): string {
  return randomBytes(48).toString('base64url');
}

async function resolveTarget(region: string, clusterId: string): Promise<StatementTarget> {
  const rds = new RDSClient({ region });
  const out = await rds.send(new DescribeDBClustersCommand({ DBClusterIdentifier: clusterId }));
  const cluster = out.DBClusters?.[0];
  const resourceArn = cluster?.DBClusterArn;
  const secretArn = cluster?.MasterUserSecret?.SecretArn;
  const database = cluster?.DatabaseName;
  if (resourceArn === undefined || secretArn === undefined || database === undefined) {
    throw new Error(`Cluster ${clusterId} did not report an ARN, master secret and database name.`);
  }
  return { resourceArn, secretArn, database };
}

async function main(): Promise<void> {
  const region = process.env.AWS_REGION ?? 'ap-south-1';
  const slug = process.env.VUMP_ENV ?? 'dev';
  const clusterId = `vump-${slug}-aurora`;

  const target = await resolveTarget(region, clusterId);
  const secrets = new SecretsManagerClient({ region });

  console.log(`cluster : ${clusterId} (${region})`);
  console.log(`database: ${target.database}\n`);

  for (const fn of FUNCTIONS) {
    const role = roleFor(fn);
    const secretName = secretNameFor(slug, fn);

    // Fail early and clearly if Terraform has not created the container yet,
    // rather than after the role password has already been changed.
    try {
      await secrets.send(new DescribeSecretCommand({ SecretId: secretName }));
    } catch {
      throw new Error(
        `Secret ${secretName} does not exist. Run \`terraform apply\` in ` +
          'infrastructure/terraform/environments/' +
          slug +
          ' first — it creates the containers this command fills.',
      );
    }

    const password = generatePassword();

    // Role first, secret second. If the process dies between them the secret
    // holds a stale password and the function fails loudly; the reverse order
    // would leave a working credential nobody can read.
    await execute(`ALTER ROLE ${role} WITH LOGIN PASSWORD '${password}'`, { target });

    await secrets.send(
      new PutSecretValueCommand({
        SecretId: secretName,
        // The shape the Data API requires: username and password at minimum.
        // The rest is context for a human reading the secret, and none of it is
        // itself secret.
        SecretString: JSON.stringify({
          username: role,
          password,
          engine: 'postgres',
          dbClusterIdentifier: clusterId,
          dbname: target.database,
        }),
      }),
    );

    // The password is never printed. Only that one was set.
    console.log(`  ${fn.padEnd(14)} role ${role.padEnd(20)} -> ${secretName}`);
  }

  console.log(`\n${String(FUNCTIONS.length)} credential(s) set.`);
  console.log('No password was printed, written to a file, or stored in Terraform state.');
}

await main();
