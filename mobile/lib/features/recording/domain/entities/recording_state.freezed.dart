// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recording_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$RecordingState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(RecordingSession? lastCompletedSession) idle,
    required TResult Function(RecordingSession session) ready,
    required TResult Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)
        recording,
    required TResult Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)
        finalizing,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(RecordingSession? lastCompletedSession)? idle,
    TResult? Function(RecordingSession session)? ready,
    TResult? Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)?
        recording,
    TResult? Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)?
        finalizing,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(RecordingSession? lastCompletedSession)? idle,
    TResult Function(RecordingSession session)? ready,
    TResult Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)?
        recording,
    TResult Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)?
        finalizing,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RecordingStateIdle value) idle,
    required TResult Function(RecordingStateReady value) ready,
    required TResult Function(RecordingStateRecording value) recording,
    required TResult Function(RecordingStateFinalizing value) finalizing,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RecordingStateIdle value)? idle,
    TResult? Function(RecordingStateReady value)? ready,
    TResult? Function(RecordingStateRecording value)? recording,
    TResult? Function(RecordingStateFinalizing value)? finalizing,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RecordingStateIdle value)? idle,
    TResult Function(RecordingStateReady value)? ready,
    TResult Function(RecordingStateRecording value)? recording,
    TResult Function(RecordingStateFinalizing value)? finalizing,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecordingStateCopyWith<$Res> {
  factory $RecordingStateCopyWith(
          RecordingState value, $Res Function(RecordingState) then) =
      _$RecordingStateCopyWithImpl<$Res, RecordingState>;
}

/// @nodoc
class _$RecordingStateCopyWithImpl<$Res, $Val extends RecordingState>
    implements $RecordingStateCopyWith<$Res> {
  _$RecordingStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$RecordingStateIdleImplCopyWith<$Res> {
  factory _$$RecordingStateIdleImplCopyWith(_$RecordingStateIdleImpl value,
          $Res Function(_$RecordingStateIdleImpl) then) =
      __$$RecordingStateIdleImplCopyWithImpl<$Res>;
  @useResult
  $Res call({RecordingSession? lastCompletedSession});

  $RecordingSessionCopyWith<$Res>? get lastCompletedSession;
}

/// @nodoc
class __$$RecordingStateIdleImplCopyWithImpl<$Res>
    extends _$RecordingStateCopyWithImpl<$Res, _$RecordingStateIdleImpl>
    implements _$$RecordingStateIdleImplCopyWith<$Res> {
  __$$RecordingStateIdleImplCopyWithImpl(_$RecordingStateIdleImpl _value,
      $Res Function(_$RecordingStateIdleImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lastCompletedSession = freezed,
  }) {
    return _then(_$RecordingStateIdleImpl(
      lastCompletedSession: freezed == lastCompletedSession
          ? _value.lastCompletedSession
          : lastCompletedSession // ignore: cast_nullable_to_non_nullable
              as RecordingSession?,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $RecordingSessionCopyWith<$Res>? get lastCompletedSession {
    if (_value.lastCompletedSession == null) {
      return null;
    }

    return $RecordingSessionCopyWith<$Res>(_value.lastCompletedSession!,
        (value) {
      return _then(_value.copyWith(lastCompletedSession: value));
    });
  }
}

/// @nodoc

class _$RecordingStateIdleImpl extends RecordingStateIdle {
  const _$RecordingStateIdleImpl({this.lastCompletedSession}) : super._();

  @override
  final RecordingSession? lastCompletedSession;

  @override
  String toString() {
    return 'RecordingState.idle(lastCompletedSession: $lastCompletedSession)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecordingStateIdleImpl &&
            (identical(other.lastCompletedSession, lastCompletedSession) ||
                other.lastCompletedSession == lastCompletedSession));
  }

  @override
  int get hashCode => Object.hash(runtimeType, lastCompletedSession);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RecordingStateIdleImplCopyWith<_$RecordingStateIdleImpl> get copyWith =>
      __$$RecordingStateIdleImplCopyWithImpl<_$RecordingStateIdleImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(RecordingSession? lastCompletedSession) idle,
    required TResult Function(RecordingSession session) ready,
    required TResult Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)
        recording,
    required TResult Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)
        finalizing,
  }) {
    return idle(lastCompletedSession);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(RecordingSession? lastCompletedSession)? idle,
    TResult? Function(RecordingSession session)? ready,
    TResult? Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)?
        recording,
    TResult? Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)?
        finalizing,
  }) {
    return idle?.call(lastCompletedSession);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(RecordingSession? lastCompletedSession)? idle,
    TResult Function(RecordingSession session)? ready,
    TResult Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)?
        recording,
    TResult Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)?
        finalizing,
    required TResult orElse(),
  }) {
    if (idle != null) {
      return idle(lastCompletedSession);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RecordingStateIdle value) idle,
    required TResult Function(RecordingStateReady value) ready,
    required TResult Function(RecordingStateRecording value) recording,
    required TResult Function(RecordingStateFinalizing value) finalizing,
  }) {
    return idle(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RecordingStateIdle value)? idle,
    TResult? Function(RecordingStateReady value)? ready,
    TResult? Function(RecordingStateRecording value)? recording,
    TResult? Function(RecordingStateFinalizing value)? finalizing,
  }) {
    return idle?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RecordingStateIdle value)? idle,
    TResult Function(RecordingStateReady value)? ready,
    TResult Function(RecordingStateRecording value)? recording,
    TResult Function(RecordingStateFinalizing value)? finalizing,
    required TResult orElse(),
  }) {
    if (idle != null) {
      return idle(this);
    }
    return orElse();
  }
}

abstract class RecordingStateIdle extends RecordingState {
  const factory RecordingStateIdle(
          {final RecordingSession? lastCompletedSession}) =
      _$RecordingStateIdleImpl;
  const RecordingStateIdle._() : super._();

  RecordingSession? get lastCompletedSession;
  @JsonKey(ignore: true)
  _$$RecordingStateIdleImplCopyWith<_$RecordingStateIdleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RecordingStateReadyImplCopyWith<$Res> {
  factory _$$RecordingStateReadyImplCopyWith(_$RecordingStateReadyImpl value,
          $Res Function(_$RecordingStateReadyImpl) then) =
      __$$RecordingStateReadyImplCopyWithImpl<$Res>;
  @useResult
  $Res call({RecordingSession session});

  $RecordingSessionCopyWith<$Res> get session;
}

/// @nodoc
class __$$RecordingStateReadyImplCopyWithImpl<$Res>
    extends _$RecordingStateCopyWithImpl<$Res, _$RecordingStateReadyImpl>
    implements _$$RecordingStateReadyImplCopyWith<$Res> {
  __$$RecordingStateReadyImplCopyWithImpl(_$RecordingStateReadyImpl _value,
      $Res Function(_$RecordingStateReadyImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? session = null,
  }) {
    return _then(_$RecordingStateReadyImpl(
      session: null == session
          ? _value.session
          : session // ignore: cast_nullable_to_non_nullable
              as RecordingSession,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $RecordingSessionCopyWith<$Res> get session {
    return $RecordingSessionCopyWith<$Res>(_value.session, (value) {
      return _then(_value.copyWith(session: value));
    });
  }
}

/// @nodoc

class _$RecordingStateReadyImpl extends RecordingStateReady {
  const _$RecordingStateReadyImpl({required this.session}) : super._();

  @override
  final RecordingSession session;

  @override
  String toString() {
    return 'RecordingState.ready(session: $session)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecordingStateReadyImpl &&
            (identical(other.session, session) || other.session == session));
  }

  @override
  int get hashCode => Object.hash(runtimeType, session);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RecordingStateReadyImplCopyWith<_$RecordingStateReadyImpl> get copyWith =>
      __$$RecordingStateReadyImplCopyWithImpl<_$RecordingStateReadyImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(RecordingSession? lastCompletedSession) idle,
    required TResult Function(RecordingSession session) ready,
    required TResult Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)
        recording,
    required TResult Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)
        finalizing,
  }) {
    return ready(session);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(RecordingSession? lastCompletedSession)? idle,
    TResult? Function(RecordingSession session)? ready,
    TResult? Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)?
        recording,
    TResult? Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)?
        finalizing,
  }) {
    return ready?.call(session);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(RecordingSession? lastCompletedSession)? idle,
    TResult Function(RecordingSession session)? ready,
    TResult Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)?
        recording,
    TResult Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)?
        finalizing,
    required TResult orElse(),
  }) {
    if (ready != null) {
      return ready(session);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RecordingStateIdle value) idle,
    required TResult Function(RecordingStateReady value) ready,
    required TResult Function(RecordingStateRecording value) recording,
    required TResult Function(RecordingStateFinalizing value) finalizing,
  }) {
    return ready(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RecordingStateIdle value)? idle,
    TResult? Function(RecordingStateReady value)? ready,
    TResult? Function(RecordingStateRecording value)? recording,
    TResult? Function(RecordingStateFinalizing value)? finalizing,
  }) {
    return ready?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RecordingStateIdle value)? idle,
    TResult Function(RecordingStateReady value)? ready,
    TResult Function(RecordingStateRecording value)? recording,
    TResult Function(RecordingStateFinalizing value)? finalizing,
    required TResult orElse(),
  }) {
    if (ready != null) {
      return ready(this);
    }
    return orElse();
  }
}

abstract class RecordingStateReady extends RecordingState {
  const factory RecordingStateReady({required final RecordingSession session}) =
      _$RecordingStateReadyImpl;
  const RecordingStateReady._() : super._();

  RecordingSession get session;
  @JsonKey(ignore: true)
  _$$RecordingStateReadyImplCopyWith<_$RecordingStateReadyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RecordingStateRecordingImplCopyWith<$Res> {
  factory _$$RecordingStateRecordingImplCopyWith(
          _$RecordingStateRecordingImpl value,
          $Res Function(_$RecordingStateRecordingImpl) then) =
      __$$RecordingStateRecordingImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {RecordingSession session, int sequenceIndex, DateTime chunkStartedAt});

  $RecordingSessionCopyWith<$Res> get session;
}

/// @nodoc
class __$$RecordingStateRecordingImplCopyWithImpl<$Res>
    extends _$RecordingStateCopyWithImpl<$Res, _$RecordingStateRecordingImpl>
    implements _$$RecordingStateRecordingImplCopyWith<$Res> {
  __$$RecordingStateRecordingImplCopyWithImpl(
      _$RecordingStateRecordingImpl _value,
      $Res Function(_$RecordingStateRecordingImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? session = null,
    Object? sequenceIndex = null,
    Object? chunkStartedAt = null,
  }) {
    return _then(_$RecordingStateRecordingImpl(
      session: null == session
          ? _value.session
          : session // ignore: cast_nullable_to_non_nullable
              as RecordingSession,
      sequenceIndex: null == sequenceIndex
          ? _value.sequenceIndex
          : sequenceIndex // ignore: cast_nullable_to_non_nullable
              as int,
      chunkStartedAt: null == chunkStartedAt
          ? _value.chunkStartedAt
          : chunkStartedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $RecordingSessionCopyWith<$Res> get session {
    return $RecordingSessionCopyWith<$Res>(_value.session, (value) {
      return _then(_value.copyWith(session: value));
    });
  }
}

/// @nodoc

class _$RecordingStateRecordingImpl extends RecordingStateRecording {
  const _$RecordingStateRecordingImpl(
      {required this.session,
      required this.sequenceIndex,
      required this.chunkStartedAt})
      : super._();

  @override
  final RecordingSession session;

  /// The index this chunk will be stamped with (Volume 4 Chapter 4.4).
  @override
  final int sequenceIndex;

  /// When this chunk began — the 10-minute timer's origin.
  @override
  final DateTime chunkStartedAt;

  @override
  String toString() {
    return 'RecordingState.recording(session: $session, sequenceIndex: $sequenceIndex, chunkStartedAt: $chunkStartedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecordingStateRecordingImpl &&
            (identical(other.session, session) || other.session == session) &&
            (identical(other.sequenceIndex, sequenceIndex) ||
                other.sequenceIndex == sequenceIndex) &&
            (identical(other.chunkStartedAt, chunkStartedAt) ||
                other.chunkStartedAt == chunkStartedAt));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, session, sequenceIndex, chunkStartedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RecordingStateRecordingImplCopyWith<_$RecordingStateRecordingImpl>
      get copyWith => __$$RecordingStateRecordingImplCopyWithImpl<
          _$RecordingStateRecordingImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(RecordingSession? lastCompletedSession) idle,
    required TResult Function(RecordingSession session) ready,
    required TResult Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)
        recording,
    required TResult Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)
        finalizing,
  }) {
    return recording(session, sequenceIndex, chunkStartedAt);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(RecordingSession? lastCompletedSession)? idle,
    TResult? Function(RecordingSession session)? ready,
    TResult? Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)?
        recording,
    TResult? Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)?
        finalizing,
  }) {
    return recording?.call(session, sequenceIndex, chunkStartedAt);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(RecordingSession? lastCompletedSession)? idle,
    TResult Function(RecordingSession session)? ready,
    TResult Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)?
        recording,
    TResult Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)?
        finalizing,
    required TResult orElse(),
  }) {
    if (recording != null) {
      return recording(session, sequenceIndex, chunkStartedAt);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RecordingStateIdle value) idle,
    required TResult Function(RecordingStateReady value) ready,
    required TResult Function(RecordingStateRecording value) recording,
    required TResult Function(RecordingStateFinalizing value) finalizing,
  }) {
    return recording(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RecordingStateIdle value)? idle,
    TResult? Function(RecordingStateReady value)? ready,
    TResult? Function(RecordingStateRecording value)? recording,
    TResult? Function(RecordingStateFinalizing value)? finalizing,
  }) {
    return recording?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RecordingStateIdle value)? idle,
    TResult Function(RecordingStateReady value)? ready,
    TResult Function(RecordingStateRecording value)? recording,
    TResult Function(RecordingStateFinalizing value)? finalizing,
    required TResult orElse(),
  }) {
    if (recording != null) {
      return recording(this);
    }
    return orElse();
  }
}

abstract class RecordingStateRecording extends RecordingState {
  const factory RecordingStateRecording(
      {required final RecordingSession session,
      required final int sequenceIndex,
      required final DateTime chunkStartedAt}) = _$RecordingStateRecordingImpl;
  const RecordingStateRecording._() : super._();

  RecordingSession get session;

  /// The index this chunk will be stamped with (Volume 4 Chapter 4.4).
  int get sequenceIndex;

  /// When this chunk began — the 10-minute timer's origin.
  DateTime get chunkStartedAt;
  @JsonKey(ignore: true)
  _$$RecordingStateRecordingImplCopyWith<_$RecordingStateRecordingImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RecordingStateFinalizingImplCopyWith<$Res> {
  factory _$$RecordingStateFinalizingImplCopyWith(
          _$RecordingStateFinalizingImpl value,
          $Res Function(_$RecordingStateFinalizingImpl) then) =
      __$$RecordingStateFinalizingImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {RecordingSession session,
      int sequenceIndex,
      ChunkBoundaryReason reason});

  $RecordingSessionCopyWith<$Res> get session;
}

/// @nodoc
class __$$RecordingStateFinalizingImplCopyWithImpl<$Res>
    extends _$RecordingStateCopyWithImpl<$Res, _$RecordingStateFinalizingImpl>
    implements _$$RecordingStateFinalizingImplCopyWith<$Res> {
  __$$RecordingStateFinalizingImplCopyWithImpl(
      _$RecordingStateFinalizingImpl _value,
      $Res Function(_$RecordingStateFinalizingImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? session = null,
    Object? sequenceIndex = null,
    Object? reason = null,
  }) {
    return _then(_$RecordingStateFinalizingImpl(
      session: null == session
          ? _value.session
          : session // ignore: cast_nullable_to_non_nullable
              as RecordingSession,
      sequenceIndex: null == sequenceIndex
          ? _value.sequenceIndex
          : sequenceIndex // ignore: cast_nullable_to_non_nullable
              as int,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as ChunkBoundaryReason,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $RecordingSessionCopyWith<$Res> get session {
    return $RecordingSessionCopyWith<$Res>(_value.session, (value) {
      return _then(_value.copyWith(session: value));
    });
  }
}

/// @nodoc

class _$RecordingStateFinalizingImpl extends RecordingStateFinalizing {
  const _$RecordingStateFinalizingImpl(
      {required this.session,
      required this.sequenceIndex,
      required this.reason})
      : super._();

  @override
  final RecordingSession session;

  /// The index of the chunk being finalized.
  @override
  final int sequenceIndex;

  /// Which branch of §2's diagram this finalization returns to.
  @override
  final ChunkBoundaryReason reason;

  @override
  String toString() {
    return 'RecordingState.finalizing(session: $session, sequenceIndex: $sequenceIndex, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecordingStateFinalizingImpl &&
            (identical(other.session, session) || other.session == session) &&
            (identical(other.sequenceIndex, sequenceIndex) ||
                other.sequenceIndex == sequenceIndex) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @override
  int get hashCode => Object.hash(runtimeType, session, sequenceIndex, reason);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RecordingStateFinalizingImplCopyWith<_$RecordingStateFinalizingImpl>
      get copyWith => __$$RecordingStateFinalizingImplCopyWithImpl<
          _$RecordingStateFinalizingImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(RecordingSession? lastCompletedSession) idle,
    required TResult Function(RecordingSession session) ready,
    required TResult Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)
        recording,
    required TResult Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)
        finalizing,
  }) {
    return finalizing(session, sequenceIndex, reason);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(RecordingSession? lastCompletedSession)? idle,
    TResult? Function(RecordingSession session)? ready,
    TResult? Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)?
        recording,
    TResult? Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)?
        finalizing,
  }) {
    return finalizing?.call(session, sequenceIndex, reason);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(RecordingSession? lastCompletedSession)? idle,
    TResult Function(RecordingSession session)? ready,
    TResult Function(RecordingSession session, int sequenceIndex,
            DateTime chunkStartedAt)?
        recording,
    TResult Function(RecordingSession session, int sequenceIndex,
            ChunkBoundaryReason reason)?
        finalizing,
    required TResult orElse(),
  }) {
    if (finalizing != null) {
      return finalizing(session, sequenceIndex, reason);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RecordingStateIdle value) idle,
    required TResult Function(RecordingStateReady value) ready,
    required TResult Function(RecordingStateRecording value) recording,
    required TResult Function(RecordingStateFinalizing value) finalizing,
  }) {
    return finalizing(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RecordingStateIdle value)? idle,
    TResult? Function(RecordingStateReady value)? ready,
    TResult? Function(RecordingStateRecording value)? recording,
    TResult? Function(RecordingStateFinalizing value)? finalizing,
  }) {
    return finalizing?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RecordingStateIdle value)? idle,
    TResult Function(RecordingStateReady value)? ready,
    TResult Function(RecordingStateRecording value)? recording,
    TResult Function(RecordingStateFinalizing value)? finalizing,
    required TResult orElse(),
  }) {
    if (finalizing != null) {
      return finalizing(this);
    }
    return orElse();
  }
}

abstract class RecordingStateFinalizing extends RecordingState {
  const factory RecordingStateFinalizing(
          {required final RecordingSession session,
          required final int sequenceIndex,
          required final ChunkBoundaryReason reason}) =
      _$RecordingStateFinalizingImpl;
  const RecordingStateFinalizing._() : super._();

  RecordingSession get session;

  /// The index of the chunk being finalized.
  int get sequenceIndex;

  /// Which branch of §2's diagram this finalization returns to.
  ChunkBoundaryReason get reason;
  @JsonKey(ignore: true)
  _$$RecordingStateFinalizingImplCopyWith<_$RecordingStateFinalizingImpl>
      get copyWith => throw _privateConstructorUsedError;
}
