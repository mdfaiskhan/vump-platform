// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wide_angle_eligibility.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$WideAngleEligibility {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(double zoomFactor) optical,
    required TResult Function(double zoomFactor) hybrid,
    required TResult Function(WideAngleIneligibleReason reason) ineligible,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(double zoomFactor)? optical,
    TResult? Function(double zoomFactor)? hybrid,
    TResult? Function(WideAngleIneligibleReason reason)? ineligible,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(double zoomFactor)? optical,
    TResult Function(double zoomFactor)? hybrid,
    TResult Function(WideAngleIneligibleReason reason)? ineligible,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(WideAngleEligibilityOptical value) optical,
    required TResult Function(WideAngleEligibilityHybrid value) hybrid,
    required TResult Function(WideAngleEligibilityIneligible value) ineligible,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(WideAngleEligibilityOptical value)? optical,
    TResult? Function(WideAngleEligibilityHybrid value)? hybrid,
    TResult? Function(WideAngleEligibilityIneligible value)? ineligible,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(WideAngleEligibilityOptical value)? optical,
    TResult Function(WideAngleEligibilityHybrid value)? hybrid,
    TResult Function(WideAngleEligibilityIneligible value)? ineligible,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WideAngleEligibilityCopyWith<$Res> {
  factory $WideAngleEligibilityCopyWith(WideAngleEligibility value,
          $Res Function(WideAngleEligibility) then) =
      _$WideAngleEligibilityCopyWithImpl<$Res, WideAngleEligibility>;
}

/// @nodoc
class _$WideAngleEligibilityCopyWithImpl<$Res,
        $Val extends WideAngleEligibility>
    implements $WideAngleEligibilityCopyWith<$Res> {
  _$WideAngleEligibilityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$WideAngleEligibilityOpticalImplCopyWith<$Res> {
  factory _$$WideAngleEligibilityOpticalImplCopyWith(
          _$WideAngleEligibilityOpticalImpl value,
          $Res Function(_$WideAngleEligibilityOpticalImpl) then) =
      __$$WideAngleEligibilityOpticalImplCopyWithImpl<$Res>;
  @useResult
  $Res call({double zoomFactor});
}

/// @nodoc
class __$$WideAngleEligibilityOpticalImplCopyWithImpl<$Res>
    extends _$WideAngleEligibilityCopyWithImpl<$Res,
        _$WideAngleEligibilityOpticalImpl>
    implements _$$WideAngleEligibilityOpticalImplCopyWith<$Res> {
  __$$WideAngleEligibilityOpticalImplCopyWithImpl(
      _$WideAngleEligibilityOpticalImpl _value,
      $Res Function(_$WideAngleEligibilityOpticalImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? zoomFactor = null,
  }) {
    return _then(_$WideAngleEligibilityOpticalImpl(
      zoomFactor: null == zoomFactor
          ? _value.zoomFactor
          : zoomFactor // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$WideAngleEligibilityOpticalImpl extends WideAngleEligibilityOptical {
  const _$WideAngleEligibilityOpticalImpl({required this.zoomFactor})
      : super._();

  @override
  final double zoomFactor;

  @override
  String toString() {
    return 'WideAngleEligibility.optical(zoomFactor: $zoomFactor)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WideAngleEligibilityOpticalImpl &&
            (identical(other.zoomFactor, zoomFactor) ||
                other.zoomFactor == zoomFactor));
  }

  @override
  int get hashCode => Object.hash(runtimeType, zoomFactor);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WideAngleEligibilityOpticalImplCopyWith<_$WideAngleEligibilityOpticalImpl>
      get copyWith => __$$WideAngleEligibilityOpticalImplCopyWithImpl<
          _$WideAngleEligibilityOpticalImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(double zoomFactor) optical,
    required TResult Function(double zoomFactor) hybrid,
    required TResult Function(WideAngleIneligibleReason reason) ineligible,
  }) {
    return optical(zoomFactor);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(double zoomFactor)? optical,
    TResult? Function(double zoomFactor)? hybrid,
    TResult? Function(WideAngleIneligibleReason reason)? ineligible,
  }) {
    return optical?.call(zoomFactor);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(double zoomFactor)? optical,
    TResult Function(double zoomFactor)? hybrid,
    TResult Function(WideAngleIneligibleReason reason)? ineligible,
    required TResult orElse(),
  }) {
    if (optical != null) {
      return optical(zoomFactor);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(WideAngleEligibilityOptical value) optical,
    required TResult Function(WideAngleEligibilityHybrid value) hybrid,
    required TResult Function(WideAngleEligibilityIneligible value) ineligible,
  }) {
    return optical(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(WideAngleEligibilityOptical value)? optical,
    TResult? Function(WideAngleEligibilityHybrid value)? hybrid,
    TResult? Function(WideAngleEligibilityIneligible value)? ineligible,
  }) {
    return optical?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(WideAngleEligibilityOptical value)? optical,
    TResult Function(WideAngleEligibilityHybrid value)? hybrid,
    TResult Function(WideAngleEligibilityIneligible value)? ineligible,
    required TResult orElse(),
  }) {
    if (optical != null) {
      return optical(this);
    }
    return orElse();
  }
}

abstract class WideAngleEligibilityOptical extends WideAngleEligibility {
  const factory WideAngleEligibilityOptical(
      {required final double zoomFactor}) = _$WideAngleEligibilityOpticalImpl;
  const WideAngleEligibilityOptical._() : super._();

  double get zoomFactor;
  @JsonKey(ignore: true)
  _$$WideAngleEligibilityOpticalImplCopyWith<_$WideAngleEligibilityOpticalImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$WideAngleEligibilityHybridImplCopyWith<$Res> {
  factory _$$WideAngleEligibilityHybridImplCopyWith(
          _$WideAngleEligibilityHybridImpl value,
          $Res Function(_$WideAngleEligibilityHybridImpl) then) =
      __$$WideAngleEligibilityHybridImplCopyWithImpl<$Res>;
  @useResult
  $Res call({double zoomFactor});
}

/// @nodoc
class __$$WideAngleEligibilityHybridImplCopyWithImpl<$Res>
    extends _$WideAngleEligibilityCopyWithImpl<$Res,
        _$WideAngleEligibilityHybridImpl>
    implements _$$WideAngleEligibilityHybridImplCopyWith<$Res> {
  __$$WideAngleEligibilityHybridImplCopyWithImpl(
      _$WideAngleEligibilityHybridImpl _value,
      $Res Function(_$WideAngleEligibilityHybridImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? zoomFactor = null,
  }) {
    return _then(_$WideAngleEligibilityHybridImpl(
      zoomFactor: null == zoomFactor
          ? _value.zoomFactor
          : zoomFactor // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$WideAngleEligibilityHybridImpl extends WideAngleEligibilityHybrid {
  const _$WideAngleEligibilityHybridImpl({required this.zoomFactor})
      : super._();

  @override
  final double zoomFactor;

  @override
  String toString() {
    return 'WideAngleEligibility.hybrid(zoomFactor: $zoomFactor)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WideAngleEligibilityHybridImpl &&
            (identical(other.zoomFactor, zoomFactor) ||
                other.zoomFactor == zoomFactor));
  }

  @override
  int get hashCode => Object.hash(runtimeType, zoomFactor);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WideAngleEligibilityHybridImplCopyWith<_$WideAngleEligibilityHybridImpl>
      get copyWith => __$$WideAngleEligibilityHybridImplCopyWithImpl<
          _$WideAngleEligibilityHybridImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(double zoomFactor) optical,
    required TResult Function(double zoomFactor) hybrid,
    required TResult Function(WideAngleIneligibleReason reason) ineligible,
  }) {
    return hybrid(zoomFactor);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(double zoomFactor)? optical,
    TResult? Function(double zoomFactor)? hybrid,
    TResult? Function(WideAngleIneligibleReason reason)? ineligible,
  }) {
    return hybrid?.call(zoomFactor);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(double zoomFactor)? optical,
    TResult Function(double zoomFactor)? hybrid,
    TResult Function(WideAngleIneligibleReason reason)? ineligible,
    required TResult orElse(),
  }) {
    if (hybrid != null) {
      return hybrid(zoomFactor);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(WideAngleEligibilityOptical value) optical,
    required TResult Function(WideAngleEligibilityHybrid value) hybrid,
    required TResult Function(WideAngleEligibilityIneligible value) ineligible,
  }) {
    return hybrid(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(WideAngleEligibilityOptical value)? optical,
    TResult? Function(WideAngleEligibilityHybrid value)? hybrid,
    TResult? Function(WideAngleEligibilityIneligible value)? ineligible,
  }) {
    return hybrid?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(WideAngleEligibilityOptical value)? optical,
    TResult Function(WideAngleEligibilityHybrid value)? hybrid,
    TResult Function(WideAngleEligibilityIneligible value)? ineligible,
    required TResult orElse(),
  }) {
    if (hybrid != null) {
      return hybrid(this);
    }
    return orElse();
  }
}

abstract class WideAngleEligibilityHybrid extends WideAngleEligibility {
  const factory WideAngleEligibilityHybrid({required final double zoomFactor}) =
      _$WideAngleEligibilityHybridImpl;
  const WideAngleEligibilityHybrid._() : super._();

  double get zoomFactor;
  @JsonKey(ignore: true)
  _$$WideAngleEligibilityHybridImplCopyWith<_$WideAngleEligibilityHybridImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$WideAngleEligibilityIneligibleImplCopyWith<$Res> {
  factory _$$WideAngleEligibilityIneligibleImplCopyWith(
          _$WideAngleEligibilityIneligibleImpl value,
          $Res Function(_$WideAngleEligibilityIneligibleImpl) then) =
      __$$WideAngleEligibilityIneligibleImplCopyWithImpl<$Res>;
  @useResult
  $Res call({WideAngleIneligibleReason reason});
}

/// @nodoc
class __$$WideAngleEligibilityIneligibleImplCopyWithImpl<$Res>
    extends _$WideAngleEligibilityCopyWithImpl<$Res,
        _$WideAngleEligibilityIneligibleImpl>
    implements _$$WideAngleEligibilityIneligibleImplCopyWith<$Res> {
  __$$WideAngleEligibilityIneligibleImplCopyWithImpl(
      _$WideAngleEligibilityIneligibleImpl _value,
      $Res Function(_$WideAngleEligibilityIneligibleImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? reason = null,
  }) {
    return _then(_$WideAngleEligibilityIneligibleImpl(
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as WideAngleIneligibleReason,
    ));
  }
}

/// @nodoc

class _$WideAngleEligibilityIneligibleImpl
    extends WideAngleEligibilityIneligible {
  const _$WideAngleEligibilityIneligibleImpl({required this.reason})
      : super._();

  @override
  final WideAngleIneligibleReason reason;

  @override
  String toString() {
    return 'WideAngleEligibility.ineligible(reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WideAngleEligibilityIneligibleImpl &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @override
  int get hashCode => Object.hash(runtimeType, reason);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WideAngleEligibilityIneligibleImplCopyWith<
          _$WideAngleEligibilityIneligibleImpl>
      get copyWith => __$$WideAngleEligibilityIneligibleImplCopyWithImpl<
          _$WideAngleEligibilityIneligibleImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(double zoomFactor) optical,
    required TResult Function(double zoomFactor) hybrid,
    required TResult Function(WideAngleIneligibleReason reason) ineligible,
  }) {
    return ineligible(reason);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(double zoomFactor)? optical,
    TResult? Function(double zoomFactor)? hybrid,
    TResult? Function(WideAngleIneligibleReason reason)? ineligible,
  }) {
    return ineligible?.call(reason);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(double zoomFactor)? optical,
    TResult Function(double zoomFactor)? hybrid,
    TResult Function(WideAngleIneligibleReason reason)? ineligible,
    required TResult orElse(),
  }) {
    if (ineligible != null) {
      return ineligible(reason);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(WideAngleEligibilityOptical value) optical,
    required TResult Function(WideAngleEligibilityHybrid value) hybrid,
    required TResult Function(WideAngleEligibilityIneligible value) ineligible,
  }) {
    return ineligible(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(WideAngleEligibilityOptical value)? optical,
    TResult? Function(WideAngleEligibilityHybrid value)? hybrid,
    TResult? Function(WideAngleEligibilityIneligible value)? ineligible,
  }) {
    return ineligible?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(WideAngleEligibilityOptical value)? optical,
    TResult Function(WideAngleEligibilityHybrid value)? hybrid,
    TResult Function(WideAngleEligibilityIneligible value)? ineligible,
    required TResult orElse(),
  }) {
    if (ineligible != null) {
      return ineligible(this);
    }
    return orElse();
  }
}

abstract class WideAngleEligibilityIneligible extends WideAngleEligibility {
  const factory WideAngleEligibilityIneligible(
          {required final WideAngleIneligibleReason reason}) =
      _$WideAngleEligibilityIneligibleImpl;
  const WideAngleEligibilityIneligible._() : super._();

  WideAngleIneligibleReason get reason;
  @JsonKey(ignore: true)
  _$$WideAngleEligibilityIneligibleImplCopyWith<
          _$WideAngleEligibilityIneligibleImpl>
      get copyWith => throw _privateConstructorUsedError;
}
