// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'camera_capability.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$CameraCapability {
  /// Whether any rear-facing camera exists. BR-01 requires one.
  bool get hasRearCamera => throw _privateConstructorUsedError;

  /// Tri-state: true, false, or null for "the platform cannot say".
  bool? get hasDedicatedUltraWide => throw _privateConstructorUsedError;

  /// The smallest zoom factor the rear camera reports, or null if unknown.
  ///
  /// Below 1.0 means the sensor zooms out past its native field of view,
  /// which is the Tier 2 signal. Null where no camera could be opened to
  /// ask — on Android this value requires a bound camera, which is why it
  /// cannot be read before the Checklist grants permission.
  double? get minimumZoomFactor => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $CameraCapabilityCopyWith<CameraCapability> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CameraCapabilityCopyWith<$Res> {
  factory $CameraCapabilityCopyWith(
    CameraCapability value,
    $Res Function(CameraCapability) then,
  ) = _$CameraCapabilityCopyWithImpl<$Res, CameraCapability>;
  @useResult
  $Res call({
    bool hasRearCamera,
    bool? hasDedicatedUltraWide,
    double? minimumZoomFactor,
  });
}

/// @nodoc
class _$CameraCapabilityCopyWithImpl<$Res, $Val extends CameraCapability>
    implements $CameraCapabilityCopyWith<$Res> {
  _$CameraCapabilityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hasRearCamera = null,
    Object? hasDedicatedUltraWide = freezed,
    Object? minimumZoomFactor = freezed,
  }) {
    return _then(
      _value.copyWith(
            hasRearCamera: null == hasRearCamera
                ? _value.hasRearCamera
                : hasRearCamera // ignore: cast_nullable_to_non_nullable
                      as bool,
            hasDedicatedUltraWide: freezed == hasDedicatedUltraWide
                ? _value.hasDedicatedUltraWide
                : hasDedicatedUltraWide // ignore: cast_nullable_to_non_nullable
                      as bool?,
            minimumZoomFactor: freezed == minimumZoomFactor
                ? _value.minimumZoomFactor
                : minimumZoomFactor // ignore: cast_nullable_to_non_nullable
                      as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CameraCapabilityImplCopyWith<$Res>
    implements $CameraCapabilityCopyWith<$Res> {
  factory _$$CameraCapabilityImplCopyWith(
    _$CameraCapabilityImpl value,
    $Res Function(_$CameraCapabilityImpl) then,
  ) = __$$CameraCapabilityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool hasRearCamera,
    bool? hasDedicatedUltraWide,
    double? minimumZoomFactor,
  });
}

/// @nodoc
class __$$CameraCapabilityImplCopyWithImpl<$Res>
    extends _$CameraCapabilityCopyWithImpl<$Res, _$CameraCapabilityImpl>
    implements _$$CameraCapabilityImplCopyWith<$Res> {
  __$$CameraCapabilityImplCopyWithImpl(
    _$CameraCapabilityImpl _value,
    $Res Function(_$CameraCapabilityImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hasRearCamera = null,
    Object? hasDedicatedUltraWide = freezed,
    Object? minimumZoomFactor = freezed,
  }) {
    return _then(
      _$CameraCapabilityImpl(
        hasRearCamera: null == hasRearCamera
            ? _value.hasRearCamera
            : hasRearCamera // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasDedicatedUltraWide: freezed == hasDedicatedUltraWide
            ? _value.hasDedicatedUltraWide
            : hasDedicatedUltraWide // ignore: cast_nullable_to_non_nullable
                  as bool?,
        minimumZoomFactor: freezed == minimumZoomFactor
            ? _value.minimumZoomFactor
            : minimumZoomFactor // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}

/// @nodoc

class _$CameraCapabilityImpl extends _CameraCapability {
  const _$CameraCapabilityImpl({
    required this.hasRearCamera,
    required this.hasDedicatedUltraWide,
    required this.minimumZoomFactor,
  }) : super._();

  /// Whether any rear-facing camera exists. BR-01 requires one.
  @override
  final bool hasRearCamera;

  /// Tri-state: true, false, or null for "the platform cannot say".
  @override
  final bool? hasDedicatedUltraWide;

  /// The smallest zoom factor the rear camera reports, or null if unknown.
  ///
  /// Below 1.0 means the sensor zooms out past its native field of view,
  /// which is the Tier 2 signal. Null where no camera could be opened to
  /// ask — on Android this value requires a bound camera, which is why it
  /// cannot be read before the Checklist grants permission.
  @override
  final double? minimumZoomFactor;

  @override
  String toString() {
    return 'CameraCapability(hasRearCamera: $hasRearCamera, hasDedicatedUltraWide: $hasDedicatedUltraWide, minimumZoomFactor: $minimumZoomFactor)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CameraCapabilityImpl &&
            (identical(other.hasRearCamera, hasRearCamera) ||
                other.hasRearCamera == hasRearCamera) &&
            (identical(other.hasDedicatedUltraWide, hasDedicatedUltraWide) ||
                other.hasDedicatedUltraWide == hasDedicatedUltraWide) &&
            (identical(other.minimumZoomFactor, minimumZoomFactor) ||
                other.minimumZoomFactor == minimumZoomFactor));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    hasRearCamera,
    hasDedicatedUltraWide,
    minimumZoomFactor,
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CameraCapabilityImplCopyWith<_$CameraCapabilityImpl> get copyWith =>
      __$$CameraCapabilityImplCopyWithImpl<_$CameraCapabilityImpl>(
        this,
        _$identity,
      );
}

abstract class _CameraCapability extends CameraCapability {
  const factory _CameraCapability({
    required final bool hasRearCamera,
    required final bool? hasDedicatedUltraWide,
    required final double? minimumZoomFactor,
  }) = _$CameraCapabilityImpl;
  const _CameraCapability._() : super._();

  @override
  /// Whether any rear-facing camera exists. BR-01 requires one.
  bool get hasRearCamera;
  @override
  /// Tri-state: true, false, or null for "the platform cannot say".
  bool? get hasDedicatedUltraWide;
  @override
  /// The smallest zoom factor the rear camera reports, or null if unknown.
  ///
  /// Below 1.0 means the sensor zooms out past its native field of view,
  /// which is the Tier 2 signal. Null where no camera could be opened to
  /// ask — on Android this value requires a bound camera, which is why it
  /// cannot be read before the Checklist grants permission.
  double? get minimumZoomFactor;
  @override
  @JsonKey(ignore: true)
  _$$CameraCapabilityImplCopyWith<_$CameraCapabilityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
