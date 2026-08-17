import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/auth/domain/entities/role.dart';

part 'user.freezed.dart';

@freezed
class User with _$User {
  const factory User({
    required String uid,
    required String email,
    required Role role,
    required String orgId,
    required bool emailVerified,
    String? displayName,
  }) = _User;
}
