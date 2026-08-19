// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'metadata_capture_conditions.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MetadataCaptureConditions {
  /// Null when location permission was refused, or — today — when nothing
  /// reads it at all.
  GpsFix? get gps => throw _privateConstructorUsedError;

  /// Battery charge percentage, 0-100. Null when unavailable.
  int? get batteryPercent => throw _privateConstructorUsedError;

  /// `"wifi"`, `"cellular"`, `"none"`. Null when unavailable.
  String? get networkType => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MetadataCaptureConditionsCopyWith<MetadataCaptureConditions> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetadataCaptureConditionsCopyWith<$Res> {
  factory $MetadataCaptureConditionsCopyWith(
    MetadataCaptureConditions value,
    $Res Function(MetadataCaptureConditions) then,
  ) = _$MetadataCaptureConditionsCopyWithImpl<$Res, MetadataCaptureConditions>;
  @useResult
  $Res call({GpsFix? gps, int? batteryPercent, String? networkType});

  $GpsFixCopyWith<$Res>? get gps;
}

/// @nodoc
class _$MetadataCaptureConditionsCopyWithImpl<
  $Res,
  $Val extends MetadataCaptureConditions
>
    implements $MetadataCaptureConditionsCopyWith<$Res> {
  _$MetadataCaptureConditionsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gps = freezed,
    Object? batteryPercent = freezed,
    Object? networkType = freezed,
  }) {
    return _then(
      _value.copyWith(
            gps: freezed == gps
                ? _value.gps
                : gps // ignore: cast_nullable_to_non_nullable
                      as GpsFix?,
            batteryPercent: freezed == batteryPercent
                ? _value.batteryPercent
                : batteryPercent // ignore: cast_nullable_to_non_nullable
                      as int?,
            networkType: freezed == networkType
                ? _value.networkType
                : networkType // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  @override
  @pragma('vm:prefer-inline')
  $GpsFixCopyWith<$Res>? get gps {
    if (_value.gps == null) {
      return null;
    }

    return $GpsFixCopyWith<$Res>(_value.gps!, (value) {
      return _then(_value.copyWith(gps: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MetadataCaptureConditionsImplCopyWith<$Res>
    implements $MetadataCaptureConditionsCopyWith<$Res> {
  factory _$$MetadataCaptureConditionsImplCopyWith(
    _$MetadataCaptureConditionsImpl value,
    $Res Function(_$MetadataCaptureConditionsImpl) then,
  ) = __$$MetadataCaptureConditionsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({GpsFix? gps, int? batteryPercent, String? networkType});

  @override
  $GpsFixCopyWith<$Res>? get gps;
}

/// @nodoc
class __$$MetadataCaptureConditionsImplCopyWithImpl<$Res>
    extends
        _$MetadataCaptureConditionsCopyWithImpl<
          $Res,
          _$MetadataCaptureConditionsImpl
        >
    implements _$$MetadataCaptureConditionsImplCopyWith<$Res> {
  __$$MetadataCaptureConditionsImplCopyWithImpl(
    _$MetadataCaptureConditionsImpl _value,
    $Res Function(_$MetadataCaptureConditionsImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gps = freezed,
    Object? batteryPercent = freezed,
    Object? networkType = freezed,
  }) {
    return _then(
      _$MetadataCaptureConditionsImpl(
        gps: freezed == gps
            ? _value.gps
            : gps // ignore: cast_nullable_to_non_nullable
                  as GpsFix?,
        batteryPercent: freezed == batteryPercent
            ? _value.batteryPercent
            : batteryPercent // ignore: cast_nullable_to_non_nullable
                  as int?,
        networkType: freezed == networkType
            ? _value.networkType
            : networkType // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$MetadataCaptureConditionsImpl extends _MetadataCaptureConditions {
  const _$MetadataCaptureConditionsImpl({
    this.gps,
    this.batteryPercent,
    this.networkType,
  }) : super._();

  /// Null when location permission was refused, or — today — when nothing
  /// reads it at all.
  @override
  final GpsFix? gps;

  /// Battery charge percentage, 0-100. Null when unavailable.
  @override
  final int? batteryPercent;

  /// `"wifi"`, `"cellular"`, `"none"`. Null when unavailable.
  @override
  final String? networkType;

  @override
  String toString() {
    return 'MetadataCaptureConditions(gps: $gps, batteryPercent: $batteryPercent, networkType: $networkType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetadataCaptureConditionsImpl &&
            (identical(other.gps, gps) || other.gps == gps) &&
            (identical(other.batteryPercent, batteryPercent) ||
                other.batteryPercent == batteryPercent) &&
            (identical(other.networkType, networkType) ||
                other.networkType == networkType));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, gps, batteryPercent, networkType);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MetadataCaptureConditionsImplCopyWith<_$MetadataCaptureConditionsImpl>
  get copyWith =>
      __$$MetadataCaptureConditionsImplCopyWithImpl<
        _$MetadataCaptureConditionsImpl
      >(this, _$identity);
}

abstract class _MetadataCaptureConditions extends MetadataCaptureConditions {
  const factory _MetadataCaptureConditions({
    final GpsFix? gps,
    final int? batteryPercent,
    final String? networkType,
  }) = _$MetadataCaptureConditionsImpl;
  const _MetadataCaptureConditions._() : super._();

  @override
  /// Null when location permission was refused, or — today — when nothing
  /// reads it at all.
  GpsFix? get gps;
  @override
  /// Battery charge percentage, 0-100. Null when unavailable.
  int? get batteryPercent;
  @override
  /// `"wifi"`, `"cellular"`, `"none"`. Null when unavailable.
  String? get networkType;
  @override
  @JsonKey(ignore: true)
  _$$MetadataCaptureConditionsImplCopyWith<_$MetadataCaptureConditionsImpl>
  get copyWith => throw _privateConstructorUsedError;
}
