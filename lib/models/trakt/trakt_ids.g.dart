// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trakt_ids.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TraktIds _$TraktIdsFromJson(Map<String, dynamic> json) => TraktIds(
  trakt: (json['trakt'] as num?)?.toInt(),
  slug: json['slug'] as String?,
  imdb: json['imdb'] as String?,
  tmdb: (json['tmdb'] as num?)?.toInt(),
  tvdb: (json['tvdb'] as num?)?.toInt(),
);

Map<String, dynamic> _$TraktIdsToJson(TraktIds instance) => <String, dynamic>{
  'trakt': ?instance.trakt,
  'slug': ?instance.slug,
  'imdb': ?instance.imdb,
  'tmdb': ?instance.tmdb,
  'tvdb': ?instance.tvdb,
};
