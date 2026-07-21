// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'remote_command.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RemoteCommand {

@JsonKey(name: 't')@_RemoteCommandTypeConverter() RemoteCommandType get type;@JsonKey(name: 'd') Map<String, dynamic>? get data;
/// Create a copy of RemoteCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteCommandCopyWith<RemoteCommand> get copyWith => _$RemoteCommandCopyWithImpl<RemoteCommand>(this as RemoteCommand, _$identity);

  /// Serializes this RemoteCommand to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteCommand&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'RemoteCommand(type: $type, data: $data)';
}


}

/// @nodoc
abstract mixin class $RemoteCommandCopyWith<$Res>  {
  factory $RemoteCommandCopyWith(RemoteCommand value, $Res Function(RemoteCommand) _then) = _$RemoteCommandCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 't')@_RemoteCommandTypeConverter() RemoteCommandType type,@JsonKey(name: 'd') Map<String, dynamic>? data
});




}
/// @nodoc
class _$RemoteCommandCopyWithImpl<$Res>
    implements $RemoteCommandCopyWith<$Res> {
  _$RemoteCommandCopyWithImpl(this._self, this._then);

  final RemoteCommand _self;
  final $Res Function(RemoteCommand) _then;

/// Create a copy of RemoteCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? data = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RemoteCommandType,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [RemoteCommand].
extension RemoteCommandPatterns on RemoteCommand {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RemoteCommand value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RemoteCommand() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RemoteCommand value)  $default,){
final _that = this;
switch (_that) {
case _RemoteCommand():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RemoteCommand value)?  $default,){
final _that = this;
switch (_that) {
case _RemoteCommand() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 't')@_RemoteCommandTypeConverter()  RemoteCommandType type, @JsonKey(name: 'd')  Map<String, dynamic>? data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RemoteCommand() when $default != null:
return $default(_that.type,_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 't')@_RemoteCommandTypeConverter()  RemoteCommandType type, @JsonKey(name: 'd')  Map<String, dynamic>? data)  $default,) {final _that = this;
switch (_that) {
case _RemoteCommand():
return $default(_that.type,_that.data);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 't')@_RemoteCommandTypeConverter()  RemoteCommandType type, @JsonKey(name: 'd')  Map<String, dynamic>? data)?  $default,) {final _that = this;
switch (_that) {
case _RemoteCommand() when $default != null:
return $default(_that.type,_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RemoteCommand implements RemoteCommand {
  const _RemoteCommand({@JsonKey(name: 't')@_RemoteCommandTypeConverter() required this.type, @JsonKey(name: 'd') final  Map<String, dynamic>? data}): _data = data;
  factory _RemoteCommand.fromJson(Map<String, dynamic> json) => _$RemoteCommandFromJson(json);

@override@JsonKey(name: 't')@_RemoteCommandTypeConverter() final  RemoteCommandType type;
 final  Map<String, dynamic>? _data;
@override@JsonKey(name: 'd') Map<String, dynamic>? get data {
  final value = _data;
  if (value == null) return null;
  if (_data is EqualUnmodifiableMapView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of RemoteCommand
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RemoteCommandCopyWith<_RemoteCommand> get copyWith => __$RemoteCommandCopyWithImpl<_RemoteCommand>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RemoteCommandToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RemoteCommand&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'RemoteCommand(type: $type, data: $data)';
}


}

/// @nodoc
abstract mixin class _$RemoteCommandCopyWith<$Res> implements $RemoteCommandCopyWith<$Res> {
  factory _$RemoteCommandCopyWith(_RemoteCommand value, $Res Function(_RemoteCommand) _then) = __$RemoteCommandCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 't')@_RemoteCommandTypeConverter() RemoteCommandType type,@JsonKey(name: 'd') Map<String, dynamic>? data
});




}
/// @nodoc
class __$RemoteCommandCopyWithImpl<$Res>
    implements _$RemoteCommandCopyWith<$Res> {
  __$RemoteCommandCopyWithImpl(this._self, this._then);

  final _RemoteCommand _self;
  final $Res Function(_RemoteCommand) _then;

/// Create a copy of RemoteCommand
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? data = freezed,}) {
  return _then(_RemoteCommand(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RemoteCommandType,data: freezed == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}

// dart format on
