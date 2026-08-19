// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chunk_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ChunkMetadata {
  /// The chunk's stable UUID, minted at capture-stop (Mission 3.4.5).
  String get chunkId => throw _privateConstructorUsedError;
  MetadataIdentity get identity => throw _privateConstructorUsedError;
  MetadataTiming get timing => throw _privateConstructorUsedError;
  MetadataCapture get capture => throw _privateConstructorUsedError;
  MetadataDeviceContext get deviceContext => throw _privateConstructorUsedError;
  MetadataCaptureConditions get captureConditions =>
      throw _privateConstructorUsedError;
  ChunkIntegrity get integrity => throw _privateConstructorUsedError;
  CollectorAuthored get collectorAuthored => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ChunkMetadataCopyWith<ChunkMetadata> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChunkMetadataCopyWith<$Res> {
  factory $ChunkMetadataCopyWith(
    ChunkMetadata value,
    $Res Function(ChunkMetadata) then,
  ) = _$ChunkMetadataCopyWithImpl<$Res, ChunkMetadata>;
  @useResult
  $Res call({
    String chunkId,
    MetadataIdentity identity,
    MetadataTiming timing,
    MetadataCapture capture,
    MetadataDeviceContext deviceContext,
    MetadataCaptureConditions captureConditions,
    ChunkIntegrity integrity,
    CollectorAuthored collectorAuthored,
  });

  $MetadataIdentityCopyWith<$Res> get identity;
  $MetadataTimingCopyWith<$Res> get timing;
  $MetadataCaptureCopyWith<$Res> get capture;
  $MetadataDeviceContextCopyWith<$Res> get deviceContext;
  $MetadataCaptureConditionsCopyWith<$Res> get captureConditions;
  $ChunkIntegrityCopyWith<$Res> get integrity;
  $CollectorAuthoredCopyWith<$Res> get collectorAuthored;
}

/// @nodoc
class _$ChunkMetadataCopyWithImpl<$Res, $Val extends ChunkMetadata>
    implements $ChunkMetadataCopyWith<$Res> {
  _$ChunkMetadataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chunkId = null,
    Object? identity = null,
    Object? timing = null,
    Object? capture = null,
    Object? deviceContext = null,
    Object? captureConditions = null,
    Object? integrity = null,
    Object? collectorAuthored = null,
  }) {
    return _then(
      _value.copyWith(
            chunkId: null == chunkId
                ? _value.chunkId
                : chunkId // ignore: cast_nullable_to_non_nullable
                      as String,
            identity: null == identity
                ? _value.identity
                : identity // ignore: cast_nullable_to_non_nullable
                      as MetadataIdentity,
            timing: null == timing
                ? _value.timing
                : timing // ignore: cast_nullable_to_non_nullable
                      as MetadataTiming,
            capture: null == capture
                ? _value.capture
                : capture // ignore: cast_nullable_to_non_nullable
                      as MetadataCapture,
            deviceContext: null == deviceContext
                ? _value.deviceContext
                : deviceContext // ignore: cast_nullable_to_non_nullable
                      as MetadataDeviceContext,
            captureConditions: null == captureConditions
                ? _value.captureConditions
                : captureConditions // ignore: cast_nullable_to_non_nullable
                      as MetadataCaptureConditions,
            integrity: null == integrity
                ? _value.integrity
                : integrity // ignore: cast_nullable_to_non_nullable
                      as ChunkIntegrity,
            collectorAuthored: null == collectorAuthored
                ? _value.collectorAuthored
                : collectorAuthored // ignore: cast_nullable_to_non_nullable
                      as CollectorAuthored,
          )
          as $Val,
    );
  }

  @override
  @pragma('vm:prefer-inline')
  $MetadataIdentityCopyWith<$Res> get identity {
    return $MetadataIdentityCopyWith<$Res>(_value.identity, (value) {
      return _then(_value.copyWith(identity: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $MetadataTimingCopyWith<$Res> get timing {
    return $MetadataTimingCopyWith<$Res>(_value.timing, (value) {
      return _then(_value.copyWith(timing: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $MetadataCaptureCopyWith<$Res> get capture {
    return $MetadataCaptureCopyWith<$Res>(_value.capture, (value) {
      return _then(_value.copyWith(capture: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $MetadataDeviceContextCopyWith<$Res> get deviceContext {
    return $MetadataDeviceContextCopyWith<$Res>(_value.deviceContext, (value) {
      return _then(_value.copyWith(deviceContext: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $MetadataCaptureConditionsCopyWith<$Res> get captureConditions {
    return $MetadataCaptureConditionsCopyWith<$Res>(_value.captureConditions, (
      value,
    ) {
      return _then(_value.copyWith(captureConditions: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $ChunkIntegrityCopyWith<$Res> get integrity {
    return $ChunkIntegrityCopyWith<$Res>(_value.integrity, (value) {
      return _then(_value.copyWith(integrity: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $CollectorAuthoredCopyWith<$Res> get collectorAuthored {
    return $CollectorAuthoredCopyWith<$Res>(_value.collectorAuthored, (value) {
      return _then(_value.copyWith(collectorAuthored: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ChunkMetadataImplCopyWith<$Res>
    implements $ChunkMetadataCopyWith<$Res> {
  factory _$$ChunkMetadataImplCopyWith(
    _$ChunkMetadataImpl value,
    $Res Function(_$ChunkMetadataImpl) then,
  ) = __$$ChunkMetadataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String chunkId,
    MetadataIdentity identity,
    MetadataTiming timing,
    MetadataCapture capture,
    MetadataDeviceContext deviceContext,
    MetadataCaptureConditions captureConditions,
    ChunkIntegrity integrity,
    CollectorAuthored collectorAuthored,
  });

  @override
  $MetadataIdentityCopyWith<$Res> get identity;
  @override
  $MetadataTimingCopyWith<$Res> get timing;
  @override
  $MetadataCaptureCopyWith<$Res> get capture;
  @override
  $MetadataDeviceContextCopyWith<$Res> get deviceContext;
  @override
  $MetadataCaptureConditionsCopyWith<$Res> get captureConditions;
  @override
  $ChunkIntegrityCopyWith<$Res> get integrity;
  @override
  $CollectorAuthoredCopyWith<$Res> get collectorAuthored;
}

/// @nodoc
class __$$ChunkMetadataImplCopyWithImpl<$Res>
    extends _$ChunkMetadataCopyWithImpl<$Res, _$ChunkMetadataImpl>
    implements _$$ChunkMetadataImplCopyWith<$Res> {
  __$$ChunkMetadataImplCopyWithImpl(
    _$ChunkMetadataImpl _value,
    $Res Function(_$ChunkMetadataImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chunkId = null,
    Object? identity = null,
    Object? timing = null,
    Object? capture = null,
    Object? deviceContext = null,
    Object? captureConditions = null,
    Object? integrity = null,
    Object? collectorAuthored = null,
  }) {
    return _then(
      _$ChunkMetadataImpl(
        chunkId: null == chunkId
            ? _value.chunkId
            : chunkId // ignore: cast_nullable_to_non_nullable
                  as String,
        identity: null == identity
            ? _value.identity
            : identity // ignore: cast_nullable_to_non_nullable
                  as MetadataIdentity,
        timing: null == timing
            ? _value.timing
            : timing // ignore: cast_nullable_to_non_nullable
                  as MetadataTiming,
        capture: null == capture
            ? _value.capture
            : capture // ignore: cast_nullable_to_non_nullable
                  as MetadataCapture,
        deviceContext: null == deviceContext
            ? _value.deviceContext
            : deviceContext // ignore: cast_nullable_to_non_nullable
                  as MetadataDeviceContext,
        captureConditions: null == captureConditions
            ? _value.captureConditions
            : captureConditions // ignore: cast_nullable_to_non_nullable
                  as MetadataCaptureConditions,
        integrity: null == integrity
            ? _value.integrity
            : integrity // ignore: cast_nullable_to_non_nullable
                  as ChunkIntegrity,
        collectorAuthored: null == collectorAuthored
            ? _value.collectorAuthored
            : collectorAuthored // ignore: cast_nullable_to_non_nullable
                  as CollectorAuthored,
      ),
    );
  }
}

/// @nodoc

class _$ChunkMetadataImpl extends _ChunkMetadata {
  const _$ChunkMetadataImpl({
    required this.chunkId,
    required this.identity,
    required this.timing,
    required this.capture,
    required this.deviceContext,
    required this.captureConditions,
    required this.integrity,
    this.collectorAuthored = CollectorAuthored.empty,
  }) : super._();

  /// The chunk's stable UUID, minted at capture-stop (Mission 3.4.5).
  @override
  final String chunkId;
  @override
  final MetadataIdentity identity;
  @override
  final MetadataTiming timing;
  @override
  final MetadataCapture capture;
  @override
  final MetadataDeviceContext deviceContext;
  @override
  final MetadataCaptureConditions captureConditions;
  @override
  final ChunkIntegrity integrity;
  @override
  @JsonKey()
  final CollectorAuthored collectorAuthored;

  @override
  String toString() {
    return 'ChunkMetadata(chunkId: $chunkId, identity: $identity, timing: $timing, capture: $capture, deviceContext: $deviceContext, captureConditions: $captureConditions, integrity: $integrity, collectorAuthored: $collectorAuthored)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChunkMetadataImpl &&
            (identical(other.chunkId, chunkId) || other.chunkId == chunkId) &&
            (identical(other.identity, identity) ||
                other.identity == identity) &&
            (identical(other.timing, timing) || other.timing == timing) &&
            (identical(other.capture, capture) || other.capture == capture) &&
            (identical(other.deviceContext, deviceContext) ||
                other.deviceContext == deviceContext) &&
            (identical(other.captureConditions, captureConditions) ||
                other.captureConditions == captureConditions) &&
            (identical(other.integrity, integrity) ||
                other.integrity == integrity) &&
            (identical(other.collectorAuthored, collectorAuthored) ||
                other.collectorAuthored == collectorAuthored));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    chunkId,
    identity,
    timing,
    capture,
    deviceContext,
    captureConditions,
    integrity,
    collectorAuthored,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChunkMetadataImplCopyWith<_$ChunkMetadataImpl> get copyWith =>
      __$$ChunkMetadataImplCopyWithImpl<_$ChunkMetadataImpl>(this, _$identity);
}

abstract class _ChunkMetadata extends ChunkMetadata {
  const factory _ChunkMetadata({
    required final String chunkId,
    required final MetadataIdentity identity,
    required final MetadataTiming timing,
    required final MetadataCapture capture,
    required final MetadataDeviceContext deviceContext,
    required final MetadataCaptureConditions captureConditions,
    required final ChunkIntegrity integrity,
    final CollectorAuthored collectorAuthored,
  }) = _$ChunkMetadataImpl;
  const _ChunkMetadata._() : super._();

  @override
  /// The chunk's stable UUID, minted at capture-stop (Mission 3.4.5).
  String get chunkId;
  @override
  MetadataIdentity get identity;
  @override
  MetadataTiming get timing;
  @override
  MetadataCapture get capture;
  @override
  MetadataDeviceContext get deviceContext;
  @override
  MetadataCaptureConditions get captureConditions;
  @override
  ChunkIntegrity get integrity;
  @override
  CollectorAuthored get collectorAuthored;
  @override
  @JsonKey(ignore: true)
  _$$ChunkMetadataImplCopyWith<_$ChunkMetadataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
