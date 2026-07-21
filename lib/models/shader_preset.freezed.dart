// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shader_preset.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Anime4KConfig {

@JsonKey(unknownEnumValue: Anime4KQuality.fast) Anime4KQuality get quality;@JsonKey(unknownEnumValue: Anime4KMode.modeA) Anime4KMode get mode;
/// Create a copy of Anime4KConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Anime4KConfigCopyWith<Anime4KConfig> get copyWith => _$Anime4KConfigCopyWithImpl<Anime4KConfig>(this as Anime4KConfig, _$identity);

  /// Serializes this Anime4KConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Anime4KConfig&&(identical(other.quality, quality) || other.quality == quality)&&(identical(other.mode, mode) || other.mode == mode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,quality,mode);

@override
String toString() {
  return 'Anime4KConfig(quality: $quality, mode: $mode)';
}


}

/// @nodoc
abstract mixin class $Anime4KConfigCopyWith<$Res>  {
  factory $Anime4KConfigCopyWith(Anime4KConfig value, $Res Function(Anime4KConfig) _then) = _$Anime4KConfigCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: Anime4KQuality.fast) Anime4KQuality quality,@JsonKey(unknownEnumValue: Anime4KMode.modeA) Anime4KMode mode
});




}
/// @nodoc
class _$Anime4KConfigCopyWithImpl<$Res>
    implements $Anime4KConfigCopyWith<$Res> {
  _$Anime4KConfigCopyWithImpl(this._self, this._then);

  final Anime4KConfig _self;
  final $Res Function(Anime4KConfig) _then;

/// Create a copy of Anime4KConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? quality = null,Object? mode = null,}) {
  return _then(_self.copyWith(
quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as Anime4KQuality,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as Anime4KMode,
  ));
}

}


/// Adds pattern-matching-related methods to [Anime4KConfig].
extension Anime4KConfigPatterns on Anime4KConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Anime4KConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Anime4KConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Anime4KConfig value)  $default,){
final _that = this;
switch (_that) {
case _Anime4KConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Anime4KConfig value)?  $default,){
final _that = this;
switch (_that) {
case _Anime4KConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: Anime4KQuality.fast)  Anime4KQuality quality, @JsonKey(unknownEnumValue: Anime4KMode.modeA)  Anime4KMode mode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Anime4KConfig() when $default != null:
return $default(_that.quality,_that.mode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: Anime4KQuality.fast)  Anime4KQuality quality, @JsonKey(unknownEnumValue: Anime4KMode.modeA)  Anime4KMode mode)  $default,) {final _that = this;
switch (_that) {
case _Anime4KConfig():
return $default(_that.quality,_that.mode);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(unknownEnumValue: Anime4KQuality.fast)  Anime4KQuality quality, @JsonKey(unknownEnumValue: Anime4KMode.modeA)  Anime4KMode mode)?  $default,) {final _that = this;
switch (_that) {
case _Anime4KConfig() when $default != null:
return $default(_that.quality,_that.mode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Anime4KConfig implements Anime4KConfig {
  const _Anime4KConfig({@JsonKey(unknownEnumValue: Anime4KQuality.fast) required this.quality, @JsonKey(unknownEnumValue: Anime4KMode.modeA) required this.mode});
  factory _Anime4KConfig.fromJson(Map<String, dynamic> json) => _$Anime4KConfigFromJson(json);

@override@JsonKey(unknownEnumValue: Anime4KQuality.fast) final  Anime4KQuality quality;
@override@JsonKey(unknownEnumValue: Anime4KMode.modeA) final  Anime4KMode mode;

/// Create a copy of Anime4KConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$Anime4KConfigCopyWith<_Anime4KConfig> get copyWith => __$Anime4KConfigCopyWithImpl<_Anime4KConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$Anime4KConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Anime4KConfig&&(identical(other.quality, quality) || other.quality == quality)&&(identical(other.mode, mode) || other.mode == mode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,quality,mode);

@override
String toString() {
  return 'Anime4KConfig(quality: $quality, mode: $mode)';
}


}

/// @nodoc
abstract mixin class _$Anime4KConfigCopyWith<$Res> implements $Anime4KConfigCopyWith<$Res> {
  factory _$Anime4KConfigCopyWith(_Anime4KConfig value, $Res Function(_Anime4KConfig) _then) = __$Anime4KConfigCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: Anime4KQuality.fast) Anime4KQuality quality,@JsonKey(unknownEnumValue: Anime4KMode.modeA) Anime4KMode mode
});




}
/// @nodoc
class __$Anime4KConfigCopyWithImpl<$Res>
    implements _$Anime4KConfigCopyWith<$Res> {
  __$Anime4KConfigCopyWithImpl(this._self, this._then);

  final _Anime4KConfig _self;
  final $Res Function(_Anime4KConfig) _then;

/// Create a copy of Anime4KConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? quality = null,Object? mode = null,}) {
  return _then(_Anime4KConfig(
quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as Anime4KQuality,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as Anime4KMode,
  ));
}


}


/// @nodoc
mixin _$ArtCNNConfig {

@JsonKey(unknownEnumValue: ArtCNNModel.c4f16) ArtCNNModel get model;@JsonKey(unknownEnumValue: ArtCNNVariant.neutral) ArtCNNVariant get variant;
/// Create a copy of ArtCNNConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArtCNNConfigCopyWith<ArtCNNConfig> get copyWith => _$ArtCNNConfigCopyWithImpl<ArtCNNConfig>(this as ArtCNNConfig, _$identity);

  /// Serializes this ArtCNNConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ArtCNNConfig&&(identical(other.model, model) || other.model == model)&&(identical(other.variant, variant) || other.variant == variant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model,variant);

@override
String toString() {
  return 'ArtCNNConfig(model: $model, variant: $variant)';
}


}

/// @nodoc
abstract mixin class $ArtCNNConfigCopyWith<$Res>  {
  factory $ArtCNNConfigCopyWith(ArtCNNConfig value, $Res Function(ArtCNNConfig) _then) = _$ArtCNNConfigCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: ArtCNNModel.c4f16) ArtCNNModel model,@JsonKey(unknownEnumValue: ArtCNNVariant.neutral) ArtCNNVariant variant
});




}
/// @nodoc
class _$ArtCNNConfigCopyWithImpl<$Res>
    implements $ArtCNNConfigCopyWith<$Res> {
  _$ArtCNNConfigCopyWithImpl(this._self, this._then);

  final ArtCNNConfig _self;
  final $Res Function(ArtCNNConfig) _then;

/// Create a copy of ArtCNNConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = null,Object? variant = null,}) {
  return _then(_self.copyWith(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as ArtCNNModel,variant: null == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as ArtCNNVariant,
  ));
}

}


/// Adds pattern-matching-related methods to [ArtCNNConfig].
extension ArtCNNConfigPatterns on ArtCNNConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ArtCNNConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ArtCNNConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ArtCNNConfig value)  $default,){
final _that = this;
switch (_that) {
case _ArtCNNConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ArtCNNConfig value)?  $default,){
final _that = this;
switch (_that) {
case _ArtCNNConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: ArtCNNModel.c4f16)  ArtCNNModel model, @JsonKey(unknownEnumValue: ArtCNNVariant.neutral)  ArtCNNVariant variant)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ArtCNNConfig() when $default != null:
return $default(_that.model,_that.variant);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: ArtCNNModel.c4f16)  ArtCNNModel model, @JsonKey(unknownEnumValue: ArtCNNVariant.neutral)  ArtCNNVariant variant)  $default,) {final _that = this;
switch (_that) {
case _ArtCNNConfig():
return $default(_that.model,_that.variant);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(unknownEnumValue: ArtCNNModel.c4f16)  ArtCNNModel model, @JsonKey(unknownEnumValue: ArtCNNVariant.neutral)  ArtCNNVariant variant)?  $default,) {final _that = this;
switch (_that) {
case _ArtCNNConfig() when $default != null:
return $default(_that.model,_that.variant);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ArtCNNConfig implements ArtCNNConfig {
  const _ArtCNNConfig({@JsonKey(unknownEnumValue: ArtCNNModel.c4f16) required this.model, @JsonKey(unknownEnumValue: ArtCNNVariant.neutral) required this.variant});
  factory _ArtCNNConfig.fromJson(Map<String, dynamic> json) => _$ArtCNNConfigFromJson(json);

@override@JsonKey(unknownEnumValue: ArtCNNModel.c4f16) final  ArtCNNModel model;
@override@JsonKey(unknownEnumValue: ArtCNNVariant.neutral) final  ArtCNNVariant variant;

/// Create a copy of ArtCNNConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArtCNNConfigCopyWith<_ArtCNNConfig> get copyWith => __$ArtCNNConfigCopyWithImpl<_ArtCNNConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArtCNNConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ArtCNNConfig&&(identical(other.model, model) || other.model == model)&&(identical(other.variant, variant) || other.variant == variant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model,variant);

@override
String toString() {
  return 'ArtCNNConfig(model: $model, variant: $variant)';
}


}

/// @nodoc
abstract mixin class _$ArtCNNConfigCopyWith<$Res> implements $ArtCNNConfigCopyWith<$Res> {
  factory _$ArtCNNConfigCopyWith(_ArtCNNConfig value, $Res Function(_ArtCNNConfig) _then) = __$ArtCNNConfigCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: ArtCNNModel.c4f16) ArtCNNModel model,@JsonKey(unknownEnumValue: ArtCNNVariant.neutral) ArtCNNVariant variant
});




}
/// @nodoc
class __$ArtCNNConfigCopyWithImpl<$Res>
    implements _$ArtCNNConfigCopyWith<$Res> {
  __$ArtCNNConfigCopyWithImpl(this._self, this._then);

  final _ArtCNNConfig _self;
  final $Res Function(_ArtCNNConfig) _then;

/// Create a copy of ArtCNNConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = null,Object? variant = null,}) {
  return _then(_ArtCNNConfig(
model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as ArtCNNModel,variant: null == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as ArtCNNVariant,
  ));
}


}


/// @nodoc
mixin _$NVScalerConfig {

/// Whether to automatically skip NVScaler on HDR content
 bool get autoHdrSkip;
/// Create a copy of NVScalerConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NVScalerConfigCopyWith<NVScalerConfig> get copyWith => _$NVScalerConfigCopyWithImpl<NVScalerConfig>(this as NVScalerConfig, _$identity);

  /// Serializes this NVScalerConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NVScalerConfig&&(identical(other.autoHdrSkip, autoHdrSkip) || other.autoHdrSkip == autoHdrSkip));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,autoHdrSkip);

@override
String toString() {
  return 'NVScalerConfig(autoHdrSkip: $autoHdrSkip)';
}


}

/// @nodoc
abstract mixin class $NVScalerConfigCopyWith<$Res>  {
  factory $NVScalerConfigCopyWith(NVScalerConfig value, $Res Function(NVScalerConfig) _then) = _$NVScalerConfigCopyWithImpl;
@useResult
$Res call({
 bool autoHdrSkip
});




}
/// @nodoc
class _$NVScalerConfigCopyWithImpl<$Res>
    implements $NVScalerConfigCopyWith<$Res> {
  _$NVScalerConfigCopyWithImpl(this._self, this._then);

  final NVScalerConfig _self;
  final $Res Function(NVScalerConfig) _then;

/// Create a copy of NVScalerConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? autoHdrSkip = null,}) {
  return _then(_self.copyWith(
autoHdrSkip: null == autoHdrSkip ? _self.autoHdrSkip : autoHdrSkip // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NVScalerConfig].
extension NVScalerConfigPatterns on NVScalerConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NVScalerConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NVScalerConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NVScalerConfig value)  $default,){
final _that = this;
switch (_that) {
case _NVScalerConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NVScalerConfig value)?  $default,){
final _that = this;
switch (_that) {
case _NVScalerConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool autoHdrSkip)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NVScalerConfig() when $default != null:
return $default(_that.autoHdrSkip);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool autoHdrSkip)  $default,) {final _that = this;
switch (_that) {
case _NVScalerConfig():
return $default(_that.autoHdrSkip);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool autoHdrSkip)?  $default,) {final _that = this;
switch (_that) {
case _NVScalerConfig() when $default != null:
return $default(_that.autoHdrSkip);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NVScalerConfig implements NVScalerConfig {
  const _NVScalerConfig({this.autoHdrSkip = true});
  factory _NVScalerConfig.fromJson(Map<String, dynamic> json) => _$NVScalerConfigFromJson(json);

/// Whether to automatically skip NVScaler on HDR content
@override@JsonKey() final  bool autoHdrSkip;

/// Create a copy of NVScalerConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NVScalerConfigCopyWith<_NVScalerConfig> get copyWith => __$NVScalerConfigCopyWithImpl<_NVScalerConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NVScalerConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NVScalerConfig&&(identical(other.autoHdrSkip, autoHdrSkip) || other.autoHdrSkip == autoHdrSkip));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,autoHdrSkip);

@override
String toString() {
  return 'NVScalerConfig(autoHdrSkip: $autoHdrSkip)';
}


}

/// @nodoc
abstract mixin class _$NVScalerConfigCopyWith<$Res> implements $NVScalerConfigCopyWith<$Res> {
  factory _$NVScalerConfigCopyWith(_NVScalerConfig value, $Res Function(_NVScalerConfig) _then) = __$NVScalerConfigCopyWithImpl;
@override @useResult
$Res call({
 bool autoHdrSkip
});




}
/// @nodoc
class __$NVScalerConfigCopyWithImpl<$Res>
    implements _$NVScalerConfigCopyWith<$Res> {
  __$NVScalerConfigCopyWithImpl(this._self, this._then);

  final _NVScalerConfig _self;
  final $Res Function(_NVScalerConfig) _then;

/// Create a copy of NVScalerConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? autoHdrSkip = null,}) {
  return _then(_NVScalerConfig(
autoHdrSkip: null == autoHdrSkip ? _self.autoHdrSkip : autoHdrSkip // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
