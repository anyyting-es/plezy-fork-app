import 'package:json_annotation/json_annotation.dart';

import '../../utils/external_ids.dart';

part 'trakt_ids.g.dart';

/// External IDs for matching Plex items against Trakt's catalog.
///
/// Trakt prefers (in order): trakt > slug > imdb > tmdb > tvdb. Movies use
/// imdb/tmdb; episodes use the show's tvdb/tmdb/imdb plus season/episode index.
@JsonSerializable(includeIfNull: false)
class TraktIds {
  final int? trakt;
  final String? slug;
  final String? imdb;
  final int? tmdb;
  final int? tvdb;

  const TraktIds({this.trakt, this.slug, this.imdb, this.tmdb, this.tvdb});

  /// True when at least one external ID is set (i.e. usable for Trakt matching).
  bool get hasAny => imdb != null || tmdb != null || tvdb != null || trakt != null || slug != null;

  Map<String, dynamic> toJson() => _$TraktIdsToJson(this);

  factory TraktIds.fromJson(Map<String, dynamic> json) => _$TraktIdsFromJson(json);

  factory TraktIds.fromExternal(ExternalIds ids) => TraktIds(imdb: ids.imdb, tmdb: ids.tmdb, tvdb: ids.tvdb);
}
