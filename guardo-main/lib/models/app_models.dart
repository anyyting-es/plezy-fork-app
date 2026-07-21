class SearchResult {
  SearchResult({
    required this.id,
    required this.title,
    this.image,
    this.url,
    this.slug,
  });

  final String id;
  final String title;
  final String? image;
  final String? url;
  final String? slug;
}

class AnimeDetailsResult {
  AnimeDetailsResult({
    required this.id,
    required this.title,
    required this.episodes,
  });

  final String id;
  final String title;
  final List<EpisodeInfo> episodes;
}

class ManhwaDetails {
  ManhwaDetails({
    required this.id,
    required this.slug,
    required this.title,
    required this.image,
    required this.description,
    required this.status,
    required this.type,
    required this.genres,
    required this.chapters,
  });

  final String id;
  final String slug;
  final String title;
  final String image;
  final String description;
  final String status;
  final String type;
  final List<String> genres;
  final List<Map<String, dynamic>> chapters;

  factory ManhwaDetails.fromJson(Map<String, dynamic> json) {
    return ManhwaDetails(
      id: json['id']?.toString() ?? '',
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      image: json['image'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? '',
      type: json['type'] ?? '',
      genres: (json['genres'] as List? ?? []).cast<String>(),
      chapters: (json['chapters'] as List? ?? []).cast<Map<String, dynamic>>(),
    );
  }
}

class AnizipResult {
  AnizipResult({
    required this.episodes,
    this.tmdbId,
    this.seasonNumber,
    this.theTvdbId,
    this.malId,
    this.anidbId,
    this.logo,
    this.banner,
    this.poster,
    this.overview,
    this.mappingType,
  });

  final Map<int, TvdbEpisode> episodes;
  final int? tmdbId;
  final int? seasonNumber;
  final int? theTvdbId;
  final int? malId;
  final int? anidbId;
  final String? logo;
  final String? banner;
  final String? poster;
  final String? overview;
  final String? mappingType;  // 'TV', 'MOVIE', etc.
}

class EpisodeInfo {
  EpisodeInfo({
    required this.id,
    required this.number,
    required this.title,
    this.description,
    this.url,
    this.image,
    this.hasDub = false,
    this.airDate,
  });

  final String id;
  final int number;
  final String title;
  final String? description;
  final String? url;
  final String? image;
  final bool hasDub;
  final String? airDate;
}

class SubtitleTrack {
  SubtitleTrack({
    required this.id,
    required this.name,
    required this.language,
    required this.url,
    this.headers,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String language;
  final String url;
  final Map<String, String>? headers;
  final bool isDefault;
}

class StreamLink {
  StreamLink({
    required this.url,
    required this.quality,
    required this.isM3u8,
    this.headers,
    this.subtitles = const [],
  });

  final String url;
  final String quality;
  final bool isM3u8;
  final Map<String, String>? headers;
  final List<SubtitleTrack> subtitles;
}

class TvdbEpisode {
  TvdbEpisode({
    required this.episodeNumber,
    this.absoluteNumber,
    required this.name,
    this.overview = '',
    this.stillPath,
    this.airDate,
    this.voteAverage = 0,
    this.runtime,
  });

  final int episodeNumber;
  final int? absoluteNumber;
  final String name;
  final String overview;
  final String? stillPath;
  final String? airDate;
  final num voteAverage;
  final int? runtime;

  factory TvdbEpisode.fromJson(Map<String, dynamic> json) {
    return TvdbEpisode(
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? 'Episodio',
      overview: (json['overview'] as String?) ?? '',
      stillPath: json['still_path'] as String?,
      airDate: json['air_date'] as String?,
      voteAverage: (json['vote_average'] as num?) ?? 0,
      runtime: (json['runtime'] as num?)?.toInt(),
    );
  }
}

class SkipTime {
  SkipTime({
    required this.startTime,
    required this.endTime,
    required this.skipType,
  });

  final double startTime;
  final double endTime;
  final String skipType;

  factory SkipTime.fromJson(Map<String, dynamic> json) {
    final interval = json['interval'] as Map<String, dynamic>?;
    return SkipTime(
      startTime: (interval?['startTime'] as num?)?.toDouble() ?? 0.0,
      endTime: (interval?['endTime'] as num?)?.toDouble() ?? 0.0,
      skipType: (json['skipType'] as String?) ?? '',
    );
  }
}

class AppSettings {
  AppSettings({
    required this.homeAnimeSections,
    required this.homeMangaSections,
    this.showProfileBanner = true,
    this.themePalette = 'violet',
    this.themeMode = 'dark',
    this.oledBlack = false,
    this.preferredPlayer = 'mpv',
    this.metadataSource = 'anilist',
  });

  final bool showProfileBanner;
  final String themePalette;
  final String themeMode;
  final bool oledBlack;
  final String preferredPlayer; // 'mpv' or 'exoplayer'
  final String metadataSource; // 'anilist' or 'tmdb'
  final Map<String, bool> homeAnimeSections;
  final Map<String, bool> homeMangaSections;

  AppSettings copyWith({
    bool? showProfileBanner,
    String? themePalette,
    String? themeMode,
    bool? oledBlack,
    String? preferredPlayer,
    String? metadataSource,
    Map<String, bool>? homeAnimeSections,
    Map<String, bool>? homeMangaSections,
  }) {
    return AppSettings(
      showProfileBanner: showProfileBanner ?? this.showProfileBanner,
      themePalette: themePalette ?? this.themePalette,
      themeMode: themeMode ?? this.themeMode,
      oledBlack: oledBlack ?? this.oledBlack,
      preferredPlayer: preferredPlayer ?? this.preferredPlayer,
      metadataSource: metadataSource ?? this.metadataSource,
      homeAnimeSections: homeAnimeSections ?? this.homeAnimeSections,
      homeMangaSections: homeMangaSections ?? this.homeMangaSections,
    );
  }

  static AppSettings defaults() => AppSettings(
    showProfileBanner: true,
    preferredPlayer: 'mpv',
    metadataSource: 'anilist',
    homeAnimeSections: {
      'trending': true,
      'popular': true,
      'all_time': true,
      'romance': true,
      'action': true,
      'comedy': true,
      'fantasy': true,
      'upcoming': true,
    },
    homeMangaSections: {
      'trending': true,
      'popular': true,
      'manhwa': true,
      'action': true,
      'romance': true,
      'fantasy': true,
      'comedy': true,
    },
  );

  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    final defaults = AppSettings.defaults();
    if (json == null) return defaults;
    final ui = json['ui'] as Map<String, dynamic>?;

    Map<String, bool> parseSectionMap(
      Map<String, bool> fallback,
      dynamic value,
    ) {
      final map = Map<String, bool>.from(fallback);
      if (value is Map) {
        for (final key in value.keys) {
          map[key.toString()] = value[key] != false;
        }
      }
      return map;
    }

    return AppSettings(
      showProfileBanner: (ui?['showProfileBanner'] as bool?) ?? true,
      themePalette: (ui?['themePalette'] as String?) ?? defaults.themePalette,
      themeMode: (ui?['themeMode'] as String?) ?? 'dark',
      oledBlack: (ui?['oledBlack'] as bool?) ?? defaults.oledBlack,
      preferredPlayer: (json['preferredPlayer'] as String?) ?? defaults.preferredPlayer,
      metadataSource: (json['metadataSource'] as String?) ?? defaults.metadataSource,
      homeAnimeSections: parseSectionMap(
        defaults.homeAnimeSections,
        json['homeAnimeSections'],
      ),
      homeMangaSections: parseSectionMap(
        defaults.homeMangaSections,
        json['homeMangaSections'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'ui': {
      'showProfileBanner': showProfileBanner,
      'themePalette': themePalette,
      'themeMode': themeMode,
      'oledBlack': oledBlack,
    },
    'preferredPlayer': preferredPlayer,
    'metadataSource': metadataSource,
    'homeAnimeSections': homeAnimeSections,
    'homeMangaSections': homeMangaSections,
  };
}

enum ListType { watching, planning, completed, dropped, paused }

String listTypeToString(ListType type) => type.name;

ListType listTypeFromString(String? value) {
  return ListType.values.firstWhere(
    (item) => item.name == value,
    orElse: () => ListType.planning,
  );
}

class WatchEntry {
  WatchEntry({
    required this.animeId,
    required this.animeTitleRomaji,
    required this.animeCover,
    required this.lastEpisodeNumber,
    required this.currentTime,
    required this.duration,
    required this.progress,
    required this.watchedEpisodes,
    required this.updatedAt,
    this.animeTitleEnglish,
    this.animeBanner,
    this.totalEpisodes,
    this.animeStatus,
    this.lastEpisodeTitle,
    this.sourceEpisodeId,
    this.hasDub,
    this.audioMode,
    this.status,
    this.score,
    this.startDate,
    this.finishDate,
    this.rewatches,
    this.notes,
    this.lastEpisodeStill,
  });

  final int animeId;
  final String animeTitleRomaji;
  final String? animeTitleEnglish;
  final String animeCover;
  final String? animeBanner;
  final int? totalEpisodes;
  final String? animeStatus;
  final int lastEpisodeNumber;
  final String? lastEpisodeTitle;
  final double currentTime;
  final double duration;
  final double progress;
  final List<int> watchedEpisodes;
  final int updatedAt;
  final String? sourceEpisodeId;
  final bool? hasDub;
  final String? audioMode;
  final String? status;
  final double? score;
  final String? startDate;
  final String? finishDate;
  final int? rewatches;
  final String? notes;
  final String? lastEpisodeStill;

  factory WatchEntry.fromJson(Map<String, dynamic> json) {
    return WatchEntry(
      animeId: (json['animeId'] as num?)?.toInt() ?? 0,
      animeTitleRomaji: (json['animeTitleRomaji'] as String?) ?? '',
      animeTitleEnglish: json['animeTitleEnglish'] as String?,
      animeCover: (json['animeCover'] as String?) ?? '',
      animeBanner: json['animeBanner'] as String?,
      totalEpisodes: (json['totalEpisodes'] as num?)?.toInt(),
      animeStatus: json['animeStatus'] as String?,
      lastEpisodeNumber: (json['lastEpisodeNumber'] as num?)?.toInt() ?? 1,
      lastEpisodeTitle: json['lastEpisodeTitle'] as String?,
      currentTime: (json['currentTime'] as num?)?.toDouble() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      watchedEpisodes: (json['watchedEpisodes'] as List<dynamic>? ?? const [])
          .map((item) => (item as num).toInt())
          .toList(),
      updatedAt:
          (json['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      sourceEpisodeId: json['sourceEpisodeId'] as String?,
      hasDub: json['hasDub'] as bool?,
      audioMode: json['audioMode'] as String?,
      status: json['status'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      startDate: json['startDate'] as String?,
      finishDate: json['finishDate'] as String?,
      rewatches: (json['rewatches'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      lastEpisodeStill: json['lastEpisodeStill'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'animeId': animeId,
    'animeTitleRomaji': animeTitleRomaji,
    'animeTitleEnglish': animeTitleEnglish,
    'animeCover': animeCover,
    'animeBanner': animeBanner,
    'totalEpisodes': totalEpisodes,
    'animeStatus': animeStatus,
    'lastEpisodeNumber': lastEpisodeNumber,
    'lastEpisodeTitle': lastEpisodeTitle,
    'currentTime': currentTime,
    'duration': duration,
    'progress': progress,
    'watchedEpisodes': watchedEpisodes,
    'updatedAt': updatedAt,
    'sourceEpisodeId': sourceEpisodeId,
    'hasDub': hasDub,
    'audioMode': audioMode,
    'status': status,
    'score': score,
    'startDate': startDate,
    'finishDate': finishDate,
    'rewatches': rewatches,
    'notes': notes,
    'lastEpisodeStill': lastEpisodeStill,
  };
}

class ReadEntry {
  ReadEntry({
    required this.mangaId,
    required this.mangaTitleRomaji,
    required this.mangaCover,
    required this.lastChapterNumber,
    required this.readChapters,
    required this.updatedAt,
    this.mangaTitleEnglish,
    this.mangaBanner,
    this.totalChapters,
    this.mangaStatus,
    this.sourceSlug,
  });

  final int mangaId;
  final String mangaTitleRomaji;
  final String? mangaTitleEnglish;
  final String mangaCover;
  final String? mangaBanner;
  final int? totalChapters;
  final String? mangaStatus;
  final double lastChapterNumber;
  final List<int> readChapters;
  final int updatedAt;
  final String? sourceSlug;

  factory ReadEntry.fromJson(Map<String, dynamic> json) {
    return ReadEntry(
      mangaId: (json['mangaId'] as num?)?.toInt() ?? 0,
      mangaTitleRomaji: (json['mangaTitleRomaji'] as String?) ?? '',
      mangaTitleEnglish: json['mangaTitleEnglish'] as String?,
      mangaCover: (json['mangaCover'] as String?) ?? '',
      mangaBanner: json['mangaBanner'] as String?,
      totalChapters: (json['totalChapters'] as num?)?.toInt(),
      mangaStatus: json['mangaStatus'] as String?,
      lastChapterNumber: (json['lastChapterNumber'] as num?)?.toDouble() ?? 1,
      readChapters: (json['readChapters'] as List<dynamic>? ?? const [])
          .map((item) => (item as num).toInt())
          .toList(),
      updatedAt:
          (json['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      sourceSlug: json['sourceSlug'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'mangaId': mangaId,
    'mangaTitleRomaji': mangaTitleRomaji,
    'mangaTitleEnglish': mangaTitleEnglish,
    'mangaCover': mangaCover,
    'mangaBanner': mangaBanner,
    'totalChapters': totalChapters,
    'mangaStatus': mangaStatus,
    'lastChapterNumber': lastChapterNumber,
    'readChapters': readChapters,
    'updatedAt': updatedAt,
    'sourceSlug': sourceSlug,
  };
}

class ListEntry {
  ListEntry({
    required this.id,
    required this.title,
    required this.cover,
    required this.list,
    required this.progress,
    required this.updatedAt,
    this.titleEnglish,
    this.totalEpisodes,
    this.totalChapters,
    this.averageScore,
    this.status,
    this.format,
    this.addedAt,
    this.score,
    this.startDate,
    this.endDate,
  });

  final int id;
  final String title;
  final String? titleEnglish;
  final String cover;
  final ListType list;
  final int progress;
  final int updatedAt;
  final int? totalEpisodes;
  final int? totalChapters;
  final num? averageScore;
  final String? status;
  final String? format;
  final int? addedAt;
  final num? score;
  final String? startDate;
  final String? endDate;

  factory ListEntry.fromJson(
    Map<String, dynamic> json, {
    required bool isManga,
  }) {
    return ListEntry(
      id: (json[isManga ? 'mangaId' : 'animeId'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      titleEnglish: json['titleEnglish'] as String?,
      cover: (json['cover'] as String?) ?? '',
      list: listTypeFromString(json['list'] as String?),
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      totalEpisodes: (json['totalEpisodes'] as num?)?.toInt(),
      totalChapters: (json['totalChapters'] as num?)?.toInt(),
      averageScore: json['averageScore'] as num?,
      status: json['status'] as String?,
      format: json['format'] as String?,
      addedAt: (json['addedAt'] as num?)?.toInt(),
      score: json['score'] as num?,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
    );
  }

  Map<String, dynamic> toJson({required bool isManga}) => {
    isManga ? 'mangaId' : 'animeId': id,
    'title': title,
    'titleEnglish': titleEnglish,
    'cover': cover,
    'list': listTypeToString(list),
    'progress': progress,
    'updatedAt': updatedAt,
    'totalEpisodes': totalEpisodes,
    'totalChapters': totalChapters,
    'averageScore': averageScore,
    'status': status,
    'format': format,
    'addedAt': addedAt,
    'score': score,
    'startDate': startDate,
    'endDate': endDate,
  };
}
