// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'collector_authored.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$CollectorAuthored {
  String? get notes => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $CollectorAuthoredCopyWith<CollectorAuthored> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CollectorAuthoredCopyWith<$Res> {
  factory $CollectorAuthoredCopyWith(
    CollectorAuthored value,
    $Res Function(CollectorAuthored) then,
  ) = _$CollectorAuthoredCopyWithImpl<$Res, CollectorAuthored>;
  @useResult
  $Res call({String? notes, List<String> tags});
}

/// @nodoc
class _$CollectorAuthoredCopyWithImpl<$Res, $Val extends CollectorAuthored>
    implements $CollectorAuthoredCopyWith<$Res> {
  _$CollectorAuthoredCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? notes = freezed, Object? tags = null}) {
    return _then(
      _value.copyWith(
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CollectorAuthoredImplCopyWith<$Res>
    implements $CollectorAuthoredCopyWith<$Res> {
  factory _$$CollectorAuthoredImplCopyWith(
    _$CollectorAuthoredImpl value,
    $Res Function(_$CollectorAuthoredImpl) then,
  ) = __$$CollectorAuthoredImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? notes, List<String> tags});
}

/// @nodoc
class __$$CollectorAuthoredImplCopyWithImpl<$Res>
    extends _$CollectorAuthoredCopyWithImpl<$Res, _$CollectorAuthoredImpl>
    implements _$$CollectorAuthoredImplCopyWith<$Res> {
  __$$CollectorAuthoredImplCopyWithImpl(
    _$CollectorAuthoredImpl _value,
    $Res Function(_$CollectorAuthoredImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? notes = freezed, Object? tags = null}) {
    return _then(
      _$CollectorAuthoredImpl(
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$CollectorAuthoredImpl implements _CollectorAuthored {
  const _$CollectorAuthoredImpl({
    this.notes,
    final List<String> tags = const <String>[],
  }) : _tags = tags;

  @override
  final String? notes;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  String toString() {
    return 'CollectorAuthored(notes: $notes, tags: $tags)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CollectorAuthoredImpl &&
            (identical(other.notes, notes) || other.notes == notes) &&
            const DeepCollectionEquality().equals(other._tags, _tags));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    notes,
    const DeepCollectionEquality().hash(_tags),
  );

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CollectorAuthoredImplCopyWith<_$CollectorAuthoredImpl> get copyWith =>
      __$$CollectorAuthoredImplCopyWithImpl<_$CollectorAuthoredImpl>(
        this,
        _$identity,
      );
}

abstract class _CollectorAuthored implements CollectorAuthored {
  const factory _CollectorAuthored({
    final String? notes,
    final List<String> tags,
  }) = _$CollectorAuthoredImpl;

  @override
  String? get notes;
  @override
  List<String> get tags;
  @override
  @JsonKey(ignore: true)
  _$$CollectorAuthoredImplCopyWith<_$CollectorAuthoredImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
