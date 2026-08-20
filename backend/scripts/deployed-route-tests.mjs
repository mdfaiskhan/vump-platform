/**
 * Two assertions against DEPLOYED routes. Neither can be made anywhere else.
 *
 * Run:  node scripts/deployed-route-tests.mjs race
 *       node scripts/deployed-route-tests.mjs forged-key
 *
 * ## Why this is a script and not a vitest file
 *
 * `npm test` runs in CI with no AWS credentials and no deployed API, so a test
 * that needs both would either be skipped — a green check measuring nothing —
 * or would fail every run. Both assertions here are manual verification steps
 * with a recorded result, which is what the unit tests explicitly cannot do:
 * `functions/redeem/src/index.test.ts` mocks the Data API, and a mock has no
 * row lock.
 *
 * ## The two assertions are SEPARATE and neither substitutes for the other
 *
 *   race        — two callers, one remaining use. Proves the decrement is
 *                 atomic in PostgreSQL, which is Phase 4's own gate.
 *   forged-key  — finalizeUpload with a key and upload id the chunk does not
 *                 own. Proves A-195's validation runs in production, which is
 *                 what CLOSES A-220.
 *
 * A-220 was written, tested, reviewed, merged and reported closed while the
 * deployed Lambda never received the fix. Running the race and reporting A-220
 * closed would repeat exactly that error at a smaller scale.
 */
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';

const REGION = process.env.AWS_REGION ?? 'ap-south-1';
const API = process.env.VUMP_API_URL;
const CODE = process.env.VUMP_TEST_CODE;
const CHUNK_ID = process.env.VUMP_TEST_CHUNK_ID;

function required(name, value) {
  if (value === undefined || value === '') {
    throw new Error(`${name} is not set.`);
  }
  return value;
}

async function post(path, body) {
  const started = Date.now();
  const response = await fetch(`${required('VUMP_API_URL', API)}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  let envelope;
  try {
    envelope = JSON.parse(text);
  } catch {
    envelope = { raw: text };
  }
  return { status: response.status, envelope, ms: Date.now() - started };
}

/**
 * Wakes the cluster and the container before the measurement.
 *
 * **Without this the race proves nothing**, and it would still pass. Redeem is
 * the one route exempt from the REQUEST authorizer, so nothing runs in front
 * of it and its first Data API call is the one that resumes Aurora — up to 30
 * seconds after a day idle. Fired cold, caller A spends that time waking the
 * cluster and caller B arrives afterwards on a warm container. The two
 * requests are then sequential, both assertions hold, and nothing about
 * locking was exercised.
 *
 * Uses a code that cannot exist, so the warm-up cannot itself spend a use.
 */
async function warmUp() {
  const probe = await post('/v1/auth/redeem', {
    email: `warmup-${String(Date.now())}@example.invalid`,
    password: 'warm-up-only',
    code: 'ZZZZWARMUPZZZZ',
  });
  console.log(`warm-up: ${String(probe.status)} in ${String(probe.ms)}ms`);
  return probe.ms;
}

async function race() {
  required('VUMP_TEST_CODE', CODE);

  const coldMs = await warmUp();
  const second = await warmUp();
  console.log(`second warm-up: ${String(second)}ms (cold was ${String(coldMs)}ms)\n`);

  if (second > 3000) {
    console.log('WARNING: the second warm-up still took over 3s. The container');
    console.log('may not be warm, and a race fired now may not be concurrent.');
  }

  const stamp = Date.now();
  const callers = [
    { email: `race-a-${String(stamp)}@example.com`, password: 'correct-horse-a' },
    { email: `race-b-${String(stamp)}@example.com`, password: 'correct-horse-b' },
  ];

  // Both promises created before either is awaited. Awaiting the first would
  // serialise them and the test would pass without testing anything.
  const results = await Promise.all(
    callers.map((caller) => post('/v1/auth/redeem', { ...caller, code: CODE })),
  );

  results.forEach((result, index) => {
    console.log(
      `caller ${String(index)}: ${String(result.status)} in ${String(result.ms)}ms — ` +
        JSON.stringify(result.envelope),
    );
  });

  const created = results.filter((r) => r.status === 201);
  const refused = results.filter((r) => r.envelope?.error?.code === 'AUTH_INVITE_CODE_INVALID');
  const spread = Math.abs(results[0].ms - results[1].ms);

  console.log(`\nlatency spread: ${String(spread)}ms`);
  console.log(`created: ${String(created.length)}   refused: ${String(refused.length)}`);

  // The concurrency check is an assertion, not a note. If the two calls did
  // not overlap, the counts below are satisfiable without any locking and the
  // run must not be recorded as a pass.
  const overlapped = spread < Math.min(results[0].ms, results[1].ms);
  console.log(`overlapped: ${String(overlapped)}`);

  const pass = created.length === 1 && refused.length === 1 && overlapped;
  console.log(`\n${pass ? 'PASS' : 'FAIL'}`);
  console.log('Now confirm by hand: remaining_uses is 0, and exactly ONE');
  console.log('Firebase account exists for this run.');
  process.exitCode = pass ? 0 : 1;
}

/**
 * A-220's actual closing assertion.
 *
 * `finalizeUpload` is reached by direct invoke rather than over HTTP — it is
 * the seam `chunks-verify` uses, not a route. A-195 made it read the chunk row
 * and refuse unless the supplied key AND upload id are the ones that chunk
 * owns. Before that fix it passed both straight to S3.
 *
 * Invoked with a real chunk id and a key that chunk does not own. A refusal
 * proves the validation is running in the deployed code; a success proves the
 * deployed Lambda is still the pre-fix one, whatever the repository says.
 */
async function forgedKey() {
  required('VUMP_TEST_CHUNK_ID', CHUNK_ID);

  const lambda = new LambdaClient({ region: REGION });

  // `action` is 'finalize-upload' — the exact string `isFinalizeRequest`
  // matches on, and there is no `parts` field. **Getting this wrong produces a
  // FALSE PASS**, which is why it is called out rather than merely written
  // correctly: an unrecognised payload falls through to the router, which
  // answers a 404 envelope containing "No handler is registered". A loose
  // "did it refuse?" check reads that as a refusal and reports A-220 closed,
  // having never reached `finalizeUpload` at all.
  const payload = {
    action: 'finalize-upload',
    chunkId: CHUNK_ID,
    key: 'forged/not-this-chunks-key',
    uploadId: 'forged-upload-id',
  };

  const started = Date.now();
  const out = await lambda.send(
    new InvokeCommand({
      FunctionName: `vump-${process.env.VUMP_ENV ?? 'dev'}-chunks-upload`,
      Payload: Buffer.from(JSON.stringify(payload)),
    }),
  );
  const ms = Date.now() - started;
  const body = Buffer.from(out.Payload ?? []).toString('utf8');

  console.log(`invoke: ${String(out.StatusCode)} in ${String(ms)}ms`);
  console.log(`functionError: ${out.FunctionError ?? '(none)'}`);
  console.log(`payload: ${body}`);

  // **The exact message A-195 raises**, not a keyword search. A generic
  // "did something fail?" check passes on a 404 from the router, on an
  // IAM denial, and on a cold-start crash — none of which is the validation
  // running. Only this string proves the comparison was reached and lost.
  const reachedTheCheck = body.includes('does not own the key or upload id supplied');
  const chunkMissing = body.includes('No chunk');

  console.log(`\nreached A-195's check: ${String(reachedTheCheck)}`);

  if (chunkMissing) {
    console.log('\nINCONCLUSIVE — that chunk id does not exist, so the row lookup');
    console.log('refused BEFORE the key comparison. Supply a real chunk id from');
    console.log('the chunks table. A-220 stays open.');
    process.exitCode = 1;
    return;
  }

  console.log(`\n${reachedTheCheck ? 'PASS — the forged key was refused' : 'FAIL'}`);
  if (!reachedTheCheck) {
    console.log('A-220 stays OPEN. If the invoke SUCCEEDED, the deployed code');
    console.log('predates A-195 — check S3 for an object at the forged key.');
  }
  process.exitCode = reachedTheCheck ? 0 : 1;
}

const mode = process.argv[2];
if (mode === 'race') {
  await race();
} else if (mode === 'forged-key') {
  await forgedKey();
} else {
  console.log('usage: node scripts/deployed-route-tests.mjs race|forged-key');
  process.exitCode = 1;
}
