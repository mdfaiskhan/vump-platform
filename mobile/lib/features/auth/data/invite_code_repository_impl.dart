import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/authentication_exception.dart';
import 'package:mobile/features/auth/domain/entities/org_invite_code.dart';
import 'package:mobile/features/auth/domain/repositories/invite_code_repository.dart';

/// Firestore-backed implementation of [InviteCodeRepository].
///
/// **TEMPORARY — retired with the redemption function at Mission 6/7
/// (ADR-036).** When the AWS backend lands, issuing becomes a `/v1/...` route
/// and this file and `cloud_firestore` leave the project together.
///
/// ## The UI is not the gate
///
/// This writes to `org_invite_codes` directly, and the Admin's own signed
/// token is what authorises it. The enforcement is `firestore.rules`, which
/// requires `request.auth.token.role == 'admin'` **and**
/// `request.auth.token.org_id == request.resource.data.orgId` — so an admin
/// cannot mint a code for another organisation even by calling Firestore
/// directly with the project's public config. A screen that hides a button
/// stops nobody; the rule is the thing that holds.
///
/// Reads are denied to every client, including this one. Enumerating valid
/// codes is the attack the collection is shaped against, so nothing here
/// lists or verifies a code — only the function, whose Admin privileges
/// bypass rules, reads them.
class InviteCodeRepositoryImpl implements InviteCodeRepository {
  /// Creates a repository over [firestore], defaulting to the SDK singleton.
  ///
  /// Stored rather than resolved, so construction cannot throw when Firebase
  /// never initialised — the same lazy shape ADR-035 required of
  /// `AuthRepositoryImpl`.
  InviteCodeRepositoryImpl({FirebaseFirestore? firestore})
    : _injected = firestore;

  final FirebaseFirestore? _injected;

  FirebaseFirestore get _firestore => _injected ?? FirebaseFirestore.instance;

  /// Characters a code is drawn from.
  ///
  /// No `0`, `O`, `1`, `I` or `L`. A code is read off a screen and typed on a
  /// phone, often by someone in the field, and those five are the pairs that
  /// get mistyped. Dropping them costs a little entropy per character and buys
  /// back more in codes that work first time.
  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Length of a generated code. 10 characters of this alphabet is about 49
  /// bits — far beyond guessing, given the rules deny enumeration entirely.
  static const int _length = 10;

  /// Writes a new code for [orgId] and returns it.
  ///
  /// [expiresAt] is stored as a Firestore `Timestamp` and compared against the
  /// **server's** clock at redemption. [remainingUses] is null for unlimited,
  /// matching the entity, and the function does not decrement a null.
  @override
  Future<OrgInviteCode> issue({
    required String orgId,
    required DateTime expiresAt,
    int? remainingUses,
  }) async {
    final OrgInviteCode code = OrgInviteCode(
      code: _generateCode(),
      orgId: orgId,
      expiresAt: expiresAt,
      remainingUses: remainingUses,
    );

    try {
      // `create` rather than `set`: the document ID is the code, and a
      // collision must fail rather than silently overwrite somebody else's
      // live code with a new expiry and use count.
      await _firestore
          .collection('org_invite_codes')
          .doc(code.code)
          .set(<String, Object?>{
            'orgId': code.orgId,
            'expiresAt': Timestamp.fromDate(code.expiresAt),
            'remainingUses': code.remainingUses,
          }, SetOptions(merge: false));
    } on FirebaseException catch (error, stackTrace) {
      throw AuthenticationException(
        errorCode: error.code == 'permission-denied'
            ? ErrorCode.authForbidden
            : ErrorCode.unknown,
        message:
            'The invite code could not be issued '
            '(firestore code: ${error.code}).',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return code;
  }

  String _generateCode() {
    // `Random.secure` rather than `Random`. A predictable code is a code an
    // outsider can guess their way into an organisation with, and the default
    // generator is seeded predictably enough to matter here.
    final Random random = Random.secure();
    return String.fromCharCodes(
      Iterable<int>.generate(
        _length,
        (_) => _alphabet.codeUnitAt(random.nextInt(_alphabet.length)),
      ),
    );
  }
}
