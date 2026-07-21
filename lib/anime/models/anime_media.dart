import '../../media/media_item.dart';
import '../../media/media_kind.dart';

/// Represents a single anime entry from the AniList GraphQL API.
class AnimeMedia {
  final int id;
  final String? titleEn;
  final String? titleRomaji;
  final String? titleNative;
  final String? description;
  final String? coverLarge;
  final String? coverExtraLarge;
  final String? bannerImage;

  /// Accent color hex string returned by AniList (e.g. "#e4a15d").
  final String? accentColor;

  /// Total episode count (null if ongoing/unknown).
  final int? episodes;

  /// Score from 0–100. Divide by 10 for a display rating.
  final double? averageScore;

  /// RELEASING | FINISHED | NOT_YET_RELEASED | CANCELLED | HIATUS
  final String? status;

  /// TV | TV_SHORT | MOVIE | SPECIAL | OVA | ONA | MUSIC
  final String? format;

  final int? seasonYear;

  /// WINTER | SPRING | SUMMER | FALL
  final String? season;

  final List<String> genres;

  /// MyAnimeList ID — used as a cross-reference; not directly consumed by UI.
  final int? idMal;

  const AnimeMedia({
    required this.id,
    this.titleEn,
    this.titleRomaji,
    this.titleNative,
    this.description,
    this.coverLarge,
    this.coverExtraLarge,
    this.bannerImage,
    this.accentColor,
    this.episodes,
    this.averageScore,
    this.status,
    this.format,
    this.seasonYear,
    this.season,
    this.genres = const [],
    this.idMal,
  });

  // ── Computed helpers ──────────────────────────────────────────────────────

  /// Best available display title (English → Romaji → Native → fallback).
  String get displayTitle =>
      titleEn?.isNotEmpty == true
          ? titleEn!
          : titleRomaji?.isNotEmpty == true
          ? titleRomaji!
          : titleNative ?? 'Unknown';

  /// Score expressed as X.X out of 10 (null when unavailable).
  double? get scoreOutOfTen =>
      averageScore != null ? (averageScore! / 10).clamp(0.0, 10.0) : null;

  /// Human-readable format label.
  String get formatDisplay => switch (format) {
    'TV' => 'TV',
    'TV_SHORT' => 'TV Short',
    'MOVIE' => 'Movie',
    'SPECIAL' => 'Special',
    'OVA' => 'OVA',
    'ONA' => 'ONA',
    'MUSIC' => 'Music',
    _ => format ?? 'Unknown',
  };

  /// Human-readable status label.
  String get statusDisplay => switch (status) {
    'RELEASING' => 'Airing',
    'FINISHED' => 'Finished',
    'NOT_YET_RELEASED' => 'Upcoming',
    'CANCELLED' => 'Cancelled',
    'HIATUS' => 'On Hiatus',
    _ => status ?? 'Unknown',
  };

  /// Season + year label (e.g. "Fall 2023").
  String? get seasonYearDisplay {
    if (season == null && seasonYear == null) return null;
    final s = season != null
        ? '${season![0]}${season!.substring(1).toLowerCase()}'
        : '';
    final y = seasonYear?.toString() ?? '';
    return '$s $y'.trim();
  }

  // ── Factory ───────────────────────────────────────────────────────────────

  factory AnimeMedia.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>?;
    final cover = json['coverImage'] as Map<String, dynamic>?;
    final genreList = (json['genres'] as List<dynamic>?)
            ?.map((g) => g.toString())
            .toList() ??
        [];

    // Strip HTML tags from description
    final rawDesc = json['description'] as String?;
    final cleanDesc = rawDesc != null ? _stripHtml(rawDesc) : null;

    return AnimeMedia(
      id: (json['id'] as num).toInt(),
      titleEn: title?['english'] as String?,
      titleRomaji: title?['romaji'] as String?,
      titleNative: title?['native'] as String?,
      description: cleanDesc,
      coverLarge: cover?['large'] as String?,
      coverExtraLarge: cover?['extraLarge'] as String?,
      bannerImage: json['bannerImage'] as String?,
      accentColor: cover?['color'] as String?,
      episodes: (json['episodes'] as num?)?.toInt(),
      averageScore: (json['averageScore'] as num?)?.toDouble(),
      status: json['status'] as String?,
      format: json['format'] as String?,
      seasonYear: (json['seasonYear'] as num?)?.toInt(),
      season: json['season'] as String?,
      genres: genreList,
      idMal: (json['idMal'] as num?)?.toInt(),
    );
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  MediaItem toMediaItem() {
    return MediaItem.anilist(
      id: 'anime_$id',
      kind: format == 'MOVIE' ? MediaKind.movie : MediaKind.show,
      title: displayTitle,
      summary: description,
      thumbPath: coverExtraLarge ?? coverLarge,
      artPath: bannerImage ?? coverExtraLarge ?? coverLarge,
      genres: genres,
      year: seasonYear,
      rating: averageScore != null ? (averageScore! / 10.0) : null,
      originallyAvailableAt: seasonYear != null ? '$seasonYear-01-01' : null,
    );
  }
}
