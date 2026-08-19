// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chunk_processing_job.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ChunkProcessingJob {
  /// The UUID identifying this chunk for its whole life (Ch. 5.14 §3).
  String get chunkId => throw _privateConstructorUsedError;

  /// Its position within the session (Ch. 5.6 §2), fixed at capture-stop.
  int get sequenceIndex => throw _privateConstructorUsedError;

  /// The closed `.mp4` the platform wrote.
  String get filePath => throw _privateConstructorUsedError;

  /// When capture stopped and processing became possible.
  DateTime get startedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ChunkProcessingJobCopyWith<ChunkProcessingJob> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChunkProcessingJobCopyWith<$Res> {
  factory $ChunkProcessingJobCopyWith(
          ChunkProcessingJob value, $Res Function(ChunkProcessingJob) then) =
      _$ChunkProcessingJobCopyWithImpl<$Res, ChunkProcessingJob>;
  @useResult
  $Res call(
      {String chunkId, int sequenceIndex, String filePath, DateTime startedAt});
}

/// @nodoc
class _$ChunkProcessingJobCopyWithImpl<$Res, $Val extends ChunkProcessingJob>
    implements $ChunkProcessingJobCopyWith<$Res> {
  _$ChunkProcessingJobCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chunkId = null,
    Object? sequenceIndex = null,
    Object? filePath = null,
    Object? startedAt = null,
  }) {
    return _then(_value.copyWith(
      chunkId: null == chunkId
          ? _value.chunkId
          : chunkId // ignore: cast_nullable_to_non_nullable
              as String,
      sequenceIndex: null == sequenceIndex
          ? _value.sequenceIndex
          : sequenceIndex // ignore: cast_nullable_to_non_nullable
              as int,
      filePath: null == filePath
          ? _value.filePath
          : filePath // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChunkProcessingJobImplCopyWith<$Res>
    implements $ChunkProcessingJobCopyWith<$Res> {
  factory _$$ChunkProcessingJobImplCopyWith(_$ChunkProcessingJobImpl value,
          $Res Function(_$ChunkProcessingJobImpl) then) =
      __$$ChunkProcessingJobImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String chunkId, int sequenceIndex, String filePath, DateTime startedAt});
}

/// @nodoc
class __$$ChunkProcessingJobImplCopyWithImpl<$Res>
    extends _$ChunkProcessingJobCopyWithImpl<$Res, _$ChunkProcessingJobImpl>
    implements _$$ChunkProcessingJobImplCopyWith<$Res> {
  __$$ChunkProcessingJobImplCopyWithImpl(_$ChunkProcessingJobImpl _value,
      $Res Function(_$ChunkProcessingJobImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chunkId = null,
    Object? sequenceIndex = null,
    Object? filePath = null,
    Object? startedAt = null,
  }) {
    return _then(_$ChunkProcessingJobImpl(
      chunkId: null == chunkId
          ? _value.chunkId
          : chunkId // ignore: cast_nullable_to_non_nullable
              as String,
      sequenceIndex: null == sequenceIndex
          ? _value.sequenceIndex
          : sequenceIndex // ignore: cast_nullable_to_non_nullable
              as int,
      filePath: null == filePath
          ? _value.filePath
          : filePath // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: null == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc

class _$ChunkProcessingJobImpl implements _ChunkProcessingJob {
  const _$ChunkProcessingJobImpl(
      {required this.chunkId,
      required this.sequenceIndex,
      required this.filePath,
      required this.startedAt});

  /// The UUID identifying this chunk for its whole life (Ch. 5.14 §3).
  @override
  final String chunkId;

  /// Its position within the session (Ch. 5.6 §2), fixed at capture-stop.
  @override
  final int sequenceIndex;

  /// The closed `.mp4` the platform wrote.
  @override
  final String filePath;

  /// When capture stopped and processing became possible.
  @override
  final DateTime startedAt;

  @override
  String toString() {
    return 'ChunkProcessingJob(chunkId: $chunkId, sequenceIndex: $sequenceIndex, filePath: $filePath, startedAt: $startedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChunkProcessingJobImpl &&
            (identical(other.chunkId, chunkId) || other.chunkId == chunkId) &&
            (identical(other.sequenceIndex, sequenceIndex) ||
                other.sequenceIndex == sequenceIndex) &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, chunkId, sequenceIndex, filePath, startedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChunkProcessingJobImplCopyWith<_$ChunkProcessingJobImpl> get copyWith =>
      __$$ChunkProcessingJobImplCopyWithImpl<_$ChunkProcessingJobImpl>(
          this, _$identity);
}

abstract class _ChunkProcessingJob implements ChunkProcessingJob {
  const factory _ChunkProcessingJob(
      {required final String chunkId,
      required final int sequenceIndex,
      required final String filePath,
      required final DateTime startedAt}) = _$ChunkProcessingJobImpl;

  @override

  /// The UUID identifying this chunk for its whole life (Ch. 5.14 §3).
  String get chunkId;
  @override

  /// Its position within the session (Ch. 5.6 §2), fixed at capture-stop.
  int get sequenceIndex;
  @override

  /// The closed `.mp4` the platform wrote.
  String get filePath;
  @override

  /// When capture stopped and processing became possible.
  DateTime get startedAt;
  @override
  @JsonKey(ignore: true)
  _$$ChunkProcessingJobImplCopyWith<_$ChunkProcessingJobImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
