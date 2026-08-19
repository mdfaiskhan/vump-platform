// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'org_invite_code.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$OrgInviteCode {
  String get code => throw _privateConstructorUsedError;
  String get orgId => throw _privateConstructorUsedError;
  DateTime get expiresAt => throw _privateConstructorUsedError;
  int? get remainingUses => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $OrgInviteCodeCopyWith<OrgInviteCode> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrgInviteCodeCopyWith<$Res> {
  factory $OrgInviteCodeCopyWith(
          OrgInviteCode value, $Res Function(OrgInviteCode) then) =
      _$OrgInviteCodeCopyWithImpl<$Res, OrgInviteCode>;
  @useResult
  $Res call(
      {String code, String orgId, DateTime expiresAt, int? remainingUses});
}

/// @nodoc
class _$OrgInviteCodeCopyWithImpl<$Res, $Val extends OrgInviteCode>
    implements $OrgInviteCodeCopyWith<$Res> {
  _$OrgInviteCodeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? orgId = null,
    Object? expiresAt = null,
    Object? remainingUses = freezed,
  }) {
    return _then(_value.copyWith(
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      orgId: null == orgId
          ? _value.orgId
          : orgId // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      remainingUses: freezed == remainingUses
          ? _value.remainingUses
          : remainingUses // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OrgInviteCodeImplCopyWith<$Res>
    implements $OrgInviteCodeCopyWith<$Res> {
  factory _$$OrgInviteCodeImplCopyWith(
          _$OrgInviteCodeImpl value, $Res Function(_$OrgInviteCodeImpl) then) =
      __$$OrgInviteCodeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String code, String orgId, DateTime expiresAt, int? remainingUses});
}

/// @nodoc
class __$$OrgInviteCodeImplCopyWithImpl<$Res>
    extends _$OrgInviteCodeCopyWithImpl<$Res, _$OrgInviteCodeImpl>
    implements _$$OrgInviteCodeImplCopyWith<$Res> {
  __$$OrgInviteCodeImplCopyWithImpl(
      _$OrgInviteCodeImpl _value, $Res Function(_$OrgInviteCodeImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? orgId = null,
    Object? expiresAt = null,
    Object? remainingUses = freezed,
  }) {
    return _then(_$OrgInviteCodeImpl(
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      orgId: null == orgId
          ? _value.orgId
          : orgId // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      remainingUses: freezed == remainingUses
          ? _value.remainingUses
          : remainingUses // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$OrgInviteCodeImpl implements _OrgInviteCode {
  const _$OrgInviteCodeImpl(
      {required this.code,
      required this.orgId,
      required this.expiresAt,
      this.remainingUses});

  @override
  final String code;
  @override
  final String orgId;
  @override
  final DateTime expiresAt;
  @override
  final int? remainingUses;

  @override
  String toString() {
    return 'OrgInviteCode(code: $code, orgId: $orgId, expiresAt: $expiresAt, remainingUses: $remainingUses)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrgInviteCodeImpl &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.orgId, orgId) || other.orgId == orgId) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.remainingUses, remainingUses) ||
                other.remainingUses == remainingUses));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, code, orgId, expiresAt, remainingUses);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$OrgInviteCodeImplCopyWith<_$OrgInviteCodeImpl> get copyWith =>
      __$$OrgInviteCodeImplCopyWithImpl<_$OrgInviteCodeImpl>(this, _$identity);
}

abstract class _OrgInviteCode implements OrgInviteCode {
  const factory _OrgInviteCode(
      {required final String code,
      required final String orgId,
      required final DateTime expiresAt,
      final int? remainingUses}) = _$OrgInviteCodeImpl;

  @override
  String get code;
  @override
  String get orgId;
  @override
  DateTime get expiresAt;
  @override
  int? get remainingUses;
  @override
  @JsonKey(ignore: true)
  _$$OrgInviteCodeImplCopyWith<_$OrgInviteCodeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
