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
  type ExecuteOptions,
  type StatementTarget,
} from './data-api.js';
export { isResuming, withResumeRetry, type RetryOptions } from './resume.js';
export { authorize, isAuthorizerEvent } from './authorizer.js';
export { lookupCaller, provisionCaller, type ResolvedCaller } from './caller.js';
export { resolveOrgId, DEFAULT_ORG_ID, LEGACY_DEFAULT_ORG_CLAIM } from './org.js';
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
  withVerifiedToken,
  withoutAuthentication,
  requireRole,
  type Caller,
  type CallerRole,
  type DomainHandler,
  type HandlerResult,
} from './handler.js';
export { encodeCursor, decodeCursor, pageMeta, type Cursor } from './cursor.js';
export { withTransaction, type TransactionalExecute } from './transaction.js';
export {
  parseBody,
  requiredString,
  optionalString,
  optionalStringArray,
  optionalPastInstant,
  pathUuid,
} from './request.js';
export {
  readString,
  readOptionalString,
  readStringArray,
  textParam,
  optionalTextParam,
  uuidParam,
  jsonParam,
  longParam,
  type Row,
} from './row.js';
export { logger, type LogLevel } from './logger.js';
export { parsePageRequest, DEFAULT_LIMIT, MAX_LIMIT, type PageRequest } from './pagination.js';
export { createRouter, routeKey, type RouteTable, type WrappedHandler } from './router.js';
