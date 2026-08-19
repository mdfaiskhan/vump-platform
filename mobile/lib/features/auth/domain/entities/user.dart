import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';

part 'user.freezed.dart';

/// The signed-in account, as this application knows it.
///
/// ## Two identifiers, and they are not interchangeable — A-206
///
/// [uid] is **Firebase's**. [backendUserId] is `users.id`, the database uuid
/// every backend row references — `sessions.collector_id`,
/// `projects.created_by` and `task_assignments.user_id` all hold that one,
/// never the Firebase uid.
///
/// Mission 7.4 step 3 wired `identity.collector_id` to [uid], and the metadata
/// route joins the truth out of the database and refuses a document that
/// disagrees. Every metadata POST would have been refused, for every chunk,
/// forever — and nothing could have caught it, because both are opaque strings
/// from the same signed-in account.
///
/// So the two are separate fields with separate names rather than one field
/// whose meaning depends on where it came from. A call site that needs the
/// backend's identifier has to say so.
@freezed
class User with _$User {
  const factory User({
    required String uid,
    required String backendUserId,
    required String email,
    required Role role,
    required String orgId,
    required bool emailVerified,
    String? displayName,
  }) = _User;
}
