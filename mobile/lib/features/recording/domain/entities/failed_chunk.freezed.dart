// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'failed_chunk.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$FailedChunk {
  /// The chunk's stable id, unchanged by the failure (Ch. 5.13 §4).
  String get chunkId => throw _privateConstructorUsedError;

  /// Its position within the session.
  int get sequenceIndex => throw _privateConstructorUsedError;

  /// The named cause Chapter 2.9's copy rules require.
  ErrorCode get cause => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $FailedChunkCopyWith<FailedChunk> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FailedChunkCopyWith<$Res> {
  factory $FailedChunkCopyWith(
          FailedChunk value, $Res Function(FailedChunk) then) =
      _$FailedChunkCopyWithImpl<$Res, FailedChunk>;
  @useResult
  $Res call({String chunkId, int sequenceIndex, ErrorCode cause});
}

/// @nodoc
class _$FailedChunkCopyWithImpl<$Res, $Val extends FailedChunk>
    implements $FailedChunkCopyWith<$Res> {
  _$FailedChunkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chunkId = null,
    Object? sequenceIndex = null,
    Object? cause = null,
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
      cause: null == cause
          ? _value.cause
          : cause // ignore: cast_nullable_to_non_nullable
              as ErrorCode,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FailedChunkImplCopyWith<$Res>
    implements $FailedChunkCopyWith<$Res> {
  factory _$$FailedChunkImplCopyWith(
          _$FailedChunkImpl value, $Res Function(_$FailedChunkImpl) then) =
      __$$FailedChunkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String chunkId, int sequenceIndex, ErrorCode cause});
}

/// @nodoc
class __$$FailedChunkImplCopyWithImpl<$Res>
    extends _$FailedChunkCopyWithImpl<$Res, _$FailedChunkImpl>
    implements _$$FailedChunkImplCopyWith<$Res> {
  __$$FailedChunkImplCopyWithImpl(
      _$FailedChunkImpl _value, $Res Function(_$FailedChunkImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chunkId = null,
    Object? sequenceIndex = null,
    Object? cause = null,
  }) {
    return _then(_$FailedChunkImpl(
      chunkId: null == chunkId
          ? _value.chunkId
          : chunkId // ignore: cast_nullable_to_non_nullable
              as String,
      sequenceIndex: null == sequenceIndex
          ? _value.sequenceIndex
          : sequenceIndex // ignore: cast_nullable_to_non_nullable
              as int,
      cause: null == cause
          ? _value.cause
          : cause // ignore: cast_nullable_to_non_nullable
              as ErrorCode,
    ));
  }
}

/// @nodoc

class _$FailedChunkImpl implements _FailedChunk {
  const _$FailedChunkImpl(
      {required this.chunkId,
      required this.sequenceIndex,
      required this.cause});

  /// The chunk's stable id, unchanged by the failure (Ch. 5.13 §4).
  @override
  final String chunkId;

  /// Its position within the session.
  @override
  final int sequenceIndex;

  /// The named cause Chapter 2.9's copy rules require.
  @override
  final ErrorCode cause;

  @override
  String toString() {
    return 'FailedChunk(chunkId: $chunkId, sequenceIndex: $sequenceIndex, cause: $cause)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FailedChunkImpl &&
            (identical(other.chunkId, chunkId) || other.chunkId == chunkId) &&
            (identical(other.sequenceIndex, sequenceIndex) ||
                other.sequenceIndex == sequenceIndex) &&
            (identical(other.cause, cause) || other.cause == cause));
  }

  @override
  int get hashCode => Object.hash(runtimeType, chunkId, sequenceIndex, cause);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FailedChunkImplCopyWith<_$FailedChunkImpl> get copyWith =>
      __$$FailedChunkImplCopyWithImpl<_$FailedChunkImpl>(this, _$identity);
}

abstract class _FailedChunk implements FailedChunk {
  const factory _FailedChunk(
      {required final String chunkId,
      required final int sequenceIndex,
      required final ErrorCode cause}) = _$FailedChunkImpl;

  @override

  /// The chunk's stable id, unchanged by the failure (Ch. 5.13 §4).
  String get chunkId;
  @override

  /// Its position within the session.
  int get sequenceIndex;
  @override

  /// The named cause Chapter 2.9's copy rules require.
  ErrorCode get cause;
  @override
  @JsonKey(ignore: true)
  _$$FailedChunkImplCopyWith<_$FailedChunkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
