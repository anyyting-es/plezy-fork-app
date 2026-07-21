// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_connection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProfileConnection {

 String get profileId; String get connectionId; String? get userToken; String get userIdentifier; bool get isDefault; DateTime? get tokenAcquiredAt; DateTime? get lastUsedAt;
/// Create a copy of ProfileConnection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileConnectionCopyWith<ProfileConnection> get copyWith => _$ProfileConnectionCopyWithImpl<ProfileConnection>(this as ProfileConnection, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileConnection&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.userToken, userToken) || other.userToken == userToken)&&(identical(other.userIdentifier, userIdentifier) || other.userIdentifier == userIdentifier)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.tokenAcquiredAt, tokenAcquiredAt) || other.tokenAcquiredAt == tokenAcquiredAt)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt));
}


@override
int get hashCode => Object.hash(runtimeType,profileId,connectionId,userToken,userIdentifier,isDefault,tokenAcquiredAt,lastUsedAt);

@override
String toString() {
  return 'ProfileConnection(profileId: $profileId, connectionId: $connectionId, userToken: $userToken, userIdentifier: $userIdentifier, isDefault: $isDefault, tokenAcquiredAt: $tokenAcquiredAt, lastUsedAt: $lastUsedAt)';
}


}

/// @nodoc
abstract mixin class $ProfileConnectionCopyWith<$Res>  {
  factory $ProfileConnectionCopyWith(ProfileConnection value, $Res Function(ProfileConnection) _then) = _$ProfileConnectionCopyWithImpl;
@useResult
$Res call({
 String profileId, String connectionId, String? userToken, String userIdentifier, bool isDefault, DateTime? tokenAcquiredAt, DateTime? lastUsedAt
});




}
/// @nodoc
class _$ProfileConnectionCopyWithImpl<$Res>
    implements $ProfileConnectionCopyWith<$Res> {
  _$ProfileConnectionCopyWithImpl(this._self, this._then);

  final ProfileConnection _self;
  final $Res Function(ProfileConnection) _then;

/// Create a copy of ProfileConnection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = null,Object? connectionId = null,Object? userToken = freezed,Object? userIdentifier = null,Object? isDefault = null,Object? tokenAcquiredAt = freezed,Object? lastUsedAt = freezed,}) {
  return _then(_self.copyWith(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String,connectionId: null == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String,userToken: freezed == userToken ? _self.userToken : userToken // ignore: cast_nullable_to_non_nullable
as String?,userIdentifier: null == userIdentifier ? _self.userIdentifier : userIdentifier // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,tokenAcquiredAt: freezed == tokenAcquiredAt ? _self.tokenAcquiredAt : tokenAcquiredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileConnection].
extension ProfileConnectionPatterns on ProfileConnection {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileConnection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileConnection() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileConnection value)  $default,){
final _that = this;
switch (_that) {
case _ProfileConnection():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileConnection value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileConnection() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String profileId,  String connectionId,  String? userToken,  String userIdentifier,  bool isDefault,  DateTime? tokenAcquiredAt,  DateTime? lastUsedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileConnection() when $default != null:
return $default(_that.profileId,_that.connectionId,_that.userToken,_that.userIdentifier,_that.isDefault,_that.tokenAcquiredAt,_that.lastUsedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String profileId,  String connectionId,  String? userToken,  String userIdentifier,  bool isDefault,  DateTime? tokenAcquiredAt,  DateTime? lastUsedAt)  $default,) {final _that = this;
switch (_that) {
case _ProfileConnection():
return $default(_that.profileId,_that.connectionId,_that.userToken,_that.userIdentifier,_that.isDefault,_that.tokenAcquiredAt,_that.lastUsedAt);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String profileId,  String connectionId,  String? userToken,  String userIdentifier,  bool isDefault,  DateTime? tokenAcquiredAt,  DateTime? lastUsedAt)?  $default,) {final _that = this;
switch (_that) {
case _ProfileConnection() when $default != null:
return $default(_that.profileId,_that.connectionId,_that.userToken,_that.userIdentifier,_that.isDefault,_that.tokenAcquiredAt,_that.lastUsedAt);case _:
  return null;

}
}

}

/// @nodoc


class _ProfileConnection extends ProfileConnection {
  const _ProfileConnection({required this.profileId, required this.connectionId, this.userToken, required this.userIdentifier, this.isDefault = false, this.tokenAcquiredAt, this.lastUsedAt}): super._();
  

@override final  String profileId;
@override final  String connectionId;
@override final  String? userToken;
@override final  String userIdentifier;
@override@JsonKey() final  bool isDefault;
@override final  DateTime? tokenAcquiredAt;
@override final  DateTime? lastUsedAt;

/// Create a copy of ProfileConnection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileConnectionCopyWith<_ProfileConnection> get copyWith => __$ProfileConnectionCopyWithImpl<_ProfileConnection>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileConnection&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.connectionId, connectionId) || other.connectionId == connectionId)&&(identical(other.userToken, userToken) || other.userToken == userToken)&&(identical(other.userIdentifier, userIdentifier) || other.userIdentifier == userIdentifier)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.tokenAcquiredAt, tokenAcquiredAt) || other.tokenAcquiredAt == tokenAcquiredAt)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt));
}


@override
int get hashCode => Object.hash(runtimeType,profileId,connectionId,userToken,userIdentifier,isDefault,tokenAcquiredAt,lastUsedAt);

@override
String toString() {
  return 'ProfileConnection(profileId: $profileId, connectionId: $connectionId, userToken: $userToken, userIdentifier: $userIdentifier, isDefault: $isDefault, tokenAcquiredAt: $tokenAcquiredAt, lastUsedAt: $lastUsedAt)';
}


}

/// @nodoc
abstract mixin class _$ProfileConnectionCopyWith<$Res> implements $ProfileConnectionCopyWith<$Res> {
  factory _$ProfileConnectionCopyWith(_ProfileConnection value, $Res Function(_ProfileConnection) _then) = __$ProfileConnectionCopyWithImpl;
@override @useResult
$Res call({
 String profileId, String connectionId, String? userToken, String userIdentifier, bool isDefault, DateTime? tokenAcquiredAt, DateTime? lastUsedAt
});




}
/// @nodoc
class __$ProfileConnectionCopyWithImpl<$Res>
    implements _$ProfileConnectionCopyWith<$Res> {
  __$ProfileConnectionCopyWithImpl(this._self, this._then);

  final _ProfileConnection _self;
  final $Res Function(_ProfileConnection) _then;

/// Create a copy of ProfileConnection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,Object? connectionId = null,Object? userToken = freezed,Object? userIdentifier = null,Object? isDefault = null,Object? tokenAcquiredAt = freezed,Object? lastUsedAt = freezed,}) {
  return _then(_ProfileConnection(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String,connectionId: null == connectionId ? _self.connectionId : connectionId // ignore: cast_nullable_to_non_nullable
as String,userToken: freezed == userToken ? _self.userToken : userToken // ignore: cast_nullable_to_non_nullable
as String?,userIdentifier: null == userIdentifier ? _self.userIdentifier : userIdentifier // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,tokenAcquiredAt: freezed == tokenAcquiredAt ? _self.tokenAcquiredAt : tokenAcquiredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
