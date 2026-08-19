// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_fingerprint.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$DeviceFingerprint {
  /// The application's version, as `AppInfo.fullVersion` reports it.
  String get appVersion => throw _privateConstructorUsedError;

  /// The platform's version, as `Platform.operatingSystemVersion` reports.
  String get osVersion => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DeviceFingerprintCopyWith<DeviceFingerprint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeviceFingerprintCopyWith<$Res> {
  factory $DeviceFingerprintCopyWith(
    DeviceFingerprint value,
    $Res Function(DeviceFingerprint) then,
  ) = _$DeviceFingerprintCopyWithImpl<$Res, DeviceFingerprint>;
  @useResult
  $Res call({String appVersion, String osVersion});
}

/// @nodoc
class _$DeviceFingerprintCopyWithImpl<$Res, $Val extends DeviceFingerprint>
    implements $DeviceFingerprintCopyWith<$Res> {
  _$DeviceFingerprintCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? appVersion = null, Object? osVersion = null}) {
    return _then(
      _value.copyWith(
            appVersion: null == appVersion
                ? _value.appVersion
                : appVersion // ignore: cast_nullable_to_non_nullable
                      as String,
            osVersion: null == osVersion
                ? _value.osVersion
                : osVersion // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DeviceFingerprintImplCopyWith<$Res>
    implements $DeviceFingerprintCopyWith<$Res> {
  factory _$$DeviceFingerprintImplCopyWith(
    _$DeviceFingerprintImpl value,
    $Res Function(_$DeviceFingerprintImpl) then,
  ) = __$$DeviceFingerprintImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String appVersion, String osVersion});
}

/// @nodoc
class __$$DeviceFingerprintImplCopyWithImpl<$Res>
    extends _$DeviceFingerprintCopyWithImpl<$Res, _$DeviceFingerprintImpl>
    implements _$$DeviceFingerprintImplCopyWith<$Res> {
  __$$DeviceFingerprintImplCopyWithImpl(
    _$DeviceFingerprintImpl _value,
    $Res Function(_$DeviceFingerprintImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? appVersion = null, Object? osVersion = null}) {
    return _then(
      _$DeviceFingerprintImpl(
        appVersion: null == appVersion
            ? _value.appVersion
            : appVersion // ignore: cast_nullable_to_non_nullable
                  as String,
        osVersion: null == osVersion
            ? _value.osVersion
            : osVersion // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$DeviceFingerprintImpl implements _DeviceFingerprint {
  const _$DeviceFingerprintImpl({
    required this.appVersion,
    required this.osVersion,
  });

  /// The application's version, as `AppInfo.fullVersion` reports it.
  @override
  final String appVersion;

  /// The platform's version, as `Platform.operatingSystemVersion` reports.
  @override
  final String osVersion;

  @override
  String toString() {
    return 'DeviceFingerprint(appVersion: $appVersion, osVersion: $osVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeviceFingerprintImpl &&
            (identical(other.appVersion, appVersion) ||
                other.appVersion == appVersion) &&
            (identical(other.osVersion, osVersion) ||
                other.osVersion == osVersion));
  }

  @override
  int get hashCode => Object.hash(runtimeType, appVersion, osVersion);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DeviceFingerprintImplCopyWith<_$DeviceFingerprintImpl> get copyWith =>
      __$$DeviceFingerprintImplCopyWithImpl<_$DeviceFingerprintImpl>(
        this,
        _$identity,
      );
}

abstract class _DeviceFingerprint implements DeviceFingerprint {
  const factory _DeviceFingerprint({
    required final String appVersion,
    required final String osVersion,
  }) = _$DeviceFingerprintImpl;

  @override
  /// The application's version, as `AppInfo.fullVersion` reports it.
  String get appVersion;
  @override
  /// The platform's version, as `Platform.operatingSystemVersion` reports.
  String get osVersion;
  @override
  @JsonKey(ignore: true)
  _$$DeviceFingerprintImplCopyWith<_$DeviceFingerprintImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
