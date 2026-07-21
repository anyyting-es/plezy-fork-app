import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime_episode.dart';
import '../../utils/app_logger.dart';

/// Client for the AniZip REST API.
///
/// Endpoint: https://api.ani.zip/mappings?anilist_id={id}
/// No authentication or rate-limit documentation exists.
/// Response: JSON with `episodes` map keyed by episode number string.
class AniZipService {
  AniZipService._();

  static const String _baseUrl = 'https://api.ani.zip/mappings';

  /// In-memory episode cache.  Key = anilist_id → (episodes, loadedAt).
  /// Persists for the lifetime of the app process — entries are cheap.
  static final Map<int, _CacheEntry> _cache = {};
  static const Duration _cacheTtl = Duration(hours: 24);

  static final Map<int, int> _anidbIdCache = {};

  static int? getAnidbAid(int anilistId) => _anidbIdCache[anilistId];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the sorted episode list for [anilistId].
  ///
  /// Results are cached for [_cacheTtl]. Returns an empty list when AniZip
  /// has no data for the requested anime (404 or missing episodes key).
  static Future<List<AnimeEpisode>> getEpisodes(int anilistId) async {
    // 1. Check cache
    final cached = _cache[anilistId];
    if (cached != null &&
        DateTime.now().difference(cached.loadedAt) < _cacheTtl) {
      return cached.episodes;
    }

    // 2. Fetch from AniZip
    try {
      final uri =
          Uri.parse('$_baseUrl?anilist_id=$anilistId');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        // Anime not in AniZip database — cache empty result to avoid hammering
        _cache[anilistId] =
            _CacheEntry(episodes: const [], loadedAt: DateTime.now());
        return const [];
      }

      if (response.statusCode != 200) {
        appLogger.w(
          'AniZip: HTTP ${response.statusCode} for anilist_id=$anilistId',
        );
        return const [];
      }

      // 3. Parse
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      
      final mappings = decoded['mappings'] as Map<String, dynamic>?;
      if (mappings != null) {
        final aidVal = mappings['anidb_id'];
        if (aidVal is num) {
          _anidbIdCache[anilistId] = aidVal.toInt();
        } else if (aidVal != null) {
          final parsedAid = int.tryParse(aidVal.toString());
          if (parsedAid != null) {
            _anidbIdCache[anilistId] = parsedAid;
          }
        }
      }

      final episodesMap =
          decoded['episodes'] as Map<String, dynamic>?;

      if (episodesMap == null || episodesMap.isEmpty) {
        _cache[anilistId] =
            _CacheEntry(episodes: const [], loadedAt: DateTime.now());
        return const [];
      }

      final episodes = episodesMap.entries
          .map((entry) {
            final data = entry.value;
            if (data is! Map<String, dynamic>) return null;

            // Only allow regular chapter episodes (numeric keys > 0)
            final keyInt = int.tryParse(entry.key);
            if (keyInt == null || keyInt <= 0) return null;

            final ep = AnimeEpisode.fromJson(entry.key, data);

            // Double check: ensure episode number and absolute episode number are positive
            if (ep.episodeNumber <= 0 || ep.absoluteEpisodeNumber <= 0) return null;

            return ep;
          })
          .whereType<AnimeEpisode>()
          .toList()
        // Sort by absolute episode number so multi-season series display correctly
        ..sort(
          (a, b) =>
              a.absoluteEpisodeNumber.compareTo(b.absoluteEpisodeNumber),
        );

      // 4. Store + return
      _cache[anilistId] =
          _CacheEntry(episodes: episodes, loadedAt: DateTime.now());
      return episodes;
    } catch (e, st) {
      appLogger.e(
        'AniZip: failed to load episodes for anilist_id=$anilistId',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  /// Evicts a specific entry from the in-memory cache (e.g. force refresh).
  static void evict(int anilistId) => _cache.remove(anilistId);

  /// Clears all cached entries.
  static void clearAll() => _cache.clear();
}

class _CacheEntry {
  final List<AnimeEpisode> episodes;
  final DateTime loadedAt;

  const _CacheEntry({required this.episodes, required this.loadedAt});
}
