// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'play_queue.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlayQueue {

 List<MediaItem> get items; int? get currentIndex; bool get shuffled;
/// Create a copy of PlayQueue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayQueueCopyWith<PlayQueue> get copyWith => _$PlayQueueCopyWithImpl<PlayQueue>(this as PlayQueue, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayQueue&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.currentIndex, currentIndex) || other.currentIndex == currentIndex)&&(identical(other.shuffled, shuffled) || other.shuffled == shuffled));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),currentIndex,shuffled);

@override
String toString() {
  return 'PlayQueue(items: $items, currentIndex: $currentIndex, shuffled: $shuffled)';
}


}

/// @nodoc
abstract mixin class $PlayQueueCopyWith<$Res>  {
  factory $PlayQueueCopyWith(PlayQueue value, $Res Function(PlayQueue) _then) = _$PlayQueueCopyWithImpl;
@useResult
$Res call({
 List<MediaItem> items, int? currentIndex, bool shuffled
});




}
/// @nodoc
class _$PlayQueueCopyWithImpl<$Res>
    implements $PlayQueueCopyWith<$Res> {
  _$PlayQueueCopyWithImpl(this._self, this._then);

  final PlayQueue _self;
  final $Res Function(PlayQueue) _then;

/// Create a copy of PlayQueue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? currentIndex = freezed,Object? shuffled = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<MediaItem>,currentIndex: freezed == currentIndex ? _self.currentIndex : currentIndex // ignore: cast_nullable_to_non_nullable
as int?,shuffled: null == shuffled ? _self.shuffled : shuffled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PlayQueue].
extension PlayQueuePatterns on PlayQueue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PlexServerPlayQueue value)?  plex,TResult Function( LocalPlayQueue value)?  local,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PlexServerPlayQueue() when plex != null:
return plex(_that);case LocalPlayQueue() when local != null:
return local(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PlexServerPlayQueue value)  plex,required TResult Function( LocalPlayQueue value)  local,}){
final _that = this;
switch (_that) {
case PlexServerPlayQueue():
return plex(_that);case LocalPlayQueue():
return local(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PlexServerPlayQueue value)?  plex,TResult? Function( LocalPlayQueue value)?  local,}){
final _that = this;
switch (_that) {
case PlexServerPlayQueue() when plex != null:
return plex(_that);case LocalPlayQueue() when local != null:
return local(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int playQueueId,  List<MediaItem> items,  int? currentIndex,  bool shuffled,  int? selectedItemId,  int? version,  String? sourceUri)?  plex,TResult Function( String id,  List<MediaItem> items,  String backendId,  int? currentIndex,  bool shuffled)?  local,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PlexServerPlayQueue() when plex != null:
return plex(_that.playQueueId,_that.items,_that.currentIndex,_that.shuffled,_that.selectedItemId,_that.version,_that.sourceUri);case LocalPlayQueue() when local != null:
return local(_that.id,_that.items,_that.backendId,_that.currentIndex,_that.shuffled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int playQueueId,  List<MediaItem> items,  int? currentIndex,  bool shuffled,  int? selectedItemId,  int? version,  String? sourceUri)  plex,required TResult Function( String id,  List<MediaItem> items,  String backendId,  int? currentIndex,  bool shuffled)  local,}) {final _that = this;
switch (_that) {
case PlexServerPlayQueue():
return plex(_that.playQueueId,_that.items,_that.currentIndex,_that.shuffled,_that.selectedItemId,_that.version,_that.sourceUri);case LocalPlayQueue():
return local(_that.id,_that.items,_that.backendId,_that.currentIndex,_that.shuffled);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int playQueueId,  List<MediaItem> items,  int? currentIndex,  bool shuffled,  int? selectedItemId,  int? version,  String? sourceUri)?  plex,TResult? Function( String id,  List<MediaItem> items,  String backendId,  int? currentIndex,  bool shuffled)?  local,}) {final _that = this;
switch (_that) {
case PlexServerPlayQueue() when plex != null:
return plex(_that.playQueueId,_that.items,_that.currentIndex,_that.shuffled,_that.selectedItemId,_that.version,_that.sourceUri);case LocalPlayQueue() when local != null:
return local(_that.id,_that.items,_that.backendId,_that.currentIndex,_that.shuffled);case _:
  return null;

}
}

}

/// @nodoc


class PlexServerPlayQueue extends PlayQueue {
  const PlexServerPlayQueue({required this.playQueueId, required final  List<MediaItem> items, this.currentIndex, this.shuffled = false, this.selectedItemId, this.version, this.sourceUri}): _items = items,super._();
  

/// Plex `playQueueID` — addresses the queue for subsequent fetches.
 final  int playQueueId;
 final  List<MediaItem> _items;
@override List<MediaItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  int? currentIndex;
@override@JsonKey() final  bool shuffled;
/// Plex `playQueueSelectedItemID` of the active item.
 final  int? selectedItemId;
/// Plex `playQueueVersion` — server-side optimistic concurrency token.
 final  int? version;
/// Plex `playQueueSourceURI` — used for "Up Next" derivation.
 final  String? sourceUri;

/// Create a copy of PlayQueue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlexServerPlayQueueCopyWith<PlexServerPlayQueue> get copyWith => _$PlexServerPlayQueueCopyWithImpl<PlexServerPlayQueue>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlexServerPlayQueue&&(identical(other.playQueueId, playQueueId) || other.playQueueId == playQueueId)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.currentIndex, currentIndex) || other.currentIndex == currentIndex)&&(identical(other.shuffled, shuffled) || other.shuffled == shuffled)&&(identical(other.selectedItemId, selectedItemId) || other.selectedItemId == selectedItemId)&&(identical(other.version, version) || other.version == version)&&(identical(other.sourceUri, sourceUri) || other.sourceUri == sourceUri));
}


@override
int get hashCode => Object.hash(runtimeType,playQueueId,const DeepCollectionEquality().hash(_items),currentIndex,shuffled,selectedItemId,version,sourceUri);

@override
String toString() {
  return 'PlayQueue.plex(playQueueId: $playQueueId, items: $items, currentIndex: $currentIndex, shuffled: $shuffled, selectedItemId: $selectedItemId, version: $version, sourceUri: $sourceUri)';
}


}

/// @nodoc
abstract mixin class $PlexServerPlayQueueCopyWith<$Res> implements $PlayQueueCopyWith<$Res> {
  factory $PlexServerPlayQueueCopyWith(PlexServerPlayQueue value, $Res Function(PlexServerPlayQueue) _then) = _$PlexServerPlayQueueCopyWithImpl;
@override @useResult
$Res call({
 int playQueueId, List<MediaItem> items, int? currentIndex, bool shuffled, int? selectedItemId, int? version, String? sourceUri
});




}
/// @nodoc
class _$PlexServerPlayQueueCopyWithImpl<$Res>
    implements $PlexServerPlayQueueCopyWith<$Res> {
  _$PlexServerPlayQueueCopyWithImpl(this._self, this._then);

  final PlexServerPlayQueue _self;
  final $Res Function(PlexServerPlayQueue) _then;

/// Create a copy of PlayQueue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? playQueueId = null,Object? items = null,Object? currentIndex = freezed,Object? shuffled = null,Object? selectedItemId = freezed,Object? version = freezed,Object? sourceUri = freezed,}) {
  return _then(PlexServerPlayQueue(
playQueueId: null == playQueueId ? _self.playQueueId : playQueueId // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<MediaItem>,currentIndex: freezed == currentIndex ? _self.currentIndex : currentIndex // ignore: cast_nullable_to_non_nullable
as int?,shuffled: null == shuffled ? _self.shuffled : shuffled // ignore: cast_nullable_to_non_nullable
as bool,selectedItemId: freezed == selectedItemId ? _self.selectedItemId : selectedItemId // ignore: cast_nullable_to_non_nullable
as int?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int?,sourceUri: freezed == sourceUri ? _self.sourceUri : sourceUri // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class LocalPlayQueue extends PlayQueue {
  const LocalPlayQueue({required this.id, required final  List<MediaItem> items, required this.backendId, this.currentIndex, this.shuffled = false}): _items = items,super._();
  

/// Client-generated UUID identifying this queue for the session.
 final  String id;
 final  List<MediaItem> _items;
@override List<MediaItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

/// Server kind that owns this queue's items (typically `"jellyfin"`).
 final  String backendId;
@override final  int? currentIndex;
@override@JsonKey() final  bool shuffled;

/// Create a copy of PlayQueue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocalPlayQueueCopyWith<LocalPlayQueue> get copyWith => _$LocalPlayQueueCopyWithImpl<LocalPlayQueue>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocalPlayQueue&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.backendId, backendId) || other.backendId == backendId)&&(identical(other.currentIndex, currentIndex) || other.currentIndex == currentIndex)&&(identical(other.shuffled, shuffled) || other.shuffled == shuffled));
}


@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_items),backendId,currentIndex,shuffled);

@override
String toString() {
  return 'PlayQueue.local(id: $id, items: $items, backendId: $backendId, currentIndex: $currentIndex, shuffled: $shuffled)';
}


}

/// @nodoc
abstract mixin class $LocalPlayQueueCopyWith<$Res> implements $PlayQueueCopyWith<$Res> {
  factory $LocalPlayQueueCopyWith(LocalPlayQueue value, $Res Function(LocalPlayQueue) _then) = _$LocalPlayQueueCopyWithImpl;
@override @useResult
$Res call({
 String id, List<MediaItem> items, String backendId, int? currentIndex, bool shuffled
});




}
/// @nodoc
class _$LocalPlayQueueCopyWithImpl<$Res>
    implements $LocalPlayQueueCopyWith<$Res> {
  _$LocalPlayQueueCopyWithImpl(this._self, this._then);

  final LocalPlayQueue _self;
  final $Res Function(LocalPlayQueue) _then;

/// Create a copy of PlayQueue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? items = null,Object? backendId = null,Object? currentIndex = freezed,Object? shuffled = null,}) {
  return _then(LocalPlayQueue(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<MediaItem>,backendId: null == backendId ? _self.backendId : backendId // ignore: cast_nullable_to_non_nullable
as String,currentIndex: freezed == currentIndex ? _self.currentIndex : currentIndex // ignore: cast_nullable_to_non_nullable
as int?,shuffled: null == shuffled ? _self.shuffled : shuffled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
