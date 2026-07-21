// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trakt_scrobble_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TraktScrobbleRequest {

 double? get progress;
/// Create a copy of TraktScrobbleRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TraktScrobbleRequestCopyWith<TraktScrobbleRequest> get copyWith => _$TraktScrobbleRequestCopyWithImpl<TraktScrobbleRequest>(this as TraktScrobbleRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TraktScrobbleRequest&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode => Object.hash(runtimeType,progress);

@override
String toString() {
  return 'TraktScrobbleRequest(progress: $progress)';
}


}

/// @nodoc
abstract mixin class $TraktScrobbleRequestCopyWith<$Res>  {
  factory $TraktScrobbleRequestCopyWith(TraktScrobbleRequest value, $Res Function(TraktScrobbleRequest) _then) = _$TraktScrobbleRequestCopyWithImpl;
@useResult
$Res call({
 double? progress
});




}
/// @nodoc
class _$TraktScrobbleRequestCopyWithImpl<$Res>
    implements $TraktScrobbleRequestCopyWith<$Res> {
  _$TraktScrobbleRequestCopyWithImpl(this._self, this._then);

  final TraktScrobbleRequest _self;
  final $Res Function(TraktScrobbleRequest) _then;

/// Create a copy of TraktScrobbleRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? progress = freezed,}) {
  return _then(_self.copyWith(
progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [TraktScrobbleRequest].
extension TraktScrobbleRequestPatterns on TraktScrobbleRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TraktScrobbleMovieRequest value)?  movie,TResult Function( TraktScrobbleEpisodeRequest value)?  episode,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TraktScrobbleMovieRequest() when movie != null:
return movie(_that);case TraktScrobbleEpisodeRequest() when episode != null:
return episode(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TraktScrobbleMovieRequest value)  movie,required TResult Function( TraktScrobbleEpisodeRequest value)  episode,}){
final _that = this;
switch (_that) {
case TraktScrobbleMovieRequest():
return movie(_that);case TraktScrobbleEpisodeRequest():
return episode(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TraktScrobbleMovieRequest value)?  movie,TResult? Function( TraktScrobbleEpisodeRequest value)?  episode,}){
final _that = this;
switch (_that) {
case TraktScrobbleMovieRequest() when movie != null:
return movie(_that);case TraktScrobbleEpisodeRequest() when episode != null:
return episode(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( TraktIds ids,  double? progress)?  movie,TResult Function( TraktIds showIds,  int season,  int number,  double? progress)?  episode,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TraktScrobbleMovieRequest() when movie != null:
return movie(_that.ids,_that.progress);case TraktScrobbleEpisodeRequest() when episode != null:
return episode(_that.showIds,_that.season,_that.number,_that.progress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( TraktIds ids,  double? progress)  movie,required TResult Function( TraktIds showIds,  int season,  int number,  double? progress)  episode,}) {final _that = this;
switch (_that) {
case TraktScrobbleMovieRequest():
return movie(_that.ids,_that.progress);case TraktScrobbleEpisodeRequest():
return episode(_that.showIds,_that.season,_that.number,_that.progress);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( TraktIds ids,  double? progress)?  movie,TResult? Function( TraktIds showIds,  int season,  int number,  double? progress)?  episode,}) {final _that = this;
switch (_that) {
case TraktScrobbleMovieRequest() when movie != null:
return movie(_that.ids,_that.progress);case TraktScrobbleEpisodeRequest() when episode != null:
return episode(_that.showIds,_that.season,_that.number,_that.progress);case _:
  return null;

}
}

}

/// @nodoc


class TraktScrobbleMovieRequest extends TraktScrobbleRequest {
  const TraktScrobbleMovieRequest({required this.ids, this.progress}): super._();
  

 final  TraktIds ids;
@override final  double? progress;

/// Create a copy of TraktScrobbleRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TraktScrobbleMovieRequestCopyWith<TraktScrobbleMovieRequest> get copyWith => _$TraktScrobbleMovieRequestCopyWithImpl<TraktScrobbleMovieRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TraktScrobbleMovieRequest&&(identical(other.ids, ids) || other.ids == ids)&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode => Object.hash(runtimeType,ids,progress);

@override
String toString() {
  return 'TraktScrobbleRequest.movie(ids: $ids, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $TraktScrobbleMovieRequestCopyWith<$Res> implements $TraktScrobbleRequestCopyWith<$Res> {
  factory $TraktScrobbleMovieRequestCopyWith(TraktScrobbleMovieRequest value, $Res Function(TraktScrobbleMovieRequest) _then) = _$TraktScrobbleMovieRequestCopyWithImpl;
@override @useResult
$Res call({
 TraktIds ids, double? progress
});




}
/// @nodoc
class _$TraktScrobbleMovieRequestCopyWithImpl<$Res>
    implements $TraktScrobbleMovieRequestCopyWith<$Res> {
  _$TraktScrobbleMovieRequestCopyWithImpl(this._self, this._then);

  final TraktScrobbleMovieRequest _self;
  final $Res Function(TraktScrobbleMovieRequest) _then;

/// Create a copy of TraktScrobbleRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ids = null,Object? progress = freezed,}) {
  return _then(TraktScrobbleMovieRequest(
ids: null == ids ? _self.ids : ids // ignore: cast_nullable_to_non_nullable
as TraktIds,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc


class TraktScrobbleEpisodeRequest extends TraktScrobbleRequest {
  const TraktScrobbleEpisodeRequest({required this.showIds, required this.season, required this.number, this.progress}): super._();
  

 final  TraktIds showIds;
 final  int season;
 final  int number;
@override final  double? progress;

/// Create a copy of TraktScrobbleRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TraktScrobbleEpisodeRequestCopyWith<TraktScrobbleEpisodeRequest> get copyWith => _$TraktScrobbleEpisodeRequestCopyWithImpl<TraktScrobbleEpisodeRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TraktScrobbleEpisodeRequest&&(identical(other.showIds, showIds) || other.showIds == showIds)&&(identical(other.season, season) || other.season == season)&&(identical(other.number, number) || other.number == number)&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode => Object.hash(runtimeType,showIds,season,number,progress);

@override
String toString() {
  return 'TraktScrobbleRequest.episode(showIds: $showIds, season: $season, number: $number, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $TraktScrobbleEpisodeRequestCopyWith<$Res> implements $TraktScrobbleRequestCopyWith<$Res> {
  factory $TraktScrobbleEpisodeRequestCopyWith(TraktScrobbleEpisodeRequest value, $Res Function(TraktScrobbleEpisodeRequest) _then) = _$TraktScrobbleEpisodeRequestCopyWithImpl;
@override @useResult
$Res call({
 TraktIds showIds, int season, int number, double? progress
});




}
/// @nodoc
class _$TraktScrobbleEpisodeRequestCopyWithImpl<$Res>
    implements $TraktScrobbleEpisodeRequestCopyWith<$Res> {
  _$TraktScrobbleEpisodeRequestCopyWithImpl(this._self, this._then);

  final TraktScrobbleEpisodeRequest _self;
  final $Res Function(TraktScrobbleEpisodeRequest) _then;

/// Create a copy of TraktScrobbleRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? showIds = null,Object? season = null,Object? number = null,Object? progress = freezed,}) {
  return _then(TraktScrobbleEpisodeRequest(
showIds: null == showIds ? _self.showIds : showIds // ignore: cast_nullable_to_non_nullable
as TraktIds,season: null == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
