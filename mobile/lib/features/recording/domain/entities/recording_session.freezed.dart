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

  /// The wide-angle factor for every chunk in this session — 0.5 or 0.6.
  double get zoomFactor => throw _privateConstructorUsedError;

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
  $Res call({String sessionId, double zoomFactor, DateTime startedAt});
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
    Object? zoomFactor = null,
    Object? startedAt = null,
  }) {
    return _then(_value.copyWith(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      zoomFactor: null == zoomFactor
          ? _value.zoomFactor
          : zoomFactor // ignore: cast_nullable_to_non_nullable
              as double,
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
  $Res call({String sessionId, double zoomFactor, DateTime startedAt});
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
    Object? zoomFactor = null,
    Object? startedAt = null,
  }) {
    return _then(_$RecordingSessionImpl(
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      zoomFactor: null == zoomFactor
          ? _value.zoomFactor
          : zoomFactor // ignore: cast_nullable_to_non_nullable
              as double,
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
      required this.zoomFactor,
      required this.startedAt});

  /// The UUID generated once at session start (Chapter 5.14 §3).
  @override
  final String sessionId;

  /// The wide-angle factor for every chunk in this session — 0.5 or 0.6.
  @override
  final double zoomFactor;

  /// When the Collector tapped Start.
  @override
  final DateTime startedAt;

  @override
  String toString() {
    return 'RecordingSession(sessionId: $sessionId, zoomFactor: $zoomFactor, startedAt: $startedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecordingSessionImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.zoomFactor, zoomFactor) ||
                other.zoomFactor == zoomFactor) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, sessionId, zoomFactor, startedAt);

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
      required final double zoomFactor,
      required final DateTime startedAt}) = _$RecordingSessionImpl;

  @override

  /// The UUID generated once at session start (Chapter 5.14 §3).
  String get sessionId;
  @override

  /// The wide-angle factor for every chunk in this session — 0.5 or 0.6.
  double get zoomFactor;
  @override

  /// When the Collector tapped Start.
  DateTime get startedAt;
  @override
  @JsonKey(ignore: true)
  _$$RecordingSessionImplCopyWith<_$RecordingSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
