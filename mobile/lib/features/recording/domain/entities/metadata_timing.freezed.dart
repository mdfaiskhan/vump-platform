// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'metadata_timing.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MetadataTiming {
  /// From `ChunkProcessingJob.sequenceIndex` (Mission 3.4.5).
  int get sequenceIndex => throw _privateConstructorUsedError;

  /// From `RecordingStateRecording.chunkStartedAt` (Mission 3.4.5).
  DateTime get startedAt => throw _privateConstructorUsedError;

  /// From `ChunkProcessingJob.startedAt` — the instant capture stopped.
  DateTime get endedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MetadataTimingCopyWith<MetadataTiming> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetadataTimingCopyWith<$Res> {
  factory $MetadataTimingCopyWith(
    MetadataTiming value,
    $Res Function(MetadataTiming) then,
  ) = _$MetadataTimingCopyWithImpl<$Res, MetadataTiming>;
  @useResult
  $Res call({int sequenceIndex, DateTime startedAt, DateTime endedAt});
}

/// @nodoc
class _$MetadataTimingCopyWithImpl<$Res, $Val extends MetadataTiming>
    implements $MetadataTimingCopyWith<$Res> {
  _$MetadataTimingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sequenceIndex = null,
    Object? startedAt = null,
    Object? endedAt = null,
  }) {
    return _then(
      _value.copyWith(
            sequenceIndex: null == sequenceIndex
                ? _value.sequenceIndex
                : sequenceIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endedAt: null == endedAt
                ? _value.endedAt
                : endedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MetadataTimingImplCopyWith<$Res>
    implements $MetadataTimingCopyWith<$Res> {
  factory _$$MetadataTimingImplCopyWith(
    _$MetadataTimingImpl value,
    $Res Function(_$MetadataTimingImpl) then,
  ) = __$$MetadataTimingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int sequenceIndex, DateTime startedAt, DateTime endedAt});
}

/// @nodoc
class __$$MetadataTimingImplCopyWithImpl<$Res>
    extends _$MetadataTimingCopyWithImpl<$Res, _$MetadataTimingImpl>
    implements _$$MetadataTimingImplCopyWith<$Res> {
  __$$MetadataTimingImplCopyWithImpl(
    _$MetadataTimingImpl _value,
    $Res Function(_$MetadataTimingImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sequenceIndex = null,
    Object? startedAt = null,
    Object? endedAt = null,
  }) {
    return _then(
      _$MetadataTimingImpl(
        sequenceIndex: null == sequenceIndex
            ? _value.sequenceIndex
            : sequenceIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endedAt: null == endedAt
            ? _value.endedAt
            : endedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$MetadataTimingImpl extends _MetadataTiming {
  const _$MetadataTimingImpl({
    required this.sequenceIndex,
    required this.startedAt,
    required this.endedAt,
  }) : super._();

  /// From `ChunkProcessingJob.sequenceIndex` (Mission 3.4.5).
  @override
  final int sequenceIndex;

  /// From `RecordingStateRecording.chunkStartedAt` (Mission 3.4.5).
  @override
  final DateTime startedAt;

  /// From `ChunkProcessingJob.startedAt` — the instant capture stopped.
  @override
  final DateTime endedAt;

  @override
  String toString() {
    return 'MetadataTiming(sequenceIndex: $sequenceIndex, startedAt: $startedAt, endedAt: $endedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetadataTimingImpl &&
            (identical(other.sequenceIndex, sequenceIndex) ||
                other.sequenceIndex == sequenceIndex) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.endedAt, endedAt) || other.endedAt == endedAt));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, sequenceIndex, startedAt, endedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MetadataTimingImplCopyWith<_$MetadataTimingImpl> get copyWith =>
      __$$MetadataTimingImplCopyWithImpl<_$MetadataTimingImpl>(
        this,
        _$identity,
      );
}

abstract class _MetadataTiming extends MetadataTiming {
  const factory _MetadataTiming({
    required final int sequenceIndex,
    required final DateTime startedAt,
    required final DateTime endedAt,
  }) = _$MetadataTimingImpl;
  const _MetadataTiming._() : super._();

  @override
  /// From `ChunkProcessingJob.sequenceIndex` (Mission 3.4.5).
  int get sequenceIndex;
  @override
  /// From `RecordingStateRecording.chunkStartedAt` (Mission 3.4.5).
  DateTime get startedAt;
  @override
  /// From `ChunkProcessingJob.startedAt` — the instant capture stopped.
  DateTime get endedAt;
  @override
  @JsonKey(ignore: true)
  _$$MetadataTimingImplCopyWith<_$MetadataTimingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
