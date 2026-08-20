/**
 * `redeem` route behaviour, against a mocked Data API and a mocked Admin SDK.
 *
 * ## What these tests can and cannot establish
 *
 * They cover validation, the decrement statement's shape, the ordering of the
 * three side effects, and the failure compensator. **They cannot establish
 * that the decrement is atomic** — a mock has no row lock, so a test that
 * "proves" the race here proves only that the mock returned what it was told
 * to. That is the A-212 shape exactly, and it is why Phase 4 requires a real
 * two-caller race against the DEPLOYED route.
 *
 * Nor can they establish that Workload Identity Federation works: the Admin
 * SDK is mocked here, so no token is ever exchanged. That is the deployed
 * test's job too.
 *
 * What they do is pin the decisions — the ordering, the literal role, disable
 * rather than delete, one error code for every rejection — so a later edit
 * that quietly reverses one fails here rather than in production.
 */
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mockClient } from 'aws-sdk-client-mock';
import { RDSDataClient, ExecuteStatementCommand } from '@aws-sdk/client-rds-data';
import type { APIGatewayProxyEvent } from 'aws-lambda';

import { resetConfigForTest, resetDataApiClientForTest } from '@vump/shared';

const createUser = vi.fn();
const setCustomUserClaims = vi.fn();
const updateUser = vi.fn();

vi.mock('./firebase.js', () => ({
  federatedAuth: () => ({ createUser, setCustomUserClaims, updateUser }),
}));

const { handler } = await import('./index.js');

const rds = mockClient(RDSDataClient);

const ENV = {
  APP_ENV: 'development',
  AWS_REGION: 'ap-south-1',
  CHUNK_BUCKET: 'vump-platform-dev',
  PRESIGN_EXPIRY_SECONDS: '3600',
  DATABASE_CLUSTER_ARN: 'arn:aws:rds:ap-south-1:000000000000:cluster:vump-dev-aurora',
  DATABASE_CREDENTIALS_SECRET_ARN: 'arn:aws:secretsmanager:ap-south-1:000000000000:secret:x',
  DATABASE_NAME: 'vump_dev',
  FIREBASE_PROJECT_ID: 'vump-platform-f86af',

  // Redeem will never invoke chunks-upload, and `loadConfig` requires this
  // anyway — it validates every field eagerly, for every function. The
  // deployed function does receive it, because Terraform's
  // `lambda_environment` is shared across all eight, so this matches reality
  // rather than papering over a gap. Worth knowing that the coupling exists:
  // removing this from the shared map would 500 a route unrelated to it.
  UPLOAD_FUNCTION_NAME: 'vump-dev-chunks-upload',
};

const DEFAULT_ORG = '00000000-0000-4000-8000-000000000001';
const CODE_ORG = '99999999-9999-4999-8999-999999999999';

interface Envelope {
  readonly data: { readonly uid: string; readonly orgId: string };
  readonly error: { readonly code: string };
}

function event(body: unknown): APIGatewayProxyEvent {
  return {
    httpMethod: 'POST',
    resource: '/v1/auth/redeem',
    headers: {},
    body: JSON.stringify(body),
  } as unknown as APIGatewayProxyEvent;
}

async function redeem(body: unknown): Promise<{ status: number; envelope: Envelope }> {
  const response = (await handler(event(body))) as { statusCode: number; body: string };
  return { status: response.statusCode, envelope: JSON.parse(response.body) as Envelope };
}

beforeEach(() => {
  Object.assign(process.env, ENV);
  resetConfigForTest();
  resetDataApiClientForTest();
  rds.reset();
  createUser.mockReset();
  setCustomUserClaims.mockReset();
  updateUser.mockReset();
  createUser.mockResolvedValue({ uid: 'firebase-uid' });
  setCustomUserClaims.mockResolvedValue(undefined);
  updateUser.mockResolvedValue(undefined);
});

afterEach(() => {
  for (const key of Object.keys(ENV)) {
    process.env[key] = undefined;
  }
});

describe('validation', () => {
  it.each([
    ['no email', { password: 'hunter22' }],
    ['no password', { email: 'a@b.com' }],
    ['an empty password', { email: 'a@b.com', password: '' }],
    ['a non-alphanumeric code', { email: 'a@b.com', password: 'hunter22', code: 'AB/CD' }],
    ['an over-long code', { email: 'a@b.com', password: 'hunter22', code: 'A'.repeat(65) }],
  ])('refuses %s before touching anything', async (_name, body) => {
    const { status, envelope } = await redeem(body);

    expect(status).toBe(400);
    expect(envelope.error.code).toBe('REQUEST_INVALID');

    // The point of validating first: nothing was spent and nothing created.
    expect(rds.commandCalls(ExecuteStatementCommand)).toHaveLength(0);
    expect(createUser).not.toHaveBeenCalled();
  });

  it('treats a blank code as no code at all', async () => {
    const { status, envelope } = await redeem({
      email: 'a@b.com',
      password: 'hunter22',
      code: '   ',
    });

    // Not a validation failure. It joins the default organisation, which is
    // what omitting the field does — A-056.
    expect(status).toBe(201);
    expect(envelope.data.orgId).toBe(DEFAULT_ORG);
    expect(rds.commandCalls(ExecuteStatementCommand)).toHaveLength(0);
  });
});

describe('the invite code', () => {
  it('spends one use and joins the organisation the code names', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [[{ stringValue: CODE_ORG }]] });

    const { status, envelope } = await redeem({
      email: 'a@b.com',
      password: 'hunter22',
      code: 'abc123',
    });

    expect(status).toBe(201);
    expect(envelope.data.orgId).toBe(CODE_ORG);

    const input = rds.commandCalls(ExecuteStatementCommand)[0]?.args[0].input;

    // The decision and the decrement are ONE statement. A separate SELECT
    // followed by an UPDATE would satisfy every other assertion here and lose
    // the atomicity the deployed race test exists to check.
    expect(input?.sql).toContain('UPDATE org_invite_codes');
    expect(input?.sql).toContain('RETURNING org_id');
    expect(input?.sql).toContain('expires_at > now()');

    // Upper-cased and trimmed before it reaches the database.
    expect(input?.parameters?.[0]?.value?.stringValue).toBe('ABC123');
  });

  it('refuses when the code returns no row, and creates nothing', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [] });

    const { status, envelope } = await redeem({
      email: 'a@b.com',
      password: 'hunter22',
      code: 'GONE',
    });

    expect(status).toBe(404);
    expect(envelope.error.code).toBe('AUTH_INVITE_CODE_INVALID');

    // F1: an invalid code creates nothing, so there is nothing to observe.
    expect(createUser).not.toHaveBeenCalled();
  });

  it('reports a taken address as an invalid code, not as a taken address', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [[{ stringValue: CODE_ORG }]] });
    createUser.mockRejectedValue({ code: 'auth/email-already-exists' });

    const { status, envelope } = await redeem({
      email: 'a@b.com',
      password: 'hunter22',
      code: 'ABC',
    });

    // The enumeration oracle F1 removed. Same code and same status either way.
    expect(status).toBe(404);
    expect(envelope.error.code).toBe('AUTH_INVITE_CODE_INVALID');
  });
});

describe('account provisioning', () => {
  it('hard-locks the role to collector', async () => {
    await redeem({ email: 'a@b.com', password: 'hunter22' });

    expect(setCustomUserClaims).toHaveBeenCalledWith('firebase-uid', {
      role: 'collector',
      org_id: DEFAULT_ORG,
    });
  });

  it('cannot be talked into an admin by the request body', async () => {
    await redeem({ email: 'a@b.com', password: 'hunter22', role: 'admin', org_id: 'elsewhere' });

    expect(setCustomUserClaims).toHaveBeenCalledWith('firebase-uid', {
      role: 'collector',
      org_id: DEFAULT_ORG,
    });
  });

  it('disables rather than deletes an account whose claims could not be set', async () => {
    setCustomUserClaims.mockRejectedValue(new Error('permission denied'));

    const { status } = await redeem({ email: 'a@b.com', password: 'hunter22' });

    expect(status).toBe(500);

    // Blocker 2's ruling. The custom role holds users.create and users.update
    // and NOT users.delete, so deleteUser would fail inside the error handler —
    // and adding the permission would hand a leaked federated identity the
    // ability to destroy accounts.
    expect(updateUser).toHaveBeenCalledWith('firebase-uid', { disabled: true });
  });

  it('does not restore the spent use when provisioning fails', async () => {
    rds.on(ExecuteStatementCommand).resolves({ records: [[{ stringValue: CODE_ORG }]] });
    setCustomUserClaims.mockRejectedValue(new Error('permission denied'));

    await redeem({ email: 'a@b.com', password: 'hunter22', code: 'ABC' });

    // F15. Exactly one statement ran — the decrement. A compensating increment
    // is a write that can itself fail, and A-056 made the counter
    // non-load-bearing.
    expect(rds.commandCalls(ExecuteStatementCommand)).toHaveLength(1);
  });
});
