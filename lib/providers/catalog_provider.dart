import 'dart:async';
import 'package:flutter/foundation.dart';
import '../anime/models/anime_media.dart';
import '../anime/models/anime_episode.dart';
import '../anime/services/anilist_service.dart';
import '../anime/services/anizip_service.dart';
import '../services/tmdb_service.dart';
import '../services/settings_service.dart';
import '../services/trackers/anilist/anilist_tracker.dart';
import '../utils/app_logger.dart';
import '../media/media_item.dart';
import '../media/media_hub.dart';
import '../media/media_backend.dart';
import '../media/media_kind.dart';
import '../i18n/strings.g.dart';

enum CatalogLoadState { initial, loading, loaded, error }

/// How long cached data is considered fresh (30 minutes).
const _kCacheTtl = Duration(minutes: 30);

/// Unified catalog provider for both AniList (Anime) and TMDB (Movies and Series).
class CatalogProvider extends ChangeNotifier {
  CatalogProvider() {
    _loadData();
    SettingsService.instance.listenable(SettingsService.discoverContentType).addListener(_onSettingChanged);
  }

  void _onSettingChanged() {
    unawaited(forceRefresh());
  }

  @override
  void dispose() {
    SettingsService.instance.listenable(SettingsService.discoverContentType).removeListener(_onSettingChanged);
    super.dispose();
  }

  CatalogLoadState _state = CatalogLoadState.initial;
  String? _errorMessage;

  List<MediaItem> _trending = [];
  List<MediaHub> _hubs = [];

  DateTime? _lastLoaded;
  bool? _lastAnilistConnected;
  bool _isRefreshing = false;
  int _loadGeneration = 0;

  // ── Public Getters ────────────────────────────────────────────────────────

  CatalogLoadState get state => _state;

  /// True only on the very first load (no data yet). Subsequent refreshes
  /// keep showing existing content so the UI never flickers blank.
  bool get isLoading =>
      _state == CatalogLoadState.loading &&
      _trending.isEmpty &&
      _hubs.isEmpty;

  String? get errorMessage =>
      _state == CatalogLoadState.error && _trending.isEmpty
          ? _errorMessage
          : null;

  List<MediaItem> get trending => _trending;
  List<MediaHub> get hubs => _hubs;
  int get loadGeneration => _loadGeneration;

  // ── Public Refresh Methods ────────────────────────────────────────────────

  /// Soft refresh: skips the network when data is still within [_kCacheTtl].
  Future<void> refresh() async {
    final isAnilistConnected = AnilistTracker.instance.client != null;
    if (_lastLoaded != null &&
        _lastAnilistConnected == isAnilistConnected &&
        DateTime.now().difference(_lastLoaded!) < _kCacheTtl) {
      return;
    }
    await _loadData(force: false);
  }

  /// Hard refresh: always hits the network regardless of cache age.
  Future<void> forceRefresh() async {
    await _loadData(force: true);
  }

  // ── Internal Data Loading ─────────────────────────────────────────────────

  Future<void> _loadData({bool force = false}) async {
    if (_isRefreshing) return;

    final isAnilistConnected = AnilistTracker.instance.client != null;

    if (!force &&
        _lastLoaded != null &&
        _lastAnilistConnected == isAnilistConnected &&
        DateTime.now().difference(_lastLoaded!) < _kCacheTtl) {
      return;
    }

    _lastAnilistConnected = isAnilistConnected;

    _isRefreshing = true;

    // Only show full loading spinner on first load; keep content for refreshes.
    final isFirstLoad = _trending.isEmpty && _hubs.isEmpty;
    if (isFirstLoad) {
      _state = CatalogLoadState.loading;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final contentType = SettingsService.instance.read(SettingsService.discoverContentType);

      if (contentType == DiscoverContentType.anime) {
        await _loadAnilistData();
      } else {
        await _loadTmdbData();
      }

      _state = CatalogLoadState.loaded;
      _errorMessage = null;
      _lastLoaded = DateTime.now();
      _loadGeneration++;
    } catch (e, st) {
      appLogger.e('CatalogProvider: load failed', error: e, stackTrace: st);
      _state = CatalogLoadState.error;
      _errorMessage = e.toString();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _loadAnilistData() async {
    // Fetch all AniList feeds concurrently
    final results = await Future.wait([
      AniListService.getTrending(perPage: 10),
      AniListService.getSeasonal(
        season: AniListService.currentSeason(),
        year: AniListService.currentYear(),
        perPage: 20,
      ),
      AniListService.getPopular(perPage: 20),
      AniListService.getUpcoming(perPage: 15),
    ]);

    final trendingRaw = results[0];
    final seasonalRaw = results[1];
    final popularRaw = results[2];
    final upcomingRaw = results[3];

    final client = AnilistTracker.instance.client;
    List<MediaItem> continueWatchingItems = [];
    if (client != null) {
      try {
        final entries = await client.getAnimeListByStatus('CURRENT');
        // Sort entries by updatedAt in descending order (most recently watched/updated first)
        entries.sort((a, b) {
          final aTime = (a['updatedAt'] as num?)?.toInt() ?? 0;
          final bTime = (b['updatedAt'] as num?)?.toInt() ?? 0;
          return bTime.compareTo(aTime);
        });

        final continueWatchingFutures = entries.map((entry) async {
          try {
            final mediaJson = entry['media'] as Map<String, dynamic>;
            final anime = AnimeMedia.fromJson(mediaJson);
            final progress = (entry['progress'] as num?)?.toInt() ?? 0;
            final episodesCount = anime.episodes ?? 0;

            // If completed, don't show in Continue Watching
            if (episodesCount > 0 && progress >= episodesCount) {
              return null;
            }

            final nextEpisodeNum = progress + 1;

            // Fetch episode metadata from AniZip (which has screenshots)
            List<AnimeEpisode> episodes = const [];
            try {
              episodes = await AniZipService.getEpisodes(anime.id);
            } catch (e) {
              appLogger.w('AniZip: error fetching episodes for anime ${anime.id}: $e');
            }
            
            // Find next episode type-safely
            AnimeEpisode? episode;
            for (final ep in episodes) {
              if (ep.episodeNumber == nextEpisodeNum) {
                episode = ep;
                break;
              }
            }

            // Check if the next episode has aired yet
            if (episode != null && episode.airDate != null) {
              try {
                final airDate = DateTime.parse(episode.airDate!);
                if (airDate.isAfter(DateTime.now())) {
                  return null;
                }
              } catch (_) {}
            }

            final displayTitle = anime.displayTitle;
            final backdropUrl = episode?.image ?? anime.bannerImage ?? anime.coverExtraLarge;

            return MediaItem(
              id: 'anime_ep_${anime.id}_$nextEpisodeNum',
              backend: MediaBackend.anilist,
              kind: MediaKind.episode,
              title: episode?.displayTitle ?? 'Episode $nextEpisodeNum',
              thumbPath: backdropUrl,
              artPath: anime.bannerImage ?? anime.coverExtraLarge,
              index: nextEpisodeNum,
              grandparentId: 'anime_${anime.id}',
              grandparentTitle: displayTitle,
              grandparentThumbPath: anime.coverExtraLarge,
              grandparentArtPath: anime.bannerImage,
              parentId: 'anime_${anime.id}',
              parentTitle: 'Temporada 1',
              viewedLeafCount: progress,
              leafCount: anime.episodes,
              raw: {
                'anime': mediaJson,
                'progress': progress,
              },
            );
          } catch (e, st) {
            appLogger.w('CatalogProvider: failed to map AniList entry', error: e, stackTrace: st);
            return null;
          }
        });

        final continueWatchingResolved = await Future.wait(continueWatchingFutures);
        continueWatchingItems = continueWatchingResolved.whereType<MediaItem>().toList();
      } catch (e, st) {
        appLogger.w('CatalogProvider: failed to load AniList continue watching', error: e, stackTrace: st);
      }
    }

    final newHubs = <MediaHub>[];

    if (continueWatchingItems.isNotEmpty) {
      newHubs.add(MediaHub(
        id: 'anilist_continue',
        title: t.discover.continueWatching,
        type: 'episode',
        items: continueWatchingItems,
      ));
    }

    final season = AniListService.currentSeason();
    final year = AniListService.currentYear();
    final seasonLabel = '${season[0]}${season.substring(1).toLowerCase()} $year';

    if (seasonalRaw.isNotEmpty) {
      newHubs.add(MediaHub(
        id: 'anime_seasonal',
        title: 'Temporada: $seasonLabel',
        type: 'show',
        items: seasonalRaw.map((m) => m.toMediaItem()).toList(),
      ));
    }

    if (popularRaw.isNotEmpty) {
      newHubs.add(MediaHub(
        id: 'anime_popular',
        title: 'Populares de Siempre',
        type: 'show',
        items: popularRaw.map((m) => m.toMediaItem()).toList(),
      ));
    }

    if (upcomingRaw.isNotEmpty) {
      newHubs.add(MediaHub(
        id: 'anime_upcoming',
        title: 'Próximos Estrenos',
        type: 'show',
        items: upcomingRaw.map((m) => m.toMediaItem()).toList(),
      ));
    }

    _trending = trendingRaw.map((m) => m.toMediaItem()).toList();
    _hubs = newHubs;
  }

  Future<void> _loadTmdbData() async {
    // Fetch all TMDB feeds concurrently
    final results = await Future.wait([
      TmdbService.getTrending(),
      TmdbService.getPopularMovies(),
      TmdbService.getPopularTv(),
      TmdbService.getRecentMovies(),
      TmdbService.getAiringTodayTv(),
    ]);

    final trendingRaw = results[0];
    final popularMoviesRaw = results[1];
    final popularTvRaw = results[2];
    final recentMoviesRaw = results[3];
    final airingTodayTvRaw = results[4];

    final newHubs = <MediaHub>[];

    if (popularMoviesRaw.isNotEmpty) {
      newHubs.add(MediaHub(
        id: 'tmdb_popular_movies',
        title: 'Películas Populares',
        type: 'movie',
        items: popularMoviesRaw,
      ));
    }

    if (popularTvRaw.isNotEmpty) {
      newHubs.add(MediaHub(
        id: 'tmdb_popular_tv',
        title: 'Series Populares',
        type: 'show',
        items: popularTvRaw,
      ));
    }

    if (recentMoviesRaw.isNotEmpty) {
      newHubs.add(MediaHub(
        id: 'tmdb_recent_movies',
        title: 'Películas Recientes (En Cines)',
        type: 'movie',
        items: recentMoviesRaw,
      ));
    }

    if (airingTodayTvRaw.isNotEmpty) {
      newHubs.add(MediaHub(
        id: 'tmdb_airing_today_tv',
        title: 'Series en Emisión (Hoy)',
        type: 'show',
        items: airingTodayTvRaw,
      ));
    }

    _trending = trendingRaw;
    _hubs = newHubs;
  }
}
