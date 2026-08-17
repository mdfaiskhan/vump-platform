/**
 * Method-and-resource dispatch inside a single Lambda.
 *
 * ADR-015 fixes *"one function per resource domain"*, and Chapter 4.6 gives
 * most domains several routes — `tasks` has five. So a function is not a single
 * endpoint, and something has to map an incoming request onto the right
 * handler. This is that, and nothing more: no framework, no middleware stack,
 * no path parsing.
 *
 * Keyed on `event.resource` rather than `event.path`, because `resource` is the
 * **template** API Gateway matched (`/v1/tasks/{taskId}`) while `path` is the
 * concrete request (`/v1/tasks/abc-123`). Matching on the template means the
 * table here is the same string that appears in the Terraform, and a route that
 * exists in one and not the other is a visible mismatch rather than a 404 that
 * only shows up at runtime.
 */
import type { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { failure } from './envelope.js';
import { logger } from './logger.js';

/** A wrapped handler, as returned by `withEnvelope`. */
export type WrappedHandler = (event: APIGatewayProxyEvent) => Promise<APIGatewayProxyResult>;

/** `"METHOD /resource/template"` → handler. */
export type RouteTable = Record<string, WrappedHandler>;

/** Builds the key a route table is indexed by. */
export function routeKey(method: string, resource: string): string {
  return `${method.toUpperCase()} ${resource}`;
}

/**
 * Dispatches an event against [routes].
 *
 * An unmatched route is a **deployment defect**, not a client error: API
 * Gateway would not have invoked this function unless it matched a route the
 * Terraform declared, so arriving here means the table and the infrastructure
 * disagree. It is logged at error level and answered with a 404 envelope.
 */
export function createRouter(functionName: string, routes: RouteTable): WrappedHandler {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const key = routeKey(event.httpMethod, event.resource);
    const handler = routes[key];

    if (handler === undefined) {
      logger.error('no handler for route', {
        function: functionName,
        route: key,
        declared: Object.keys(routes),
      });
      return {
        statusCode: 404,
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(failure('RESOURCE_NOT_FOUND', `No handler is registered for ${key}.`)),
      };
    }

    return handler(event);
  };
}
