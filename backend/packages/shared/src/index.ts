/**
 * `@vump/shared` — the code every Lambda in this backend needs.
 *
 * Governed by ADR-015 (runtime), ADR-043 (the infrastructure that runs it),
 * ADR-044 (how it reaches the database) and ADR-045 (how its dependencies are
 * managed).
 */
export { bearerToken, verifyToken, resetFirebaseAppForTest, type TokenIdentity } from './auth.js';
export { loadConfig, resetConfigForTest, type AppEnv, type BackendConfig } from './config.js';
export {
  dataApiClient,
  execute,
  statementTarget,
  resetDataApiClientForTest,
  type StatementTarget,
} from './data-api.js';
export {
  success,
  failure,
  type Envelope,
  type EnvelopeError,
  type EnvelopeMeta,
  type ErrorEnvelope,
  type SuccessEnvelope,
} from './envelope.js';
export { ApiError, ERROR_CODES, toEnvelopeError, type ErrorCode } from './errors.js';
export {
  withEnvelope,
  notImplementedRoute,
  type Caller,
  type DomainHandler,
  type HandlerResult,
} from './handler.js';
export { logger, type LogLevel } from './logger.js';
export { parsePageRequest, DEFAULT_LIMIT, MAX_LIMIT, type PageRequest } from './pagination.js';
export { createRouter, routeKey, type RouteTable, type WrappedHandler } from './router.js';
