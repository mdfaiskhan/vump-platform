// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checklist_outcome.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ChecklistOutcome {
  /// FR-CHK-01. Null until probed; an [ErrorCode] names *which* grant is
  /// missing, which is what C-08's per-row remedy needs.
  bool? get permissionsGranted => throw _privateConstructorUsedError;

  /// Why [permissionsGranted] is false, when it is.
  ErrorCode? get permissionFailure => throw _privateConstructorUsedError;

  /// FR-CHK-02 — bytes free on the volume recordings are written to.
  int? get availableBytes => throw _privateConstructorUsedError;

  /// FR-CHK-03 — charge percentage, 0–100.
  int? get batteryPercent => throw _privateConstructorUsedError;

  /// FR-CHK-04 — the connection kind. Never blocks (Ch. 2.9 §5).
  NetworkType? get network => throw _privateConstructorUsedError;

  /// A-057's verdict, from cache when the fingerprint still matches.
  WideAngleEligibility? get wideAngle => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ChecklistOutcomeCopyWith<ChecklistOutcome> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChecklistOutcomeCopyWith<$Res> {
  factory $ChecklistOutcomeCopyWith(
          ChecklistOutcome value, $Res Function(ChecklistOutcome) then) =
      _$ChecklistOutcomeCopyWithImpl<$Res, ChecklistOutcome>;
  @useResult
  $Res call(
      {bool? permissionsGranted,
      ErrorCode? permissionFailure,
      int? availableBytes,
      int? batteryPercent,
      NetworkType? network,
      WideAngleEligibility? wideAngle});

  $WideAngleEligibilityCopyWith<$Res>? get wideAngle;
}

/// @nodoc
class _$ChecklistOutcomeCopyWithImpl<$Res, $Val extends ChecklistOutcome>
    implements $ChecklistOutcomeCopyWith<$Res> {
  _$ChecklistOutcomeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? permissionsGranted = freezed,
    Object? permissionFailure = freezed,
    Object? availableBytes = freezed,
    Object? batteryPercent = freezed,
    Object? network = freezed,
    Object? wideAngle = freezed,
  }) {
    return _then(_value.copyWith(
      permissionsGranted: freezed == permissionsGranted
          ? _value.permissionsGranted
          : permissionsGranted // ignore: cast_nullable_to_non_nullable
              as bool?,
      permissionFailure: freezed == permissionFailure
          ? _value.permissionFailure
          : permissionFailure // ignore: cast_nullable_to_non_nullable
              as ErrorCode?,
      availableBytes: freezed == availableBytes
          ? _value.availableBytes
          : availableBytes // ignore: cast_nullable_to_non_nullable
              as int?,
      batteryPercent: freezed == batteryPercent
          ? _value.batteryPercent
          : batteryPercent // ignore: cast_nullable_to_non_nullable
              as int?,
      network: freezed == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as NetworkType?,
      wideAngle: freezed == wideAngle
          ? _value.wideAngle
          : wideAngle // ignore: cast_nullable_to_non_nullable
              as WideAngleEligibility?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $WideAngleEligibilityCopyWith<$Res>? get wideAngle {
    if (_value.wideAngle == null) {
      return null;
    }

    return $WideAngleEligibilityCopyWith<$Res>(_value.wideAngle!, (value) {
      return _then(_value.copyWith(wideAngle: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ChecklistOutcomeImplCopyWith<$Res>
    implements $ChecklistOutcomeCopyWith<$Res> {
  factory _$$ChecklistOutcomeImplCopyWith(_$ChecklistOutcomeImpl value,
          $Res Function(_$ChecklistOutcomeImpl) then) =
      __$$ChecklistOutcomeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool? permissionsGranted,
      ErrorCode? permissionFailure,
      int? availableBytes,
      int? batteryPercent,
      NetworkType? network,
      WideAngleEligibility? wideAngle});

  @override
  $WideAngleEligibilityCopyWith<$Res>? get wideAngle;
}

/// @nodoc
class __$$ChecklistOutcomeImplCopyWithImpl<$Res>
    extends _$ChecklistOutcomeCopyWithImpl<$Res, _$ChecklistOutcomeImpl>
    implements _$$ChecklistOutcomeImplCopyWith<$Res> {
  __$$ChecklistOutcomeImplCopyWithImpl(_$ChecklistOutcomeImpl _value,
      $Res Function(_$ChecklistOutcomeImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? permissionsGranted = freezed,
    Object? permissionFailure = freezed,
    Object? availableBytes = freezed,
    Object? batteryPercent = freezed,
    Object? network = freezed,
    Object? wideAngle = freezed,
  }) {
    return _then(_$ChecklistOutcomeImpl(
      permissionsGranted: freezed == permissionsGranted
          ? _value.permissionsGranted
          : permissionsGranted // ignore: cast_nullable_to_non_nullable
              as bool?,
      permissionFailure: freezed == permissionFailure
          ? _value.permissionFailure
          : permissionFailure // ignore: cast_nullable_to_non_nullable
              as ErrorCode?,
      availableBytes: freezed == availableBytes
          ? _value.availableBytes
          : availableBytes // ignore: cast_nullable_to_non_nullable
              as int?,
      batteryPercent: freezed == batteryPercent
          ? _value.batteryPercent
          : batteryPercent // ignore: cast_nullable_to_non_nullable
              as int?,
      network: freezed == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as NetworkType?,
      wideAngle: freezed == wideAngle
          ? _value.wideAngle
          : wideAngle // ignore: cast_nullable_to_non_nullable
              as WideAngleEligibility?,
    ));
  }
}

/// @nodoc

class _$ChecklistOutcomeImpl extends _ChecklistOutcome {
  const _$ChecklistOutcomeImpl(
      {this.permissionsGranted,
      this.permissionFailure,
      this.availableBytes,
      this.batteryPercent,
      this.network,
      this.wideAngle})
      : super._();

  /// FR-CHK-01. Null until probed; an [ErrorCode] names *which* grant is
  /// missing, which is what C-08's per-row remedy needs.
  @override
  final bool? permissionsGranted;

  /// Why [permissionsGranted] is false, when it is.
  @override
  final ErrorCode? permissionFailure;

  /// FR-CHK-02 — bytes free on the volume recordings are written to.
  @override
  final int? availableBytes;

  /// FR-CHK-03 — charge percentage, 0–100.
  @override
  final int? batteryPercent;

  /// FR-CHK-04 — the connection kind. Never blocks (Ch. 2.9 §5).
  @override
  final NetworkType? network;

  /// A-057's verdict, from cache when the fingerprint still matches.
  @override
  final WideAngleEligibility? wideAngle;

  @override
  String toString() {
    return 'ChecklistOutcome(permissionsGranted: $permissionsGranted, permissionFailure: $permissionFailure, availableBytes: $availableBytes, batteryPercent: $batteryPercent, network: $network, wideAngle: $wideAngle)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistOutcomeImpl &&
            (identical(other.permissionsGranted, permissionsGranted) ||
                other.permissionsGranted == permissionsGranted) &&
            (identical(other.permissionFailure, permissionFailure) ||
                other.permissionFailure == permissionFailure) &&
            (identical(other.availableBytes, availableBytes) ||
                other.availableBytes == availableBytes) &&
            (identical(other.batteryPercent, batteryPercent) ||
                other.batteryPercent == batteryPercent) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.wideAngle, wideAngle) ||
                other.wideAngle == wideAngle));
  }

  @override
  int get hashCode => Object.hash(runtimeType, permissionsGranted,
      permissionFailure, availableBytes, batteryPercent, network, wideAngle);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChecklistOutcomeImplCopyWith<_$ChecklistOutcomeImpl> get copyWith =>
      __$$ChecklistOutcomeImplCopyWithImpl<_$ChecklistOutcomeImpl>(
          this, _$identity);
}

abstract class _ChecklistOutcome extends ChecklistOutcome {
  const factory _ChecklistOutcome(
      {final bool? permissionsGranted,
      final ErrorCode? permissionFailure,
      final int? availableBytes,
      final int? batteryPercent,
      final NetworkType? network,
      final WideAngleEligibility? wideAngle}) = _$ChecklistOutcomeImpl;
  const _ChecklistOutcome._() : super._();

  @override

  /// FR-CHK-01. Null until probed; an [ErrorCode] names *which* grant is
  /// missing, which is what C-08's per-row remedy needs.
  bool? get permissionsGranted;
  @override

  /// Why [permissionsGranted] is false, when it is.
  ErrorCode? get permissionFailure;
  @override

  /// FR-CHK-02 — bytes free on the volume recordings are written to.
  int? get availableBytes;
  @override

  /// FR-CHK-03 — charge percentage, 0–100.
  int? get batteryPercent;
  @override

  /// FR-CHK-04 — the connection kind. Never blocks (Ch. 2.9 §5).
  NetworkType? get network;
  @override

  /// A-057's verdict, from cache when the fingerprint still matches.
  WideAngleEligibility? get wideAngle;
  @override
  @JsonKey(ignore: true)
  _$$ChecklistOutcomeImplCopyWith<_$ChecklistOutcomeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
