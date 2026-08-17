/**
 * Structured logging to CloudWatch.
 *
 * ADR-027 governs `AppLogger` in the Flutter app and is Dart-specific; it does
 * not reach here. What it establishes and this inherits is the **sensitive-data
 * contract**: the logger does not redact, so the caller is responsible for
 * never passing something that must not be logged.
 *
 * JSON lines rather than prose, because CloudWatch Logs Insights can query
 * fields but cannot query a sentence.
 */

/** Severity, ordered. */
export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

const ORDER: Record<LogLevel, number> = { debug: 10, info: 20, warn: 30, error: 40 };

/**
 * Values that must never be logged, in any environment.
 *
 * This is a list of *names*, checked against the keys of a log context. It
 * catches the accidental spread of a request body; it cannot catch a value
 * passed under an innocent key, which is why the contract above still rests on
 * the caller.
 */
const FORBIDDEN_KEYS = new Set([
  'password',
  'token',
  'idToken',
  'authorization',
  'secret',
  'secretString',
  'credentials',
  'privateKey',
]);

function minimumLevel(): LogLevel {
  // Production omits debug. Everything else is emitted: CloudWatch retention is
  // the cost control, not the log level.
  return process.env.APP_ENV === 'production' ? 'info' : 'debug';
}

function emit(level: LogLevel, message: string, context?: Record<string, unknown>): void {
  if (ORDER[level] < ORDER[minimumLevel()]) {
    return;
  }

  const safe: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(context ?? {})) {
    safe[key] = FORBIDDEN_KEYS.has(key) ? '[redacted]' : value;
  }

  const line = JSON.stringify({
    level,
    message,
    timestamp: new Date().toISOString(),
    ...safe,
  });

  if (level === 'error' || level === 'warn') {
    console.error(line);
  } else {
    console.log(line);
  }
}

/** The logger. One function per level, matching ADR-027's five-level shape. */
export const logger = {
  debug: (message: string, context?: Record<string, unknown>): void => {
    emit('debug', message, context);
  },
  info: (message: string, context?: Record<string, unknown>): void => {
    emit('info', message, context);
  },
  warn: (message: string, context?: Record<string, unknown>): void => {
    emit('warn', message, context);
  },
  error: (message: string, context?: Record<string, unknown>): void => {
    emit('error', message, context);
  },
};
