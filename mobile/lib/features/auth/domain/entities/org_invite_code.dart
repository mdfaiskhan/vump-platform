import 'package:freezed_annotation/freezed_annotation.dart';

part 'org_invite_code.freezed.dart';

@freezed
class OrgInviteCode with _$OrgInviteCode {
  const factory OrgInviteCode({
    required String code,
    required String orgId,
    required DateTime expiresAt,
    int? remainingUses,
  }) = _OrgInviteCode;
}
