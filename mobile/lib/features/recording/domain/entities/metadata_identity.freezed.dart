// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'metadata_identity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MetadataIdentity {
  /// From `RecordingSession.sessionId` (Mission 3.2).
  String get sessionId => throw _privateConstructorUsedError;

  /// From `TaskContext` — no source in this feature.
  String get projectId => throw _privateConstructorUsedError;

  /// From `TaskContext` — no source in this feature.
  String get taskId => throw _privateConstructorUsedError;

  /// From `DeviceContext` — `features/auth/`'s `User.uid`, inverted.
  String get collectorId => throw _privateConstructorUsedError;

  /// From `DeviceContext` — a "cached, stable device identifier"
  /// (Ch. 5.7 §2). Nothing in the project produces one yet.
  String get deviceId => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MetadataIdentityCopyWith<MetadataIdentity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetadataIdentityCopyWith<$Res> {
  factory $MetadataIdentityCopyWith(
          MetadataIdentity value, $Res Function(MetadataIdentity) then) =
      _$MetadataIdentityCopyWithImpl<$Res, MetadataIdentity>;
  @useResult
  $Res call(
      {String sessionId,
      String projectId,
      String taskId,
      String collectorId,
      String deviceId});
}

/// @nodoc
class _$MetadataIdentityCopyWithImpl<$Res, $Val extends MetadataIdentity>
    implements $MetadataIdentityCopyWith<$Res> {
  _$MetadataIdentityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? projectId = null,
    Object? taskId = null,
    Object? collectorId = null,
    Object? deviceId = null,
  }) {
    return _then(_value.copyWith(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      projectId: null == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String,
      taskId: null == taskId
          ? _value.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      collectorId: null == collectorId
          ? _value.collectorId
          : collectorId // ignore: cast_nullable_to_non_nullable
              as String,
      deviceId: null == deviceId
          ? _value.deviceId
          : deviceId // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MetadataIdentityImplCopyWith<$Res>
    implements $MetadataIdentityCopyWith<$Res> {
  factory _$$MetadataIdentityImplCopyWith(_$MetadataIdentityImpl value,
          $Res Function(_$MetadataIdentityImpl) then) =
      __$$MetadataIdentityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String sessionId,
      String projectId,
      String taskId,
      String collectorId,
      String deviceId});
}

/// @nodoc
class __$$MetadataIdentityImplCopyWithImpl<$Res>
    extends _$MetadataIdentityCopyWithImpl<$Res, _$MetadataIdentityImpl>
    implements _$$MetadataIdentityImplCopyWith<$Res> {
  __$$MetadataIdentityImplCopyWithImpl(_$MetadataIdentityImpl _value,
      $Res Function(_$MetadataIdentityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? projectId = null,
    Object? taskId = null,
    Object? collectorId = null,
    Object? deviceId = null,
  }) {
    return _then(_$MetadataIdentityImpl(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      projectId: null == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String,
      taskId: null == taskId
          ? _value.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      collectorId: null == collectorId
          ? _value.collectorId
          : collectorId // ignore: cast_nullable_to_non_nullable
              as String,
      deviceId: null == deviceId
          ? _value.deviceId
          : deviceId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$MetadataIdentityImpl implements _MetadataIdentity {
  const _$MetadataIdentityImpl(
      {required this.sessionId,
      required this.projectId,
      required this.taskId,
      required this.collectorId,
      required this.deviceId});

  /// From `RecordingSession.sessionId` (Mission 3.2).
  @override
  final String sessionId;

  /// From `TaskContext` — no source in this feature.
  @override
  final String projectId;

  /// From `TaskContext` — no source in this feature.
  @override
  final String taskId;

  /// From `DeviceContext` — `features/auth/`'s `User.uid`, inverted.
  @override
  final String collectorId;

  /// From `DeviceContext` — a "cached, stable device identifier"
  /// (Ch. 5.7 §2). Nothing in the project produces one yet.
  @override
  final String deviceId;

  @override
  String toString() {
    return 'MetadataIdentity(sessionId: $sessionId, projectId: $projectId, taskId: $taskId, collectorId: $collectorId, deviceId: $deviceId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetadataIdentityImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.collectorId, collectorId) ||
                other.collectorId == collectorId) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, sessionId, projectId, taskId, collectorId, deviceId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MetadataIdentityImplCopyWith<_$MetadataIdentityImpl> get copyWith =>
      __$$MetadataIdentityImplCopyWithImpl<_$MetadataIdentityImpl>(
          this, _$identity);
}

abstract class _MetadataIdentity implements MetadataIdentity {
  const factory _MetadataIdentity(
      {required final String sessionId,
      required final String projectId,
      required final String taskId,
      required final String collectorId,
      required final String deviceId}) = _$MetadataIdentityImpl;

  @override

  /// From `RecordingSession.sessionId` (Mission 3.2).
  String get sessionId;
  @override

  /// From `TaskContext` — no source in this feature.
  String get projectId;
  @override

  /// From `TaskContext` — no source in this feature.
  String get taskId;
  @override

  /// From `DeviceContext` — `features/auth/`'s `User.uid`, inverted.
  String get collectorId;
  @override

  /// From `DeviceContext` — a "cached, stable device identifier"
  /// (Ch. 5.7 §2). Nothing in the project produces one yet.
  String get deviceId;
  @override
  @JsonKey(ignore: true)
  _$$MetadataIdentityImplCopyWith<_$MetadataIdentityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
