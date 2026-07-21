import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/anime_media.dart';
import '../models/anime_episode.dart';
import '../services/anilist_service.dart';
import '../services/anizip_service.dart';
import '../../utils/app_logger.dart';
import '../../media/media_item.dart';
import '../../media/media_hub.dart';

enum AnimeLoadState { initial, loading, loaded, error }

/// How long cached AniList data is considered fresh.
/// DiscoverScreen/TmdbProvider uses 30 minutes — we match that.
const _kCacheTtl = Duration(minutes: 30);

/// Provider for the Anime tab — mirrors the exact design of [TmdbProvider]:
///
/// - `isLoading` is only true on the very first load (no data yet).
/// - Background refreshes keep existing content visible to avoid flicker.
/// - `loadGeneration` increments on every full successful load so the screen
///   can detect a new-load vs a no-op refresh.
/// - `refresh()` respects the TTL; `forceRefresh()` always hits the network.
class AnimeProvider extends ChangeNotifier {
  AnimeProvider() {
    _loadData();
  }

  AnimeLoadState _state = AnimeLoadState.initial;
  String? _errorMessage;

  List<MediaItem> _trending = [];
  List<MediaHub> _hubs = [];

  DateTime? _lastLoaded;
  bool _isRefreshing = false;
  int _loadGeneration = 0;

  // ── Public getters ────────────────────────────────────────────────────────

  AnimeLoadState get state => _state;

  /// True only on the very first load (no data yet). Subsequent refreshes
  /// keep showing existing content so the UI never flickers blank.
  bool get isLoading =>
      _state == AnimeLoadState.loading &&
      _trending.isEmpty &&
      _hubs.isEmpty;

  String? get errorMessage =>
      _state == AnimeLoadState.error && _trending.isEmpty
          ? _errorMessage
          : null;

  List<MediaItem> get trending => _trending;
  List<MediaHub> get hubs => _hubs;
  int get loadGeneration => _loadGeneration;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    super.dispose();
  }

  // ── Public refresh methods ────────────────────────────────────────────────

  /// Soft refresh: skips the network when data is still within [_kCacheTtl].
  /// Matches TmdbProvider.refresh() semantics exactly.
  Future<void> refresh() async {
    if (_lastLoaded != null &&
        DateTime.now().difference(_lastLoaded!) < _kCacheTtl) {
      return;
    }
    await _loadData(force: false);
  }

  /// Hard refresh: always hits the network regardless of cache age.
  Future<void> forceRefresh() async {
    await _loadData(force: true);
  }

  // ── Episode loading (delegated to AniZipService) ──────────────────────────

  /// Returns episodes for [anilistId] from AniZip.
  /// Results are cached by [AniZipService] for 24 h.
  Future<List<AnimeEpisode>> loadEpisodes(int anilistId) =>
      AniZipService.getEpisodes(anilistId);

  // ── Internal data loading ─────────────────────────────────────────────────

  Future<void> _loadData({bool force = false}) async {
    if (_isRefreshing) return;

    if (!force &&
        _lastLoaded != null &&
        DateTime.now().difference(_lastLoaded!) < _kCacheTtl) {
      return;
    }

    _isRefreshing = true;

    // Only show full loading spinner on first load; keep content for refreshes.
    final isFirstLoad = _trending.isEmpty && _hubs.isEmpty;
    if (isFirstLoad) {
      _state = AnimeLoadState.loading;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      // Fetch all four lists concurrently to minimise wall-clock latency.
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

      final newHubs = <MediaHub>[];

      final season = AniListService.currentSeason();
      final year = AniListService.currentYear();
      final seasonLabel =
          '${season[0]}${season.substring(1).toLowerCase()} $year';

      if (seasonalRaw.isNotEmpty) {
        newHubs.add(MediaHub(
          id: 'anime_seasonal',
          title: 'Season: $seasonLabel',
          type: 'show',
          items: seasonalRaw.map((m) => m.toMediaItem()).toList(),
        ));
      }

      if (popularRaw.isNotEmpty) {
        newHubs.add(MediaHub(
          id: 'anime_popular',
          title: 'All-Time Popular',
          type: 'show',
          items: popularRaw.map((m) => m.toMediaItem()).toList(),
        ));
      }

      if (upcomingRaw.isNotEmpty) {
        newHubs.add(MediaHub(
          id: 'anime_upcoming',
          title: 'Coming Soon',
          type: 'show',
          items: upcomingRaw.map((m) => m.toMediaItem()).toList(),
        ));
      }

      _trending = trendingRaw.map((m) => m.toMediaItem()).toList();
      _hubs = newHubs;
      _loadGeneration++;
      _lastLoaded = DateTime.now();
      _state = AnimeLoadState.loaded;
      _errorMessage = null;
    } catch (e, st) {
      appLogger.e('AnimeProvider: load failed', error: e, stackTrace: st);
      _errorMessage = e.toString();
      if (_trending.isEmpty && _hubs.isEmpty) {
        _state = AnimeLoadState.error;
      }
    } finally {
      _isRefreshing = false;
    }

    notifyListeners();
  }
}
