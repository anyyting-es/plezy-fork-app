enum AnimeListProvider { tvdb, tmdb }

enum AnimeListMatchKind { explicit, range, defaultMapping }

class AnimeListSeasonRef {
  final int? number;
  final bool isAbsolute;

  const AnimeListSeasonRef.number(this.number) : isAbsolute = false;
  const AnimeListSeasonRef.absolute() : number = null, isAbsolute = true;
}

class AnimeListEntry {
  final int anidbId;
  final String? name;
  final String? rawTvdbId;
  final int? tvdbId;
  final AnimeListSeasonRef? defaultTvdbSeason;
  final int episodeOffset;
  final int? tmdbTvId;
  final AnimeListSeasonRef? tmdbSeason;
  final int tmdbOffset;
  final List<int> tmdbMovieIds;
  final List<String> imdbIds;
  final List<AnimeListEpisodeMapping> mappings;

  const AnimeListEntry({
    required this.anidbId,
    this.name,
    this.rawTvdbId,
    this.tvdbId,
    this.defaultTvdbSeason,
    this.episodeOffset = 0,
    this.tmdbTvId,
    this.tmdbSeason,
    this.tmdbOffset = 0,
    this.tmdbMovieIds = const [],
    this.imdbIds = const [],
    this.mappings = const [],
  });

  List<AnimeEpisodeMatch> resolveEpisode({
    required AnimeListProvider provider,
    required int externalSeason,
    required int externalEpisode,
  }) {
    final explicit = <AnimeEpisodeMatch>[];
    for (final mapping in mappings) {
      if (!mapping.matchesProviderSeason(provider, externalSeason)) continue;
      for (final item in mapping.explicit) {
        if (item.externalEpisodes.contains(externalEpisode)) {
          explicit.add(
            AnimeEpisodeMatch(
              anidbId: anidbId,
              anidbSeason: mapping.anidbSeason,
              anidbEpisode: item.anidbEpisode,
              provider: provider,
              externalSeason: externalSeason,
              externalEpisode: externalEpisode,
              kind: AnimeListMatchKind.explicit,
            ),
          );
        }
      }
    }
    if (explicit.isNotEmpty) return explicit;

    final ranges = <AnimeEpisodeMatch>[];
    for (final mapping in mappings) {
      if (!mapping.matchesProviderSeason(provider, externalSeason)) continue;
      final start = mapping.start;
      if (start == null) continue;
      final anidbEpisode = externalEpisode - mapping.offset;
      if (anidbEpisode < start) continue;
      final end = mapping.end;
      if (end != null && anidbEpisode > end) continue;
      if (anidbEpisode <= 0) continue;
      ranges.add(
        AnimeEpisodeMatch(
          anidbId: anidbId,
          anidbSeason: mapping.anidbSeason,
          anidbEpisode: anidbEpisode,
          provider: provider,
          externalSeason: externalSeason,
          externalEpisode: externalEpisode,
          kind: AnimeListMatchKind.range,
          rangeStart: start,
          rangeEnd: end,
        ),
      );
    }
    if (ranges.isNotEmpty) return ranges;

    final defaultSeason = switch (provider) {
      AnimeListProvider.tvdb => defaultTvdbSeason,
      AnimeListProvider.tmdb => tmdbSeason,
    };
    final defaultOffset = switch (provider) {
      AnimeListProvider.tvdb => episodeOffset,
      AnimeListProvider.tmdb => tmdbOffset,
    };
    if (defaultSeason == null || defaultSeason.isAbsolute || defaultSeason.number != externalSeason) return const [];

    final anidbEpisode = externalEpisode - defaultOffset;
    if (anidbEpisode <= 0) return const [];
    return [
      AnimeEpisodeMatch(
        anidbId: anidbId,
        anidbSeason: 1,
        anidbEpisode: anidbEpisode,
        provider: provider,
        externalSeason: externalSeason,
        externalEpisode: externalEpisode,
        kind: AnimeListMatchKind.defaultMapping,
      ),
    ];
  }

  bool mapsSeason({required AnimeListProvider provider, required int externalSeason}) {
    final defaultSeason = switch (provider) {
      AnimeListProvider.tvdb => defaultTvdbSeason,
      AnimeListProvider.tmdb => tmdbSeason,
    };
    if (defaultSeason != null && !defaultSeason.isAbsolute && defaultSeason.number == externalSeason) return true;
    return mappings.any((mapping) => mapping.matchesProviderSeason(provider, externalSeason));
  }
}

class AnimeListEpisodeMapping {
  final int anidbSeason;
  final AnimeListProvider provider;
  final int externalSeason;
  final int? start;
  final int? end;
  final int offset;
  final List<AnimeListExplicitEpisodeMapping> explicit;

  const AnimeListEpisodeMapping({
    required this.anidbSeason,
    required this.provider,
    required this.externalSeason,
    this.start,
    this.end,
    this.offset = 0,
    this.explicit = const [],
  });

  bool matchesProviderSeason(AnimeListProvider provider, int season) =>
      this.provider == provider && externalSeason == season;
}

class AnimeListExplicitEpisodeMapping {
  final int anidbEpisode;
  final List<int> externalEpisodes;

  const AnimeListExplicitEpisodeMapping({required this.anidbEpisode, required this.externalEpisodes});
}

class AnimeEpisodeMatch {
  final int anidbId;
  final int anidbSeason;
  final int anidbEpisode;
  final AnimeListProvider provider;
  final int externalSeason;
  final int externalEpisode;
  final AnimeListMatchKind kind;
  final int? rangeStart;
  final int? rangeEnd;

  const AnimeEpisodeMatch({
    required this.anidbId,
    required this.anidbSeason,
    required this.anidbEpisode,
    required this.provider,
    required this.externalSeason,
    required this.externalEpisode,
    required this.kind,
    this.rangeStart,
    this.rangeEnd,
  });

  bool sameAnimeEntry(AnimeEpisodeMatch other) => anidbId == other.anidbId && anidbSeason == other.anidbSeason;

  bool sameEpisode(AnimeEpisodeMatch other) =>
      sameAnimeEntry(other) && anidbEpisode == other.anidbEpisode && kind == other.kind;
}
