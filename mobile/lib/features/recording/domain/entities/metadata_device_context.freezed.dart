// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'metadata_device_context.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MetadataDeviceContext {
  /// From `DeviceContext` — no source in this project yet.
  String get deviceModel => throw _privateConstructorUsedError;

  /// From `Platform.operatingSystemVersion`.
  String get osVersion => throw _privateConstructorUsedError;

  /// From `AppInfo.fullVersion`, supplied rather than imported.
  String get appVersion => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MetadataDeviceContextCopyWith<MetadataDeviceContext> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetadataDeviceContextCopyWith<$Res> {
  factory $MetadataDeviceContextCopyWith(
    MetadataDeviceContext value,
    $Res Function(MetadataDeviceContext) then,
  ) = _$MetadataDeviceContextCopyWithImpl<$Res, MetadataDeviceContext>;
  @useResult
  $Res call({String deviceModel, String osVersion, String appVersion});
}

/// @nodoc
class _$MetadataDeviceContextCopyWithImpl<
  $Res,
  $Val extends MetadataDeviceContext
>
    implements $MetadataDeviceContextCopyWith<$Res> {
  _$MetadataDeviceContextCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviceModel = null,
    Object? osVersion = null,
    Object? appVersion = null,
  }) {
    return _then(
      _value.copyWith(
            deviceModel: null == deviceModel
                ? _value.deviceModel
                : deviceModel // ignore: cast_nullable_to_non_nullable
                      as String,
            osVersion: null == osVersion
                ? _value.osVersion
                : osVersion // ignore: cast_nullable_to_non_nullable
                      as String,
            appVersion: null == appVersion
                ? _value.appVersion
                : appVersion // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MetadataDeviceContextImplCopyWith<$Res>
    implements $MetadataDeviceContextCopyWith<$Res> {
  factory _$$MetadataDeviceContextImplCopyWith(
    _$MetadataDeviceContextImpl value,
    $Res Function(_$MetadataDeviceContextImpl) then,
  ) = __$$MetadataDeviceContextImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String deviceModel, String osVersion, String appVersion});
}

/// @nodoc
class __$$MetadataDeviceContextImplCopyWithImpl<$Res>
    extends
        _$MetadataDeviceContextCopyWithImpl<$Res, _$MetadataDeviceContextImpl>
    implements _$$MetadataDeviceContextImplCopyWith<$Res> {
  __$$MetadataDeviceContextImplCopyWithImpl(
    _$MetadataDeviceContextImpl _value,
    $Res Function(_$MetadataDeviceContextImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviceModel = null,
    Object? osVersion = null,
    Object? appVersion = null,
  }) {
    return _then(
      _$MetadataDeviceContextImpl(
        deviceModel: null == deviceModel
            ? _value.deviceModel
            : deviceModel // ignore: cast_nullable_to_non_nullable
                  as String,
        osVersion: null == osVersion
            ? _value.osVersion
            : osVersion // ignore: cast_nullable_to_non_nullable
                  as String,
        appVersion: null == appVersion
            ? _value.appVersion
            : appVersion // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$MetadataDeviceContextImpl implements _MetadataDeviceContext {
  const _$MetadataDeviceContextImpl({
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
  });

  /// From `DeviceContext` — no source in this project yet.
  @override
  final String deviceModel;

  /// From `Platform.operatingSystemVersion`.
  @override
  final String osVersion;

  /// From `AppInfo.fullVersion`, supplied rather than imported.
  @override
  final String appVersion;

  @override
  String toString() {
    return 'MetadataDeviceContext(deviceModel: $deviceModel, osVersion: $osVersion, appVersion: $appVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetadataDeviceContextImpl &&
            (identical(other.deviceModel, deviceModel) ||
                other.deviceModel == deviceModel) &&
            (identical(other.osVersion, osVersion) ||
                other.osVersion == osVersion) &&
            (identical(other.appVersion, appVersion) ||
                other.appVersion == appVersion));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, deviceModel, osVersion, appVersion);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MetadataDeviceContextImplCopyWith<_$MetadataDeviceContextImpl>
  get copyWith =>
      __$$MetadataDeviceContextImplCopyWithImpl<_$MetadataDeviceContextImpl>(
        this,
        _$identity,
      );
}

abstract class _MetadataDeviceContext implements MetadataDeviceContext {
  const factory _MetadataDeviceContext({
    required final String deviceModel,
    required final String osVersion,
    required final String appVersion,
  }) = _$MetadataDeviceContextImpl;

  @override
  /// From `DeviceContext` — no source in this project yet.
  String get deviceModel;
  @override
  /// From `Platform.operatingSystemVersion`.
  String get osVersion;
  @override
  /// From `AppInfo.fullVersion`, supplied rather than imported.
  String get appVersion;
  @override
  @JsonKey(ignore: true)
  _$$MetadataDeviceContextImplCopyWith<_$MetadataDeviceContextImpl>
  get copyWith => throw _privateConstructorUsedError;
}
