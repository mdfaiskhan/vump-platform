// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Session {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() unknown,
    required TResult Function() unauthenticated,
    required TResult Function(User user) authenticated,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? unknown,
    TResult? Function()? unauthenticated,
    TResult? Function(User user)? authenticated,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? unknown,
    TResult Function()? unauthenticated,
    TResult Function(User user)? authenticated,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SessionUnknown value) unknown,
    required TResult Function(SessionUnauthenticated value) unauthenticated,
    required TResult Function(SessionAuthenticated value) authenticated,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SessionUnknown value)? unknown,
    TResult? Function(SessionUnauthenticated value)? unauthenticated,
    TResult? Function(SessionAuthenticated value)? authenticated,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SessionUnknown value)? unknown,
    TResult Function(SessionUnauthenticated value)? unauthenticated,
    TResult Function(SessionAuthenticated value)? authenticated,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionCopyWith<$Res> {
  factory $SessionCopyWith(Session value, $Res Function(Session) then) =
      _$SessionCopyWithImpl<$Res, Session>;
}

/// @nodoc
class _$SessionCopyWithImpl<$Res, $Val extends Session>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$SessionUnknownImplCopyWith<$Res> {
  factory _$$SessionUnknownImplCopyWith(
    _$SessionUnknownImpl value,
    $Res Function(_$SessionUnknownImpl) then,
  ) = __$$SessionUnknownImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$SessionUnknownImplCopyWithImpl<$Res>
    extends _$SessionCopyWithImpl<$Res, _$SessionUnknownImpl>
    implements _$$SessionUnknownImplCopyWith<$Res> {
  __$$SessionUnknownImplCopyWithImpl(
    _$SessionUnknownImpl _value,
    $Res Function(_$SessionUnknownImpl) _then,
  ) : super(_value, _then);
}

/// @nodoc

class _$SessionUnknownImpl implements SessionUnknown {
  const _$SessionUnknownImpl();

  @override
  String toString() {
    return 'Session.unknown()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$SessionUnknownImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() unknown,
    required TResult Function() unauthenticated,
    required TResult Function(User user) authenticated,
  }) {
    return unknown();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? unknown,
    TResult? Function()? unauthenticated,
    TResult? Function(User user)? authenticated,
  }) {
    return unknown?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? unknown,
    TResult Function()? unauthenticated,
    TResult Function(User user)? authenticated,
    required TResult orElse(),
  }) {
    if (unknown != null) {
      return unknown();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SessionUnknown value) unknown,
    required TResult Function(SessionUnauthenticated value) unauthenticated,
    required TResult Function(SessionAuthenticated value) authenticated,
  }) {
    return unknown(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SessionUnknown value)? unknown,
    TResult? Function(SessionUnauthenticated value)? unauthenticated,
    TResult? Function(SessionAuthenticated value)? authenticated,
  }) {
    return unknown?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SessionUnknown value)? unknown,
    TResult Function(SessionUnauthenticated value)? unauthenticated,
    TResult Function(SessionAuthenticated value)? authenticated,
    required TResult orElse(),
  }) {
    if (unknown != null) {
      return unknown(this);
    }
    return orElse();
  }
}

abstract class SessionUnknown implements Session {
  const factory SessionUnknown() = _$SessionUnknownImpl;
}

/// @nodoc
abstract class _$$SessionUnauthenticatedImplCopyWith<$Res> {
  factory _$$SessionUnauthenticatedImplCopyWith(
    _$SessionUnauthenticatedImpl value,
    $Res Function(_$SessionUnauthenticatedImpl) then,
  ) = __$$SessionUnauthenticatedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$SessionUnauthenticatedImplCopyWithImpl<$Res>
    extends _$SessionCopyWithImpl<$Res, _$SessionUnauthenticatedImpl>
    implements _$$SessionUnauthenticatedImplCopyWith<$Res> {
  __$$SessionUnauthenticatedImplCopyWithImpl(
    _$SessionUnauthenticatedImpl _value,
    $Res Function(_$SessionUnauthenticatedImpl) _then,
  ) : super(_value, _then);
}

/// @nodoc

class _$SessionUnauthenticatedImpl implements SessionUnauthenticated {
  const _$SessionUnauthenticatedImpl();

  @override
  String toString() {
    return 'Session.unauthenticated()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionUnauthenticatedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() unknown,
    required TResult Function() unauthenticated,
    required TResult Function(User user) authenticated,
  }) {
    return unauthenticated();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? unknown,
    TResult? Function()? unauthenticated,
    TResult? Function(User user)? authenticated,
  }) {
    return unauthenticated?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? unknown,
    TResult Function()? unauthenticated,
    TResult Function(User user)? authenticated,
    required TResult orElse(),
  }) {
    if (unauthenticated != null) {
      return unauthenticated();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SessionUnknown value) unknown,
    required TResult Function(SessionUnauthenticated value) unauthenticated,
    required TResult Function(SessionAuthenticated value) authenticated,
  }) {
    return unauthenticated(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SessionUnknown value)? unknown,
    TResult? Function(SessionUnauthenticated value)? unauthenticated,
    TResult? Function(SessionAuthenticated value)? authenticated,
  }) {
    return unauthenticated?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SessionUnknown value)? unknown,
    TResult Function(SessionUnauthenticated value)? unauthenticated,
    TResult Function(SessionAuthenticated value)? authenticated,
    required TResult orElse(),
  }) {
    if (unauthenticated != null) {
      return unauthenticated(this);
    }
    return orElse();
  }
}

abstract class SessionUnauthenticated implements Session {
  const factory SessionUnauthenticated() = _$SessionUnauthenticatedImpl;
}

/// @nodoc
abstract class _$$SessionAuthenticatedImplCopyWith<$Res> {
  factory _$$SessionAuthenticatedImplCopyWith(
    _$SessionAuthenticatedImpl value,
    $Res Function(_$SessionAuthenticatedImpl) then,
  ) = __$$SessionAuthenticatedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({User user});

  $UserCopyWith<$Res> get user;
}

/// @nodoc
class __$$SessionAuthenticatedImplCopyWithImpl<$Res>
    extends _$SessionCopyWithImpl<$Res, _$SessionAuthenticatedImpl>
    implements _$$SessionAuthenticatedImplCopyWith<$Res> {
  __$$SessionAuthenticatedImplCopyWithImpl(
    _$SessionAuthenticatedImpl _value,
    $Res Function(_$SessionAuthenticatedImpl) _then,
  ) : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? user = null}) {
    return _then(
      _$SessionAuthenticatedImpl(
        null == user
            ? _value.user
            : user // ignore: cast_nullable_to_non_nullable
                  as User,
      ),
    );
  }

  @override
  @pragma('vm:prefer-inline')
  $UserCopyWith<$Res> get user {
    return $UserCopyWith<$Res>(_value.user, (value) {
      return _then(_value.copyWith(user: value));
    });
  }
}

/// @nodoc

class _$SessionAuthenticatedImpl implements SessionAuthenticated {
  const _$SessionAuthenticatedImpl(this.user);

  @override
  final User user;

  @override
  String toString() {
    return 'Session.authenticated(user: $user)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionAuthenticatedImpl &&
            (identical(other.user, user) || other.user == user));
  }

  @override
  int get hashCode => Object.hash(runtimeType, user);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionAuthenticatedImplCopyWith<_$SessionAuthenticatedImpl>
  get copyWith =>
      __$$SessionAuthenticatedImplCopyWithImpl<_$SessionAuthenticatedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() unknown,
    required TResult Function() unauthenticated,
    required TResult Function(User user) authenticated,
  }) {
    return authenticated(user);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? unknown,
    TResult? Function()? unauthenticated,
    TResult? Function(User user)? authenticated,
  }) {
    return authenticated?.call(user);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? unknown,
    TResult Function()? unauthenticated,
    TResult Function(User user)? authenticated,
    required TResult orElse(),
  }) {
    if (authenticated != null) {
      return authenticated(user);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SessionUnknown value) unknown,
    required TResult Function(SessionUnauthenticated value) unauthenticated,
    required TResult Function(SessionAuthenticated value) authenticated,
  }) {
    return authenticated(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SessionUnknown value)? unknown,
    TResult? Function(SessionUnauthenticated value)? unauthenticated,
    TResult? Function(SessionAuthenticated value)? authenticated,
  }) {
    return authenticated?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SessionUnknown value)? unknown,
    TResult Function(SessionUnauthenticated value)? unauthenticated,
    TResult Function(SessionAuthenticated value)? authenticated,
    required TResult orElse(),
  }) {
    if (authenticated != null) {
      return authenticated(this);
    }
    return orElse();
  }
}

abstract class SessionAuthenticated implements Session {
  const factory SessionAuthenticated(final User user) =
      _$SessionAuthenticatedImpl;

  User get user;
  @JsonKey(ignore: true)
  _$$SessionAuthenticatedImplCopyWith<_$SessionAuthenticatedImpl>
  get copyWith => throw _privateConstructorUsedError;
}
