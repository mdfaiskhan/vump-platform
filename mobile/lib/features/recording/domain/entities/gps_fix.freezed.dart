// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gps_fix.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$GpsFix {
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $GpsFixCopyWith<GpsFix> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GpsFixCopyWith<$Res> {
  factory $GpsFixCopyWith(GpsFix value, $Res Function(GpsFix) then) =
      _$GpsFixCopyWithImpl<$Res, GpsFix>;
  @useResult
  $Res call({double latitude, double longitude});
}

/// @nodoc
class _$GpsFixCopyWithImpl<$Res, $Val extends GpsFix>
    implements $GpsFixCopyWith<$Res> {
  _$GpsFixCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? latitude = null,
    Object? longitude = null,
  }) {
    return _then(_value.copyWith(
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GpsFixImplCopyWith<$Res> implements $GpsFixCopyWith<$Res> {
  factory _$$GpsFixImplCopyWith(
          _$GpsFixImpl value, $Res Function(_$GpsFixImpl) then) =
      __$$GpsFixImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double latitude, double longitude});
}

/// @nodoc
class __$$GpsFixImplCopyWithImpl<$Res>
    extends _$GpsFixCopyWithImpl<$Res, _$GpsFixImpl>
    implements _$$GpsFixImplCopyWith<$Res> {
  __$$GpsFixImplCopyWithImpl(
      _$GpsFixImpl _value, $Res Function(_$GpsFixImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? latitude = null,
    Object? longitude = null,
  }) {
    return _then(_$GpsFixImpl(
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$GpsFixImpl implements _GpsFix {
  const _$GpsFixImpl({required this.latitude, required this.longitude});

  @override
  final double latitude;
  @override
  final double longitude;

  @override
  String toString() {
    return 'GpsFix(latitude: $latitude, longitude: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GpsFixImpl &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude));
  }

  @override
  int get hashCode => Object.hash(runtimeType, latitude, longitude);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GpsFixImplCopyWith<_$GpsFixImpl> get copyWith =>
      __$$GpsFixImplCopyWithImpl<_$GpsFixImpl>(this, _$identity);
}

abstract class _GpsFix implements GpsFix {
  const factory _GpsFix(
      {required final double latitude,
      required final double longitude}) = _$GpsFixImpl;

  @override
  double get latitude;
  @override
  double get longitude;
  @override
  @JsonKey(ignore: true)
  _$$GpsFixImplCopyWith<_$GpsFixImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
