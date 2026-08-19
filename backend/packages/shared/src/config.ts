/**
 * Environment configuration, read once per cold start.
 *
 * Mirrors `backend/.env.example`, which ADR-016 established as the contract
 * before any code existed. Everything here is **non-secret** by ADR-016's tier
 * test: a bucket name, a region, an environment key and a secret *ARN*. An ARN
 * is an identifier — possessing it grants nothing without IAM permission to
 * read what sits behind it.
 *
 * No secret VALUE is read here, and none may be. Volume 8, Chapter 8.4 §2:
 * secrets are *"never baked into a Lambda's plaintext environment variables,
 * which would be visible to anyone with read access to the function's
 * configuration"*.
 */

/** One of the three ADR-014 environments. */
export type AppEnv = 'development' | 'staging' | 'production';

/** Resolved, validated configuration. */
export interface BackendConfig {
  readonly appEnv: AppEnv;
  readonly region: string;
  readonly chunkBucket: string;
  readonly presignExpirySeconds: number;
  /** Aurora cluster ARN — the `resourceArn` every `rds-data` call names. */
  readonly clusterArn: string;
  /** ARN of the RDS-managed master credential. Not the credential. */
  readonly databaseCredentialsSecretArn: string;
  /** Initial database name. */
  readonly databaseName: string;
  /** Firebase project id. Public — ADR-016 and ADR-010 both record why. */
  readonly firebaseProjectId: string;
  /**
   * The `chunks-upload` function's name, for the Fork 1 seam.
   *
   * `chunks-verify` invokes it to finalise a multipart upload, because
   * `CompleteMultipartUpload` needs `s3:PutObject` and A-143 keeps that away
   * from the role that reads footage. A name rather than an ARN: the ARN is
   * derivable and the name is what `InvokeCommand` takes.
   *
   * Supplied to every function rather than one, because `lambda_environment` is
   * shared and a per-function variable would need the same seam in Terraform
   * that `DATABASE_CREDENTIALS_SECRET_ARN` already has. It is not a secret and
   * confers nothing without the matching `lambda:InvokeFunction` grant, which
   * only `chunks-verify` holds.
   */
  readonly uploadFunctionName: string;
}

function required(name: string): string {
  const value = process.env[name];
  if (value === undefined || value === '') {
    // Fails at cold start rather than at first request. ADR-017's
    // environment-driven startup failure applied to the backend: a function
    // that boots without its configuration and fails later is harder to
    // diagnose than one that refuses to boot.
    throw new Error(`Required environment variable ${name} is not set.`);
  }
  return value;
}

function requiredEnum(name: string): AppEnv {
  const value = required(name);
  if (value !== 'development' && value !== 'staging' && value !== 'production') {
    throw new Error(
      `${name} is "${value}"; expected development, staging or production (ADR-014). ` +
        'Note this is the APP_ENV key, not the AWS slug — see naming-conventions.md §7.1.',
    );
  }
  return value;
}

let cached: BackendConfig | undefined;

/**
 * Reads and validates configuration, caching across warm invocations.
 *
 * Cached because Lambda reuses an execution environment and re-reading is
 * pointless work on every request. Exposed as a function rather than a const so
 * that a test can reset it.
 */
export function loadConfig(): BackendConfig {
  if (cached !== undefined) {
    return cached;
  }
  cached = {
    appEnv: requiredEnum('APP_ENV'),
    region: required('AWS_REGION'),
    chunkBucket: required('CHUNK_BUCKET'),
    presignExpirySeconds: Number.parseInt(required('PRESIGN_EXPIRY_SECONDS'), 10),
    clusterArn: required('DATABASE_CLUSTER_ARN'),
    databaseCredentialsSecretArn: required('DATABASE_CREDENTIALS_SECRET_ARN'),
    databaseName: required('DATABASE_NAME'),
    firebaseProjectId: required('FIREBASE_PROJECT_ID'),
    uploadFunctionName: required('UPLOAD_FUNCTION_NAME'),
  };
  return cached;
}

/** Clears the cache. Tests only. */
export function resetConfigForTest(): void {
  cached = undefined;
}
