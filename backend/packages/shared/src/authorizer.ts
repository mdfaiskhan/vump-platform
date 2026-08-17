/**
 * The API Gateway REQUEST authorizer — ADR-048.
 *
 * Chapter 4.8 §2's middleware chain begins *"1. Authenticate (Chapter 4.7) —
 * attaches user, role, org_id"*, and every one of Chapter 4.6's endpoints is
 * supposed to run behind it. Doing that inside each function would need every
 * function to read `users`, which Volume 8 Chapter 8.4 §1 forbids and which
 * migration `0007` enforces in PostgreSQL — only `vump_auth_verify` holds the
 * grant.
 *
 * An authorizer resolves that: **one** function reads `users`, and API Gateway
 * attaches the result to every downstream request. It is the native mechanism
 * for exactly the shape Chapter 4.8 §2 describes.
 *
 * ## What it returns
 *
 * An IAM policy plus a context map. The context becomes
 * `event.requestContext.authorizer` in the target function, so a handler reads
 * `userId`/`orgId`/`role` without a query and without a grant.
 *
 * **Context values are strings.** API Gateway stringifies everything in this
 * map; numbers and booleans arrive as `"1"` / `"true"`. Only strings are put
 * in, so nothing has to be parsed back out.
 *
 * ## Deny, not Allow-with-a-flag
 *
 * A failed lookup returns an explicit `Deny`, so API Gateway refuses the
 * request before the target function is invoked at all. Returning `Allow` with
 * an "unauthenticated" flag would push the decision into fifteen handlers, any
 * one of which could forget it.
 */
import type {
  APIGatewayRequestAuthorizerEvent,
  APIGatewayAuthorizerResult,
  PolicyDocument,
} from 'aws-lambda';
import { bearerToken, verifyToken } from './auth.js';
import { lookupCaller } from './caller.js';
import { logger } from './logger.js';

function policy(effect: 'Allow' | 'Deny', resource: string): PolicyDocument {
  return {
    Version: '2012-10-17',
    Statement: [{ Action: 'execute-api:Invoke', Effect: effect, Resource: resource }],
  };
}

/**
 * Whether an event is an authorizer invocation rather than a proxied request.
 *
 * `auth-verify` is invoked both ways — as the authorizer for fourteen routes,
 * and as the handler for its own two. The discriminator is `type`, which only
 * an authorizer event carries.
 */
export function isAuthorizerEvent(event: unknown): event is APIGatewayRequestAuthorizerEvent {
  return (
    typeof event === 'object' &&
    event !== null &&
    (event as { type?: unknown }).type === 'REQUEST' &&
    typeof (event as { methodArn?: unknown }).methodArn === 'string'
  );
}

/**
 * Verifies the token and resolves the caller, or denies.
 *
 * The policy resource is the **specific** `methodArn` rather than a wildcard.
 * A wildcard would be cached by API Gateway and reused across routes, which
 * turns one allowed request into a blanket grant for the caching window.
 */
export async function authorize(
  event: APIGatewayRequestAuthorizerEvent,
): Promise<APIGatewayAuthorizerResult> {
  const started = Date.now();
  const header = event.headers?.authorization ?? event.headers?.Authorization;

  try {
    const identity = await verifyToken(bearerToken(header));
    const caller = await lookupCaller(identity);

    logger.info('authorized', {
      firebaseUid: identity.firebaseUid,
      durationMs: Date.now() - started,
    });

    return {
      principalId: identity.firebaseUid,
      policyDocument: policy('Allow', event.methodArn),
      context: {
        userId: caller.userId,
        orgId: caller.orgId,
        role: caller.role,
        firebaseUid: identity.firebaseUid,
      },
    };
  } catch (thrown) {
    // The cause is logged and never returned. API Gateway renders a Deny as a
    // bare 403 with no body, which is the correct amount to tell an
    // unauthenticated caller.
    logger.warn('authorization denied', {
      durationMs: Date.now() - started,
      cause: thrown instanceof Error ? thrown.message : String(thrown),
    });
    return {
      principalId: 'unauthorized',
      policyDocument: policy('Deny', event.methodArn),
    };
  }
}
