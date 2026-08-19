// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chunk_integrity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ChunkIntegrity {
  /// Lowercase hex SHA-256 of the finalized file — 64 characters.
  String get checksumSha256 => throw _privateConstructorUsedError;

  /// The finalized file's size in bytes, read from the closed handle.
  int get byteCount => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ChunkIntegrityCopyWith<ChunkIntegrity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChunkIntegrityCopyWith<$Res> {
  factory $ChunkIntegrityCopyWith(
    ChunkIntegrity value,
    $Res Function(ChunkIntegrity) then,
  ) = _$ChunkIntegrityCopyWithImpl<$Res, ChunkIntegrity>;
  @useResult
  $Res call({String checksumSha256, int byteCount});
}

/// @nodoc
class _$ChunkIntegrityCopyWithImpl<$Res, $Val extends ChunkIntegrity>
    implements $ChunkIntegrityCopyWith<$Res> {
  _$ChunkIntegrityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? checksumSha256 = null, Object? byteCount = null}) {
    return _then(
      _value.copyWith(
            checksumSha256: null == checksumSha256
                ? _value.checksumSha256
                : checksumSha256 // ignore: cast_nullable_to_non_nullable
                      as String,
            byteCount: null == byteCount
                ? _value.byteCount
                : byteCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChunkIntegrityImplCopyWith<$Res>
    implements $ChunkIntegrityCopyWith<$Res> {
  factory _$$ChunkIntegrityImplCopyWith(
    _$ChunkIntegrityImpl value,
    $Res Function(_$ChunkIntegrityImpl) then,
  ) = __$$ChunkIntegrityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String checksumSha256, int byteCount});
}

/// @nodoc
class __$$ChunkIntegrityImplCopyWithImpl<$Res>
    extends _$ChunkIntegrityCopyWithImpl<$Res, _$ChunkIntegrityImpl>
    implements _$$ChunkIntegrityImplCopyWith<$Res> {
  __$$ChunkIntegrityImplCopyWithImpl(
    _$ChunkIntegrityImpl _value,
    $Res Function(_$ChunkIntegrityImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? checksumSha256 = null, Object? byteCount = null}) {
    return _then(
      _$ChunkIntegrityImpl(
        checksumSha256: null == checksumSha256
            ? _value.checksumSha256
            : checksumSha256 // ignore: cast_nullable_to_non_nullable
                  as String,
        byteCount: null == byteCount
            ? _value.byteCount
            : byteCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$ChunkIntegrityImpl extends _ChunkIntegrity {
  const _$ChunkIntegrityImpl({
    required this.checksumSha256,
    required this.byteCount,
  }) : super._();

  /// Lowercase hex SHA-256 of the finalized file — 64 characters.
  @override
  final String checksumSha256;

  /// The finalized file's size in bytes, read from the closed handle.
  @override
  final int byteCount;

  @override
  String toString() {
    return 'ChunkIntegrity(checksumSha256: $checksumSha256, byteCount: $byteCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChunkIntegrityImpl &&
            (identical(other.checksumSha256, checksumSha256) ||
                other.checksumSha256 == checksumSha256) &&
            (identical(other.byteCount, byteCount) ||
                other.byteCount == byteCount));
  }

  @override
  int get hashCode => Object.hash(runtimeType, checksumSha256, byteCount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChunkIntegrityImplCopyWith<_$ChunkIntegrityImpl> get copyWith =>
      __$$ChunkIntegrityImplCopyWithImpl<_$ChunkIntegrityImpl>(
        this,
        _$identity,
      );
}

abstract class _ChunkIntegrity extends ChunkIntegrity {
  const factory _ChunkIntegrity({
    required final String checksumSha256,
    required final int byteCount,
  }) = _$ChunkIntegrityImpl;
  const _ChunkIntegrity._() : super._();

  @override
  /// Lowercase hex SHA-256 of the finalized file — 64 characters.
  String get checksumSha256;
  @override
  /// The finalized file's size in bytes, read from the closed handle.
  int get byteCount;
  @override
  @JsonKey(ignore: true)
  _$$ChunkIntegrityImplCopyWith<_$ChunkIntegrityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
