import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/app_models.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/anizip_service.dart';
import '../../../services/tmdb_service.dart';
import '../../../providers/torrent_provider.dart';

class AnimeDetailController extends ChangeNotifier {
  AnimeDetailController({
    required this.animeId,
    this.resume,
  });

  final int animeId; // AniList ID
  final WatchEntry? resume;

  final _api = ApiService.instance;
  final _anizip = AnizipService.instance;
  final _storage = StorageService.instance;
  TorrentProvider get torrentProvider => _api.torrent;

  // AniList data
  Map<String, dynamic>? anime;
  bool loading = true;

  // AniZip data
  AnizipResponse? anizip;
  List<EpisodeInfo> episodes = [];
  bool loadingEpisodes = true;

  // Settings
  AppSettings settings = AppSettings.defaults();

  // Torrent downloads
  Map<int, TorrentBackendInfo> activeDownloads = {};
  Timer? _downloadTimer;

  // Watch entry
  WatchEntry? watchEntry;
  bool isFavorite = false;

  bool _isDisposed = false;

  void init() {
    final cached = _api.getCachedMedia(animeId);
    if (cached != null) {
      anime = cached;
      loading = false;
    } else if (resume != null) {
      anime = {
        'id': animeId,
        'title': {
          'romaji': resume!.animeTitleRomaji,
          'english': resume!.animeTitleEnglish ?? resume!.animeTitleRomaji,
        },
        'coverImage': {
          'extraLarge': resume!.animeCover,
          'large': resume!.animeCover,
        },
        'bannerImage': resume!.animeBanner,
        'episodes': resume!.totalEpisodes,
        'status': resume!.animeStatus,
      };
      loading = false;
      _api.cacheMedia(animeId, anime!);
    } else {
      loading = true;
    }

    final cachedEpisodes = _anizip.getCachedEpisodes(animeId);
    if (cachedEpisodes != null) {
      anizip = cachedEpisodes;
      episodes = _parseEpisodes(cachedEpisodes);
      loadingEpisodes = false;
    } else {
      loadingEpisodes = true;
    }

    load();
    _startDownloadPolling();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _downloadTimer?.cancel();
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  List<EpisodeInfo> _parseEpisodes(AnizipResponse result) {
    final format = anime != null ? ((anime!['format'] as String?) ?? '').toUpperCase() : '';

    if (format == 'MOVIE') {
      return [
        EpisodeInfo(
          id: 'anilist-$animeId-1',
          number: 1,
          title: anime?['title']?['romaji'] ?? 'Película',
          description: anime?['description'] as String?,
          image: anime?['coverImage']?['large'] as String?,
        ),
      ];
    } else {
      // Filter out specials and sort episodes by episode number
      final regularEpisodes = result.episodes.values.where((e) => !e.isSpecial).toList()
        ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

      // Get next airing episode info from AniList to estimate future dates
      final nextAiring = anime?['nextAiringEpisode'];
      DateTime? nextAiringDate;
      int? nextAiringEp;
      if (nextAiring != null) {
        nextAiringDate = DateTime.fromMillisecondsSinceEpoch((nextAiring['airingAt'] as int) * 1000);
        nextAiringEp = (nextAiring['episode'] as num?)?.toInt();
      }

      return regularEpisodes.map((ep) {
        String? airDate = ep.airDate;

        // Estimate if missing and we have nextAiring info
        if ((airDate == null || airDate.isEmpty) && nextAiringDate != null && nextAiringEp != null) {
          final diff = ep.episodeNumber - nextAiringEp!;
          final estimatedDate = nextAiringDate!.add(Duration(days: (7 * diff).toInt()));
          airDate = estimatedDate.toIso8601String().split('T')[0];
        }

        return EpisodeInfo(
          id: 'anizip-$animeId-${ep.episodeNumber}',
          number: ep.episodeNumber,
          title: ep.title,
          description: ep.overview,
          image: ep.image,
          airDate: airDate,
        );
      }).toList();
    }
  }

  Future<void> load() async {
    if (anime == null) {
      loading = true;
    }
    if (episodes.isEmpty) {
      loadingEpisodes = true;
    }
    _safeNotify();

    settings = await _storage.getAppSettings();
    watchEntry = await _storage.getWatchEntry(animeId);

    // Fetch data
    if (settings.metadataSource == 'tmdb') {
      String mediaType = 'tv';
      if (anime != null && anime!['format'] == 'MOVIE') {
        mediaType = 'movie';
      }
      final data = await TmdbService.instance.getDetails(animeId, mediaType);
      if (data == null && anime == null) {
        final otherData = await TmdbService.instance.getDetails(animeId, 'movie');
        if (otherData != null) anime = otherData;
      } else if (data != null) {
        anime = data;
      }
    } else {
      final data = await _api.fetchMediaById(animeId);
      if (data != null) {
        anime = data;
      }
    }

    loading = false;
    _safeNotify();

    // Load favorite status
    await loadFavoriteStatus();

    if (anime != null) {
      if (settings.metadataSource == 'tmdb') {
         // Generar episodios dummy para TMDB (hasta soportar temporadas complejas)
         final format = anime!['format'];
         if (format == 'MOVIE') {
            episodes = [
              EpisodeInfo(
                id: 'tmdb-$animeId-1',
                number: 1,
                title: anime?['title']?['romaji'] ?? 'Película',
                description: anime?['description'] as String?,
                image: anime?['bannerImage'] as String?,
              )
            ];
         } else {
            final epCount = (anime?['episodes'] as num?)?.toInt() ?? 1;
            episodes = List.generate(epCount, (i) => EpisodeInfo(
              id: 'tmdb-$animeId-${i + 1}',
              number: i + 1,
              title: 'Episodio ${i + 1}',
              description: null,
              image: anime?['bannerImage'] as String?,
            ));
         }
         loadingEpisodes = false;
         _safeNotify();
      } else {
         await _loadEpisodesFromAnizip();
      }
    } else {
      loadingEpisodes = false;
      _safeNotify();
    }
  }

  Future<void> _loadEpisodesFromAnizip() async {
    if (episodes.isEmpty) {
      loadingEpisodes = true;
      _safeNotify();
    }

    final result = await _anizip.getAnime(animeId);
    anizip = result;

    if (result != null) {
      episodes = _parseEpisodes(result);
    } else {
      // Fallback: use episode count from AniList
      final epCount = (anime?['episodes'] as num?)?.toInt() ?? 0;
      if (epCount > 0) {
        episodes = List.generate(epCount, (i) => EpisodeInfo(
          id: 'anilist-$animeId-${i + 1}',
          number: i + 1,
          title: 'Episodio ${i + 1}',
          description: null,
          image: anime?['coverImage']?['large'] as String?,
        ));
      }
    }

    loadingEpisodes = false;
    _safeNotify();
  }

  void _startDownloadPolling() {
    _downloadTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (activeDownloads.isEmpty || _isDisposed) return;
      bool changed = false;
      final updated = Map<int, TorrentBackendInfo>.from(activeDownloads);
      for (final entry in activeDownloads.entries) {
        final info = await torrentProvider.getTorrentInfo(entry.value.infoHash);
        if (info != null) {
          updated[entry.key] = info;
          changed = true;
        }
      }
      if (changed) {
        activeDownloads = updated;
        _safeNotify();
      }
    });
  }

  Future<void> refreshWatchEntry() async {
    watchEntry = await _storage.getWatchEntry(animeId);
    _safeNotify();
  }

  Future<void> loadFavoriteStatus() async {
    isFavorite = await _storage.isFavorite(animeId);
    _safeNotify();
  }

  Future<bool> toggleFavorite() async {
    if (anime == null) return false;
    isFavorite = await _storage.toggleFavorite(anime!);
    _safeNotify();
    return isFavorite;
  }

  void addActiveDownload(int epNum, TorrentBackendInfo info) {
    activeDownloads[epNum] = info;
    _safeNotify();
  }
}
