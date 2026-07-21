// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'remote_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RemoteDevice {

 String get id; String get name; String get platform; DateTime get connectedAt; Map<String, bool> get capabilities;
/// Create a copy of RemoteDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteDeviceCopyWith<RemoteDevice> get copyWith => _$RemoteDeviceCopyWithImpl<RemoteDevice>(this as RemoteDevice, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteDevice&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.connectedAt, connectedAt) || other.connectedAt == connectedAt)&&const DeepCollectionEquality().equals(other.capabilities, capabilities));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,platform,connectedAt,const DeepCollectionEquality().hash(capabilities));

@override
String toString() {
  return 'RemoteDevice(id: $id, name: $name, platform: $platform, connectedAt: $connectedAt, capabilities: $capabilities)';
}


}

/// @nodoc
abstract mixin class $RemoteDeviceCopyWith<$Res>  {
  factory $RemoteDeviceCopyWith(RemoteDevice value, $Res Function(RemoteDevice) _then) = _$RemoteDeviceCopyWithImpl;
@useResult
$Res call({
 String id, String name, String platform, DateTime connectedAt, Map<String, bool> capabilities
});




}
/// @nodoc
class _$RemoteDeviceCopyWithImpl<$Res>
    implements $RemoteDeviceCopyWith<$Res> {
  _$RemoteDeviceCopyWithImpl(this._self, this._then);

  final RemoteDevice _self;
  final $Res Function(RemoteDevice) _then;

/// Create a copy of RemoteDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? platform = null,Object? connectedAt = null,Object? capabilities = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,connectedAt: null == connectedAt ? _self.connectedAt : connectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,
  ));
}

}


/// Adds pattern-matching-related methods to [RemoteDevice].
extension RemoteDevicePatterns on RemoteDevice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RemoteDevice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RemoteDevice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RemoteDevice value)  $default,){
final _that = this;
switch (_that) {
case _RemoteDevice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RemoteDevice value)?  $default,){
final _that = this;
switch (_that) {
case _RemoteDevice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String platform,  DateTime connectedAt,  Map<String, bool> capabilities)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RemoteDevice() when $default != null:
return $default(_that.id,_that.name,_that.platform,_that.connectedAt,_that.capabilities);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String platform,  DateTime connectedAt,  Map<String, bool> capabilities)  $default,) {final _that = this;
switch (_that) {
case _RemoteDevice():
return $default(_that.id,_that.name,_that.platform,_that.connectedAt,_that.capabilities);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String platform,  DateTime connectedAt,  Map<String, bool> capabilities)?  $default,) {final _that = this;
switch (_that) {
case _RemoteDevice() when $default != null:
return $default(_that.id,_that.name,_that.platform,_that.connectedAt,_that.capabilities);case _:
  return null;

}
}

}

/// @nodoc


class _RemoteDevice implements RemoteDevice {
  const _RemoteDevice({required this.id, required this.name, required this.platform, required this.connectedAt, final  Map<String, bool> capabilities = const <String, bool>{}}): _capabilities = capabilities;
  

@override final  String id;
@override final  String name;
@override final  String platform;
@override final  DateTime connectedAt;
 final  Map<String, bool> _capabilities;
@override@JsonKey() Map<String, bool> get capabilities {
  if (_capabilities is EqualUnmodifiableMapView) return _capabilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_capabilities);
}


/// Create a copy of RemoteDevice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RemoteDeviceCopyWith<_RemoteDevice> get copyWith => __$RemoteDeviceCopyWithImpl<_RemoteDevice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RemoteDevice&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.connectedAt, connectedAt) || other.connectedAt == connectedAt)&&const DeepCollectionEquality().equals(other._capabilities, _capabilities));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,platform,connectedAt,const DeepCollectionEquality().hash(_capabilities));

@override
String toString() {
  return 'RemoteDevice(id: $id, name: $name, platform: $platform, connectedAt: $connectedAt, capabilities: $capabilities)';
}


}

/// @nodoc
abstract mixin class _$RemoteDeviceCopyWith<$Res> implements $RemoteDeviceCopyWith<$Res> {
  factory _$RemoteDeviceCopyWith(_RemoteDevice value, $Res Function(_RemoteDevice) _then) = __$RemoteDeviceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String platform, DateTime connectedAt, Map<String, bool> capabilities
});




}
/// @nodoc
class __$RemoteDeviceCopyWithImpl<$Res>
    implements _$RemoteDeviceCopyWith<$Res> {
  __$RemoteDeviceCopyWithImpl(this._self, this._then);

  final _RemoteDevice _self;
  final $Res Function(_RemoteDevice) _then;

/// Create a copy of RemoteDevice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? platform = null,Object? connectedAt = null,Object? capabilities = null,}) {
  return _then(_RemoteDevice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,connectedAt: null == connectedAt ? _self.connectedAt : connectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,capabilities: null == capabilities ? _self._capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,
  ));
}


}

/// @nodoc
mixin _$RemoteSession {

 RemoteSessionRole get role; RemoteSessionStatus get status; RemoteDevice? get connectedDevice; DateTime get createdAt; String? get errorMessage;
/// Create a copy of RemoteSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteSessionCopyWith<RemoteSession> get copyWith => _$RemoteSessionCopyWithImpl<RemoteSession>(this as RemoteSession, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteSession&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&(identical(other.connectedDevice, connectedDevice) || other.connectedDevice == connectedDevice)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,role,status,connectedDevice,createdAt,errorMessage);

@override
String toString() {
  return 'RemoteSession(role: $role, status: $status, connectedDevice: $connectedDevice, createdAt: $createdAt, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $RemoteSessionCopyWith<$Res>  {
  factory $RemoteSessionCopyWith(RemoteSession value, $Res Function(RemoteSession) _then) = _$RemoteSessionCopyWithImpl;
@useResult
$Res call({
 RemoteSessionRole role, RemoteSessionStatus status, RemoteDevice? connectedDevice, DateTime createdAt, String? errorMessage
});


$RemoteDeviceCopyWith<$Res>? get connectedDevice;

}
/// @nodoc
class _$RemoteSessionCopyWithImpl<$Res>
    implements $RemoteSessionCopyWith<$Res> {
  _$RemoteSessionCopyWithImpl(this._self, this._then);

  final RemoteSession _self;
  final $Res Function(RemoteSession) _then;

/// Create a copy of RemoteSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,Object? status = null,Object? connectedDevice = freezed,Object? createdAt = null,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as RemoteSessionRole,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RemoteSessionStatus,connectedDevice: freezed == connectedDevice ? _self.connectedDevice : connectedDevice // ignore: cast_nullable_to_non_nullable
as RemoteDevice?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of RemoteSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RemoteDeviceCopyWith<$Res>? get connectedDevice {
    if (_self.connectedDevice == null) {
    return null;
  }

  return $RemoteDeviceCopyWith<$Res>(_self.connectedDevice!, (value) {
    return _then(_self.copyWith(connectedDevice: value));
  });
}
}


/// Adds pattern-matching-related methods to [RemoteSession].
extension RemoteSessionPatterns on RemoteSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RemoteSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RemoteSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RemoteSession value)  $default,){
final _that = this;
switch (_that) {
case _RemoteSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RemoteSession value)?  $default,){
final _that = this;
switch (_that) {
case _RemoteSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RemoteSessionRole role,  RemoteSessionStatus status,  RemoteDevice? connectedDevice,  DateTime createdAt,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RemoteSession() when $default != null:
return $default(_that.role,_that.status,_that.connectedDevice,_that.createdAt,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RemoteSessionRole role,  RemoteSessionStatus status,  RemoteDevice? connectedDevice,  DateTime createdAt,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _RemoteSession():
return $default(_that.role,_that.status,_that.connectedDevice,_that.createdAt,_that.errorMessage);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RemoteSessionRole role,  RemoteSessionStatus status,  RemoteDevice? connectedDevice,  DateTime createdAt,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _RemoteSession() when $default != null:
return $default(_that.role,_that.status,_that.connectedDevice,_that.createdAt,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _RemoteSession extends RemoteSession {
  const _RemoteSession({required this.role, this.status = RemoteSessionStatus.disconnected, this.connectedDevice, required this.createdAt, this.errorMessage}): super._();
  

@override final  RemoteSessionRole role;
@override@JsonKey() final  RemoteSessionStatus status;
@override final  RemoteDevice? connectedDevice;
@override final  DateTime createdAt;
@override final  String? errorMessage;

/// Create a copy of RemoteSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RemoteSessionCopyWith<_RemoteSession> get copyWith => __$RemoteSessionCopyWithImpl<_RemoteSession>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RemoteSession&&(identical(other.role, role) || other.role == role)&&(identical(other.status, status) || other.status == status)&&(identical(other.connectedDevice, connectedDevice) || other.connectedDevice == connectedDevice)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,role,status,connectedDevice,createdAt,errorMessage);

@override
String toString() {
  return 'RemoteSession(role: $role, status: $status, connectedDevice: $connectedDevice, createdAt: $createdAt, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$RemoteSessionCopyWith<$Res> implements $RemoteSessionCopyWith<$Res> {
  factory _$RemoteSessionCopyWith(_RemoteSession value, $Res Function(_RemoteSession) _then) = __$RemoteSessionCopyWithImpl;
@override @useResult
$Res call({
 RemoteSessionRole role, RemoteSessionStatus status, RemoteDevice? connectedDevice, DateTime createdAt, String? errorMessage
});


@override $RemoteDeviceCopyWith<$Res>? get connectedDevice;

}
/// @nodoc
class __$RemoteSessionCopyWithImpl<$Res>
    implements _$RemoteSessionCopyWith<$Res> {
  __$RemoteSessionCopyWithImpl(this._self, this._then);

  final _RemoteSession _self;
  final $Res Function(_RemoteSession) _then;

/// Create a copy of RemoteSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,Object? status = null,Object? connectedDevice = freezed,Object? createdAt = null,Object? errorMessage = freezed,}) {
  return _then(_RemoteSession(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as RemoteSessionRole,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RemoteSessionStatus,connectedDevice: freezed == connectedDevice ? _self.connectedDevice : connectedDevice // ignore: cast_nullable_to_non_nullable
as RemoteDevice?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of RemoteSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RemoteDeviceCopyWith<$Res>? get connectedDevice {
    if (_self.connectedDevice == null) {
    return null;
  }

  return $RemoteDeviceCopyWith<$Res>(_self.connectedDevice!, (value) {
    return _then(_self.copyWith(connectedDevice: value));
  });
}
}

// dart format on
