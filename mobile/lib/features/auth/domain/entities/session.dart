import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';

part 'session.freezed.dart';

@freezed
sealed class Session with _$Session {
  const factory Session.unknown() = SessionUnknown;
  const factory Session.unauthenticated() = SessionUnauthenticated;
  const factory Session.authenticated(User user) = SessionAuthenticated;
}
