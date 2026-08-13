import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/failure.dart';

/// Turns a [Failure] into the sentence a person reads on the sign-in screen.
///
/// Volume 2 Chapter 2.9 §2 makes a generic message a defect rather than a
/// fallback: *"Every failure state must name the specific cause and the
/// specific fix. A generic 'Something went wrong' is treated as a defect, not
/// an acceptable fallback."* §4.3 adds that every error pairs a plain-language
/// cause with a single specific recovery action.
///
/// Chapter 2.9 §3's table gives no sign-in row, so these follow the shape of
/// the rows it does give — *"Battery: 14% — charge to at least 20% before
/// recording"*, not *"Error: precondition not met"*. Cause first, then the one
/// thing to do about it.
///
/// ## Why this reads an `ErrorCode`
///
/// error-handling.md §26 puts `presentation/` in exactly this position: it
/// receives a `Failure` and pattern-matches on `code`, never on a message
/// string. Volume 3 Chapter 3.9 §5 asks for a per-feature sealed failure union
/// instead; ADR-025 supersedes it, and amendment A-054 records that. The
/// `AUTH_*` codes already distinguish every case this screen can produce.
abstract final class AuthErrorCopy {
  /// The message to show for [failure].
  ///
  /// Total over `ErrorCode`, because a code with no copy would surface as the
  /// generic string §2 forbids. The fallback still names a cause and an
  /// action; it is the line to add a case above rather than the line to leave.
  static String forFailure(Failure failure) {
    return switch (failure.code) {
      // Deliberately identical for a wrong password and an unknown address.
      // Firebase collapses them so a caller cannot learn whether an account
      // exists (ADR-034), and copy that distinguished them would undo that.
      ErrorCode.authInvalidCredentials =>
        'That email and password do not match an account. Check both and try '
            'again.',

      ErrorCode.authAccountDisabled =>
        'This account has been deactivated. Ask your organisation admin to '
            'restore it.',

      ErrorCode.authUnauthenticated =>
        'This account is not set up for Vump yet. Ask your organisation admin '
            'to finish adding you.',

      ErrorCode.authForbidden =>
        'This account does not have access to Vump. Ask your organisation '
            'admin to check your role.',

      ErrorCode.authSessionExpired || ErrorCode.authTokenRefreshFailed =>
        'Your session has ended. Sign in again to continue.',

      // Not an error. §2's "never fail silently" cuts both ways: reporting a
      // deliberate cancellation as a failure is its own kind of noise, so the
      // screen shows nothing at all for this code.
      ErrorCode.authSignInCancelled => '',

      ErrorCode.authEmailAlreadyInUse =>
        'An account already exists for this email. Sign in instead of '
            'creating a new account.',

      ErrorCode.authInviteCodeInvalid =>
        'That invite code is not valid. Check it with your organisation admin.',

      ErrorCode.authInviteCodeExpired =>
        'That invite code has expired. Ask your organisation admin for a new '
            'one.',

      ErrorCode.networkUnavailable =>
        'No connection. Signing in needs the internet — reconnect and try '
            'again.',

      ErrorCode.networkTimeout =>
        'The server took too long to answer. Check your connection and try '
            'again.',

      ErrorCode.networkRateLimited =>
        'Too many sign-in attempts. Wait a minute, then try again.',

      ErrorCode.networkServerError =>
        'Vump is not responding right now. Try again in a few minutes.',

      ErrorCode.validationInvalidInput ||
      ErrorCode.validationRequiredField ||
      ErrorCode.validationInvalidFormat =>
        'Check the details you entered and try again.',

      // Reached by an unmapped code, and by the one gap ADR-034 records: the
      // taxonomy has no configuration case, so a Firebase provider that is not
      // enabled in the console arrives here. Both are a fault on this side,
      // and the copy says so rather than blaming the person signing in.
      _ =>
        'Sign-in is not working right now. Try again, and tell your '
            'organisation admin if it keeps happening.',
    };
  }

  /// Whether [failure] should be shown to the user at all.
  ///
  /// A cancelled sign-in is the one failure the screen stays silent about: the
  /// person dismissed the Google sheet on purpose, and a red banner under a
  /// deliberate action reads as a fault that did not occur.
  static bool isSilent(Failure failure) =>
      failure.code == ErrorCode.authSignInCancelled;
}
