// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recording_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$RecordingSession {
  /// The UUID generated once at session start (Chapter 5.14 §3).
  String get sessionId => throw _privateConstructorUsedError;

  /// The Task this session records against, and its Project.
  ///
  /// Nullable because a session can be started without a selection —
  /// `PlatformTaskContext` then reports both as `MetadataIdentity.unsourced`
  /// and A-068's Guard 1 refuses the chunk at upload. Carried on the session
  /// rather than read ambiently at finalization so that every chunk of one
  /// recording is attributed to the same Task, even if the selection changes
  /// underneath. Mission 7.4, F38.
  String? get taskId => throw _privateConstructorUsedError;
  String? get projectId => throw _privateConstructorUsedError;

  /// The wide-angle factor for every chunk in this session — 0.5 or 0.6.
  double get zoomFactor => throw _privateConstructorUsedError;

  /// The wire spelling of the orientation this session captures at, read
  /// from the pipeline once the camera is open. Migration 0017.
  ///
  /// Sits beside [zoomFactor] because it is the same kind of value: a
  /// property the device resolved at session start and holds for the whole
  /// session. Null when the pipeline could not report one.
  String? get captureOrientation => throw _privateConstructorUsedError;

  /// When the Collector tapped Start.
  DateTime get startedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $RecordingSessionCopyWith<RecordingSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecordingSessionCopyWith<$Res> {
  factory $RecordingSessionCopyWith(
          RecordingSession value, $Res Function(RecordingSession) then) =
      _$RecordingSessionCopyWithImpl<$Res, RecordingSession>;
  @useResult
  $Res call(
      {String sessionId,
      String? taskId,
      String? projectId,
      double zoomFactor,
      String? captureOrientation,
      DateTime startedAt});
}

/// @nodoc
class _$RecordingSessionCopyWithImpl<$Res, $Val extends RecordingSession>
    implements $RecordingSessionCopyWith<$Res> {
  _$RecordingSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? taskId = freezed,
    Object? projectId = freezed,
    Object? zoomFactor = null,
    Object? captureOrientation = freezed,
    Object? startedAt = null,
  }) {
    return _then(_value.copyWith(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      taskId: freezed == taskId
          ? _value.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String?,
      projectId: freezed == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      zoomFactor: null == zoomFactor
          ? _value.zoomFactor
          : zoomFactor // ignore: cast_nullable_to_non_nullable
              as double,
      captureOrientation: freezed == captureOrientation
          ? _value.captureOrientation
          : captureOrientation // ignore: cast_nullable_to_non_nullable
              as String?,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RecordingSessionImplCopyWith<$Res>
    implements $RecordingSessionCopyWith<$Res> {
  factory _$$RecordingSessionImplCopyWith(_$RecordingSessionImpl value,
          $Res Function(_$RecordingSessionImpl) then) =
      __$$RecordingSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String sessionId,
      String? taskId,
      String? projectId,
      double zoomFactor,
      String? captureOrientation,
      DateTime startedAt});
}

/// @nodoc
class __$$RecordingSessionImplCopyWithImpl<$Res>
    extends _$RecordingSessionCopyWithImpl<$Res, _$RecordingSessionImpl>
    implements _$$RecordingSessionImplCopyWith<$Res> {
  __$$RecordingSessionImplCopyWithImpl(_$RecordingSessionImpl _value,
      $Res Function(_$RecordingSessionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? taskId = freezed,
    Object? projectId = freezed,
    Object? zoomFactor = null,
    Object? captureOrientation = freezed,
    Object? startedAt = null,
  }) {
    return _then(_$RecordingSessionImpl(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      taskId: freezed == taskId
          ? _value.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String?,
      projectId: freezed == projectId
          ? _value.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      zoomFactor: null == zoomFactor
          ? _value.zoomFactor
          : zoomFactor // ignore: cast_nullable_to_non_nullable
              as double,
      captureOrientation: freezed == captureOrientation
          ? _value.captureOrientation
          : captureOrientation // ignore: cast_nullable_to_non_nullable
              as String?,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc

class _$RecordingSessionImpl implements _RecordingSession {
  const _$RecordingSessionImpl(
      {required this.sessionId,
      this.taskId,
      this.projectId,
      required this.zoomFactor,
      this.captureOrientation,
      required this.startedAt});

  /// The UUID generated once at session start (Chapter 5.14 §3).
  @override
  final String sessionId;

  /// The Task this session records against, and its Project.
  ///
  /// Nullable because a session can be started without a selection —
  /// `PlatformTaskContext` then reports both as `MetadataIdentity.unsourced`
  /// and A-068's Guard 1 refuses the chunk at upload. Carried on the session
  /// rather than read ambiently at finalization so that every chunk of one
  /// recording is attributed to the same Task, even if the selection changes
  /// underneath. Mission 7.4, F38.
  @override
  final String? taskId;
  @override
  final String? projectId;

  /// The wide-angle factor for every chunk in this session — 0.5 or 0.6.
  @override
  final double zoomFactor;

  /// The wire spelling of the orientation this session captures at, read
  /// from the pipeline once the camera is open. Migration 0017.
  ///
  /// Sits beside [zoomFactor] because it is the same kind of value: a
  /// property the device resolved at session start and holds for the whole
  /// session. Null when the pipeline could not report one.
  @override
  final String? captureOrientation;

  /// When the Collector tapped Start.
  @override
  final DateTime startedAt;

  @override
  String toString() {
    return 'RecordingSession(sessionId: $sessionId, taskId: $taskId, projectId: $projectId, zoomFactor: $zoomFactor, captureOrientation: $captureOrientation, startedAt: $startedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecordingSessionImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.zoomFactor, zoomFactor) ||
                other.zoomFactor == zoomFactor) &&
            (identical(other.captureOrientation, captureOrientation) ||
                other.captureOrientation == captureOrientation) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, sessionId, taskId, projectId,
      zoomFactor, captureOrientation, startedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RecordingSessionImplCopyWith<_$RecordingSessionImpl> get copyWith =>
      __$$RecordingSessionImplCopyWithImpl<_$RecordingSessionImpl>(
          this, _$identity);
}

abstract class _RecordingSession implements RecordingSession {
  const factory _RecordingSession(
      {required final String sessionId,
      final String? taskId,
      final String? projectId,
      required final double zoomFactor,
      final String? captureOrientation,
      required final DateTime startedAt}) = _$RecordingSessionImpl;

  @override

  /// The UUID generated once at session start (Chapter 5.14 §3).
  String get sessionId;
  @override

  /// The Task this session records against, and its Project.
  ///
  /// Nullable because a session can be started without a selection —
  /// `PlatformTaskContext` then reports both as `MetadataIdentity.unsourced`
  /// and A-068's Guard 1 refuses the chunk at upload. Carried on the session
  /// rather than read ambiently at finalization so that every chunk of one
  /// recording is attributed to the same Task, even if the selection changes
  /// underneath. Mission 7.4, F38.
  String? get taskId;
  @override
  String? get projectId;
  @override

  /// The wide-angle factor for every chunk in this session — 0.5 or 0.6.
  double get zoomFactor;
  @override

  /// The wire spelling of the orientation this session captures at, read
  /// from the pipeline once the camera is open. Migration 0017.
  ///
  /// Sits beside [zoomFactor] because it is the same kind of value: a
  /// property the device resolved at session start and holds for the whole
  /// session. Null when the pipeline could not report one.
  String? get captureOrientation;
  @override

  /// When the Collector tapped Start.
  DateTime get startedAt;
  @override
  @JsonKey(ignore: true)
  _$$RecordingSessionImplCopyWith<_$RecordingSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
