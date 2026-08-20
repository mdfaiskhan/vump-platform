/**
 * The API error taxonomy.
 *
 * Volume 4, Chapter 4.6 §1 requires that errors *"always carry a specific code,
 * never a bare HTTP status alone, mirroring Chapter 2.9's named-cause-and-fix
 * rule at the API layer"*. The mobile client already enforces the other half of
 * that contract: `VumpApi._named` reads this code out of the envelope and
 * refuses to let a named refusal degrade into a bare status.
 *
 * So a code here is a published contract, not an internal label. Renaming one is
 * a breaking API change under Chapter 4.6 §1's `/v2` rule.
 *
 * `SCREAMING_SNAKE_CASE`, per ADR-023 §6's rule for enum-shaped constants.
 */

/** Every error code this API can return. */
export const ERROR_CODES = [
  // --- Authentication (Chapter 4.7) ---------------------------------------
  /** No `Authorization: Bearer …` header, or it was malformed. */
  'AUTH_TOKEN_MISSING',
  /** The token failed signature, expiry or issuer verification. */
  'AUTH_TOKEN_INVALID',
  /** The token verified, but no `users` row matches its `firebase_uid`. */
  'AUTH_USER_NOT_FOUND',
  /**
   * The token carries an `org_id` claim this application cannot resolve to a
   * row in `orgs`. Distinct from AUTH_USER_NOT_FOUND: the account may exist,
   * but the organisation it names does not. See `org.ts` for why an
   * unrecognised value is refused rather than defaulted.
   */
  'AUTH_ORG_UNRECOGNISED',

  // --- Authorization (Chapter 4.8) ----------------------------------------
  /** Authenticated, but the role or org scope forbids this operation. */
  'AUTH_FORBIDDEN',

  // --- Request shape (Chapter 8.3 §2) -------------------------------------
  /** The body or query failed schema validation before any query ran. */
  'REQUEST_INVALID',
  /** A path or query parameter was not a well-formed UUID. */
  'REQUEST_MALFORMED_ID',
  /** `?cursor=` was not a cursor this API issued. */
  'REQUEST_INVALID_CURSOR',

  // --- Resources ----------------------------------------------------------
  'RESOURCE_NOT_FOUND',

  /**
   * The chunk is already registered.
   *
   * **The mobile client knows this code by name.** A Mission 4.2 test scripts
   * this exact refusal against `VumpApi`, so it is load-bearing on both sides.
   */
  'CHUNK_ALREADY_REGISTERED',

  /**
   * A `client_session_id` was re-presented under a **different** Task.
   *
   * Not a generic invalid request: re-registering a session is normal and
   * succeeds — `SessionRegistrar` is idempotent by contract and a chunk
   * pipeline asks for the same session's id many times. What this refuses is
   * the same local session claiming two different Tasks, which cannot be
   * honoured either way round. Returning the original session would put every
   * subsequent chunk under a Task the caller did not ask for; honouring the new
   * one would move a recording between Tasks mid-flight.
   *
   * Named rather than folded into `REQUEST_INVALID` for the same reason
   * `CHUNK_ALREADY_REGISTERED` is: a caller that can distinguish "your request
   * was malformed" from "this identifier is already spoken for" can act on the
   * second and cannot act on the first. Additive, so it is not a `/v2` change.
   */
  'SESSION_ALREADY_REGISTERED',

  // --- Invite codes (ADR-036's retirement, Mission 7.6) -------------------
  /**
   * The invite code was not accepted. **One code covers every reason.**
   *
   * The Cloud Function this replaces returned `AUTH_INVITE_CODE_EXPIRED` for
   * an expired code and `AUTH_INVITE_CODE_INVALID` for a missing or exhausted
   * one. That distinction is an enumeration oracle: only a code that EXISTS
   * can be expired, so the pair of responses tells an unauthenticated caller
   * which guesses were real.
   *
   * It is the same oracle Mission 2.9's F1 removed from the account-creation
   * path — where a taken email address failed differently from a free one —
   * and it is closed the same way: one answer for every rejection.
   *
   * **`AUTH_INVITE_CODE_EXPIRED` is deliberately not defined here.** The
   * mobile client still declares it (`error_codes.dart`); after Mission 7.6 no
   * server can send it, and Phase 5 removes it.
   */
  'AUTH_INVITE_CODE_INVALID',

  // --- Server -------------------------------------------------------------
  /** An unhandled fault. Carries no detail: see `toEnvelopeError`. */
  'INTERNAL_ERROR',
  /**
   * A route exists and its behaviour does not. **Nothing raises this today.**
   *
   * Every route in Chapter 4.6's catalogue was implemented by Mission 7.3, and
   * Mission 7.7 deleted `notImplementedRoute`, the wrapper that raised it.
   *
   * The code stays anyway, and the asymmetry is the reason: this list is the
   * PUBLISHED error taxonomy, so removing an entry is a contract change while
   * adding one back is additive. A client that already maps this code keeps
   * working; one that meets it for the first time has a name for what it got.
   * Keeping an unused entry costs nothing a reader cannot see from this
   * comment.
   */
  'NOT_IMPLEMENTED',
] as const;

/** A published API error code. */
export type ErrorCode = (typeof ERROR_CODES)[number];

/**
 * An error that carries an API code and an HTTP status.
 *
 * Thrown by handlers; converted to an envelope by {@link toEnvelopeError}.
 */
export class ApiError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly status: number,
    options?: { cause?: unknown },
  ) {
    super(message, options);
    this.name = 'ApiError';
  }

  static tokenMissing(): ApiError {
    return new ApiError('AUTH_TOKEN_MISSING', 'No bearer token was supplied.', 401);
  }

  static tokenInvalid(cause?: unknown): ApiError {
    return new ApiError('AUTH_TOKEN_INVALID', 'The bearer token is not valid.', 401, { cause });
  }

  static userNotFound(): ApiError {
    return new ApiError('AUTH_USER_NOT_FOUND', 'No account matches this token.', 401);
  }

  static orgUnrecognised(): ApiError {
    return new ApiError(
      'AUTH_ORG_UNRECOGNISED',
      'This account carries no organisation this application recognises.',
      401,
    );
  }

  static forbidden(what: string): ApiError {
    return new ApiError('AUTH_FORBIDDEN', `Not permitted: ${what}.`, 403);
  }

  static invalidRequest(why: string): ApiError {
    return new ApiError('REQUEST_INVALID', why, 400);
  }

  static notFound(what: string): ApiError {
    return new ApiError('RESOURCE_NOT_FOUND', `${what} was not found.`, 404);
  }

  /**
   * 409. **A plain retry does not reach this** — A-190.
   *
   * Chapter 5.10 §3 makes a repeated registration *"safe to repeat"*, so the
   * same `chunk_id` with the same session, sequence index and checksum succeeds
   * and returns fresh presigned URLs. This is for the same id claiming
   * different facts, which cannot be honoured either way round.
   */
  static chunkAlreadyRegistered(): ApiError {
    return new ApiError(
      'CHUNK_ALREADY_REGISTERED',
      'This chunk_id is already registered with a different session, sequence index or checksum.',
      409,
    );
  }

  /** 409, because the request is well-formed and the state is what refuses it. */
  static sessionAlreadyRegistered(): ApiError {
    return new ApiError(
      'SESSION_ALREADY_REGISTERED',
      'This client_session_id is already registered under a different task.',
      409,
    );
  }

  /**
   * The scaffold marker.
   *
   * Every handler in Mission 6.2 ends here. It is deliberately a *named,
   * enveloped* refusal with a 501 rather than a plausible fake response: a stub
   * that returns invented data is indistinguishable from a working integration
   * until something depends on it.
   */
  /**
   * The invite code is not usable — missing, expired, or out of uses.
   *
   * **Also returned when the email address is already registered**, which is
   * not a mistake. A caller who reaches account creation has already supplied
   * an acceptable code, and answering "that address is taken" would hand back
   * exactly the enumeration oracle F1 removed. No account is created either
   * way, so the two cases are indistinguishable by design.
   *
   * 404 rather than 400: the code names nothing this server will act on, and a
   * 400 would suggest the request was malformed when it was well-formed and
   * refused.
   */
  static inviteCodeInvalid(): ApiError {
    return new ApiError('AUTH_INVITE_CODE_INVALID', 'This invite code is not valid.', 404);
  }

  /**
   * **No caller, deliberately** — see `NOT_IMPLEMENTED` above.
   *
   * Kept as the one supported way to raise the code, so a future route that
   * genuinely lands ahead of its query has something to throw rather than
   * inventing a second spelling. The old message named Missions 6.2 and 6.3,
   * which have both long since happened.
   */
  static notImplemented(what: string): ApiError {
    return new ApiError('NOT_IMPLEMENTED', `${what} is not implemented yet.`, 501);
  }
}

/**
 * Maps any thrown value to the `{ code, message }` an envelope carries.
 *
 * An unrecognised throw becomes `INTERNAL_ERROR` with a fixed message. The real
 * message is logged, never returned — an exception string can carry a table
 * name, a SQL fragment or a secret ARN, and this is the boundary where that
 * would leave the trust boundary.
 */
export function toEnvelopeError(thrown: unknown): {
  code: ErrorCode;
  message: string;
  status: number;
} {
  if (thrown instanceof ApiError) {
    return { code: thrown.code, message: thrown.message, status: thrown.status };
  }
  return {
    code: 'INTERNAL_ERROR',
    message: 'The request could not be completed.',
    status: 500,
  };
}
