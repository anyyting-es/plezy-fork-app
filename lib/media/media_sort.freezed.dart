// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_sort.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MediaSort {

 String get key; String? get descKey; String get title; String? get defaultDirection;
/// Create a copy of MediaSort
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaSortCopyWith<MediaSort> get copyWith => _$MediaSortCopyWithImpl<MediaSort>(this as MediaSort, _$identity);

  /// Serializes this MediaSort to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaSort&&(identical(other.key, key) || other.key == key)&&(identical(other.descKey, descKey) || other.descKey == descKey)&&(identical(other.title, title) || other.title == title)&&(identical(other.defaultDirection, defaultDirection) || other.defaultDirection == defaultDirection));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,descKey,title,defaultDirection);

@override
String toString() {
  return 'MediaSort(key: $key, descKey: $descKey, title: $title, defaultDirection: $defaultDirection)';
}


}

/// @nodoc
abstract mixin class $MediaSortCopyWith<$Res>  {
  factory $MediaSortCopyWith(MediaSort value, $Res Function(MediaSort) _then) = _$MediaSortCopyWithImpl;
@useResult
$Res call({
 String key, String? descKey, String title, String? defaultDirection
});




}
/// @nodoc
class _$MediaSortCopyWithImpl<$Res>
    implements $MediaSortCopyWith<$Res> {
  _$MediaSortCopyWithImpl(this._self, this._then);

  final MediaSort _self;
  final $Res Function(MediaSort) _then;

/// Create a copy of MediaSort
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? descKey = freezed,Object? title = null,Object? defaultDirection = freezed,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,descKey: freezed == descKey ? _self.descKey : descKey // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,defaultDirection: freezed == defaultDirection ? _self.defaultDirection : defaultDirection // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaSort].
extension MediaSortPatterns on MediaSort {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaSort value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaSort() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaSort value)  $default,){
final _that = this;
switch (_that) {
case _MediaSort():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaSort value)?  $default,){
final _that = this;
switch (_that) {
case _MediaSort() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String? descKey,  String title,  String? defaultDirection)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaSort() when $default != null:
return $default(_that.key,_that.descKey,_that.title,_that.defaultDirection);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String? descKey,  String title,  String? defaultDirection)  $default,) {final _that = this;
switch (_that) {
case _MediaSort():
return $default(_that.key,_that.descKey,_that.title,_that.defaultDirection);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String? descKey,  String title,  String? defaultDirection)?  $default,) {final _that = this;
switch (_that) {
case _MediaSort() when $default != null:
return $default(_that.key,_that.descKey,_that.title,_that.defaultDirection);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MediaSort extends MediaSort {
  const _MediaSort({required this.key, this.descKey, required this.title, this.defaultDirection}): super._();
  factory _MediaSort.fromJson(Map<String, dynamic> json) => _$MediaSortFromJson(json);

@override final  String key;
@override final  String? descKey;
@override final  String title;
@override final  String? defaultDirection;

/// Create a copy of MediaSort
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaSortCopyWith<_MediaSort> get copyWith => __$MediaSortCopyWithImpl<_MediaSort>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MediaSortToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaSort&&(identical(other.key, key) || other.key == key)&&(identical(other.descKey, descKey) || other.descKey == descKey)&&(identical(other.title, title) || other.title == title)&&(identical(other.defaultDirection, defaultDirection) || other.defaultDirection == defaultDirection));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,descKey,title,defaultDirection);

@override
String toString() {
  return 'MediaSort(key: $key, descKey: $descKey, title: $title, defaultDirection: $defaultDirection)';
}


}

/// @nodoc
abstract mixin class _$MediaSortCopyWith<$Res> implements $MediaSortCopyWith<$Res> {
  factory _$MediaSortCopyWith(_MediaSort value, $Res Function(_MediaSort) _then) = __$MediaSortCopyWithImpl;
@override @useResult
$Res call({
 String key, String? descKey, String title, String? defaultDirection
});




}
/// @nodoc
class __$MediaSortCopyWithImpl<$Res>
    implements _$MediaSortCopyWith<$Res> {
  __$MediaSortCopyWithImpl(this._self, this._then);

  final _MediaSort _self;
  final $Res Function(_MediaSort) _then;

/// Create a copy of MediaSort
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? descKey = freezed,Object? title = null,Object? defaultDirection = freezed,}) {
  return _then(_MediaSort(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,descKey: freezed == descKey ? _self.descKey : descKey // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,defaultDirection: freezed == defaultDirection ? _self.defaultDirection : defaultDirection // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
