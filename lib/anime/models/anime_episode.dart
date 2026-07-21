/// Represents a single episode fetched from the AniZip API
/// (`https://api.ani.zip/mappings?anilist_id={id}`).
class AnimeEpisode {
  /// AniZip's episode key (usually equals [episodeNumber]).
  final String key;

  /// Episode number within the season.
  final int episodeNumber;

  /// Absolute episode number across all seasons.
  final int absoluteEpisodeNumber;

  /// Season this episode belongs to.
  final int? seasonNumber;

  /// English episode title.
  final String? titleEn;

  /// Japanese episode title.
  final String? titleJa;

  /// X-JAT romanized title.
  final String? titleXJat;

  /// Thumbnail image URL (from TheTVDB via AniZip).
  final String? image;

  /// Air date string in "YYYY-MM-DD" format.
  final String? airDate;

  /// Episode synopsis / overview.
  final String? overview;

  /// Runtime in minutes.
  final int? runtime;

  /// AniDB community rating (string "X.XX").
  final double? rating;

  /// "season" or "series" when this is a finale episode.
  final String? finaleType;

  /// AniDB episode ID for cross-referencing.
  final int? anidbEid;

  const AnimeEpisode({
    required this.key,
    required this.episodeNumber,
    required this.absoluteEpisodeNumber,
    this.seasonNumber,
    this.titleEn,
    this.titleJa,
    this.titleXJat,
    this.image,
    this.airDate,
    this.overview,
    this.runtime,
    this.rating,
    this.finaleType,
    this.anidbEid,
  });

  // ── Computed helpers ──────────────────────────────────────────────────────

  /// Best available display title for the episode.
  String get displayTitle =>
      titleEn?.isNotEmpty == true
          ? titleEn!
          : titleXJat?.isNotEmpty == true
          ? titleXJat!
          : titleJa?.isNotEmpty == true
          ? titleJa!
          : 'Episode $episodeNumber';

  bool get isSeasonFinale => finaleType == 'season';
  bool get isSeriesFinale => finaleType == 'series';

  // ── Factory ───────────────────────────────────────────────────────────────

  factory AnimeEpisode.fromJson(String key, Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>?;

    // AniZip uses both episodeNumber (season-relative) and
    // absoluteEpisodeNumber. Fall back to parsing key when missing.
    final episodeNumber = (json['episodeNumber'] as num?)?.toInt() ??
        int.tryParse(key) ??
        0;
    final absoluteEpisodeNumber =
        (json['absoluteEpisodeNumber'] as num?)?.toInt() ?? episodeNumber;

    // Rating comes as a string like "6.03"
    final ratingRaw = json['rating'];
    final rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw?.toString() ?? '');

    return AnimeEpisode(
      key: key,
      episodeNumber: episodeNumber,
      absoluteEpisodeNumber: absoluteEpisodeNumber,
      seasonNumber: (json['seasonNumber'] as num?)?.toInt(),
      titleEn: title?['en'] as String?,
      titleJa: title?['ja'] as String?,
      titleXJat: title?['x-jat'] as String?,
      image: json['image'] as String?,
      airDate: (json['airDate'] ?? json['airdate']) as String?,
      overview: (json['overview'] ?? json['summary']) as String?,
      runtime: (json['runtime'] ?? json['length']) as int?,
      rating: rating,
      finaleType: json['finaleType'] as String?,
      anidbEid: (json['anidbEid'] as num?)?.toInt(),
    );
  }
}
