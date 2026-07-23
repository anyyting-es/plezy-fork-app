import 'dart:convert';
import 'package:http/http.dart' as http;
import '../media/media_item.dart';
import '../media/media_kind.dart';
import '../utils/app_logger.dart';

/// Client for the TMDB REST API (The Movie Database).
///
/// Endpoint: https://api.themoviedb.org/3
/// Authentication: Query parameter API Key.
class TmdbService {
  TmdbService._();

  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _apiKey = '11f51d424de962a06b01b8bec43d9afa';

  static const Map<int, String> _genreMap = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Science Fiction',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
    10759: 'Action & Adventure',
    10762: 'Kids',
    10763: 'News',
    10764: 'Reality',
    10765: 'Sci-Fi & Fantasy',
    10766: 'Soap',
    10767: 'Talk',
    10768: 'War & Politics',
  };

  static List<String> _mapGenreIds(List<dynamic>? ids) {
    if (ids == null) return const [];
    return ids.map((id) => _genreMap[id] ?? 'Other').where((g) => g != 'Other').toList();
  }

  static String? _imagePath(String? path, String size) {
    if (path == null || path.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  // ── Public API Methods ───────────────────────────────────────────────────

  /// Fetch trending movies and TV shows for the main carousel (Spotlight).
  static Future<List<MediaItem>> getTrending({int page = 1}) async {
    try {
      final uri = Uri.parse('$_baseUrl/trending/all/day?api_key=$_apiKey&page=$page&language=es-ES');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        appLogger.w('TMDB: Failed to load trending, status code ${response.statusCode}');
        return const [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? const [];
      return results.map((item) => _parseMediaItem(item)).whereType<MediaItem>().toList();
    } catch (e, st) {
      appLogger.e('TMDB: Error fetching trending', error: e, stackTrace: st);
      return const [];
    }
  }

  /// Fetch popular movies.
  static Future<List<MediaItem>> getPopularMovies({int page = 1}) async {
    return _fetchSection('/movie/popular', MediaKind.movie, page);
  }

  /// Fetch popular TV shows.
  static Future<List<MediaItem>> getPopularTv({int page = 1}) async {
    return _fetchSection('/tv/popular', MediaKind.show, page);
  }

  /// Fetch now playing movies (recent releases).
  static Future<List<MediaItem>> getRecentMovies({int page = 1}) async {
    return _fetchSection('/movie/now_playing', MediaKind.movie, page);
  }

  /// Fetch TV shows airing today.
  static Future<List<MediaItem>> getAiringTodayTv({int page = 1}) async {
    return _fetchSection('/tv/airing_today', MediaKind.show, page);
  }

  /// Search movies and TV shows.
  static Future<List<MediaItem>> search(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return const [];
    try {
      final uri = Uri.parse('$_baseUrl/search/multi?api_key=$_apiKey&query=${Uri.encodeComponent(query)}&page=$page&language=es-ES&include_adult=false');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        appLogger.w('TMDB: Search failed, status code ${response.statusCode}');
        return const [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? const [];
      return results.map((item) => _parseMediaItem(item)).whereType<MediaItem>().toList();
    } catch (e, st) {
      appLogger.e('TMDB: Search error', error: e, stackTrace: st);
      return const [];
    }
  }

  /// Get details of a single Movie or TV Show.
  static Future<MediaItem?> getDetails(String id, MediaKind kind) async {
    try {
      final tmdbId = id.startsWith('tmdb_') ? id.substring('tmdb_'.length) : id;
      final typePath = kind == MediaKind.movie ? 'movie' : 'tv';
      final uri = Uri.parse('$_baseUrl/$typePath/$tmdbId?api_key=$_apiKey&language=es-ES&append_to_response=credits,recommendations,external_ids');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        appLogger.w('TMDB: Details load failed for $id, status code ${response.statusCode}');
        return null;
      }

      final item = json.decode(response.body) as Map<String, dynamic>;
      return _parseMediaItem(item, forceKind: kind);
    } catch (e, st) {
      appLogger.e('TMDB: Details error for $id', error: e, stackTrace: st);
      return null;
    }
  }

  /// Fetch seasons of a TV show.
  static Future<List<MediaItem>> getSeasons(String showId) async {
    try {
      final tmdbId = showId.startsWith('tmdb_') ? showId.substring('tmdb_'.length) : showId;
      final uri = Uri.parse('$_baseUrl/tv/$tmdbId?api_key=$_apiKey&language=es-ES');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        appLogger.w('TMDB: Seasons load failed for $showId, status code ${response.statusCode}');
        return const [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final seasonsRaw = data['seasons'] as List<dynamic>? ?? const [];
      
      return seasonsRaw.map((s) {
        final seasonMap = s as Map<String, dynamic>;
        final seasonNum = seasonMap['season_number'] as int? ?? 1;
        // Skip season 0 (Specials/Extras) for clean layout unless it has items
        if (seasonNum == 0 && (seasonMap['episode_count'] as int? ?? 0) == 0) return null;
        
        return MediaItem.tmdb(
          id: 'tmdb_season_${tmdbId}_$seasonNum',
          kind: MediaKind.season,
          title: seasonMap['name'] as String? ?? 'Temporada $seasonNum',
          index: seasonNum,
          parentIndex: seasonNum,
          parentId: 'tmdb_$tmdbId',
          thumbPath: _imagePath(seasonMap['poster_path'] as String?, 'w500'),
          artPath: _imagePath(data['backdrop_path'] as String?, 'w1280'),
          leafCount: seasonMap['episode_count'] as int?,
        );
      }).whereType<MediaItem>().toList();
    } catch (e, st) {
      appLogger.e('TMDB: Seasons load error for $showId', error: e, stackTrace: st);
      return const [];
    }
  }

  /// Fetch episodes for a specific season of a TV show.
  static Future<List<MediaItem>> getSeasonEpisodes({required String showId, required int seasonNumber}) async {
    try {
      final tmdbId = showId.startsWith('tmdb_') ? showId.substring('tmdb_'.length) : showId;
      final uri = Uri.parse('$_baseUrl/tv/$tmdbId/season/$seasonNumber?api_key=$_apiKey&language=es-ES');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        appLogger.w('TMDB: Season episodes failed for $showId Season $seasonNumber, status code ${response.statusCode}');
        return const [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final episodesRaw = data['episodes'] as List<dynamic>? ?? const [];
      
      return episodesRaw.map((e) {
        final epMap = e as Map<String, dynamic>;
        final epNum = epMap['episode_number'] as int? ?? 1;
        return MediaItem.tmdb(
          id: 'tmdb_ep_${tmdbId}_${seasonNumber}_$epNum',
          kind: MediaKind.episode,
          title: epMap['name'] as String? ?? 'Episodio $epNum',
          index: epNum,
          parentIndex: seasonNumber,
          parentId: 'tmdb_season_${tmdbId}_$seasonNumber',
          grandparentId: 'tmdb_$tmdbId',
          summary: epMap['overview'] as String?,
          thumbPath: _imagePath(epMap['still_path'] as String?, 'w500'),
          originallyAvailableAt: epMap['air_date'] as String?,
          durationMs: epMap['runtime'] != null ? (epMap['runtime'] as int) * 60000 : null,
        );
      }).toList();
    } catch (e, st) {
      appLogger.e('TMDB: Episodes load error for $showId S$seasonNumber', error: e, stackTrace: st);
      return const [];
    }
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  static Future<List<MediaItem>> _fetchSection(String endpoint, MediaKind kind, int page) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint?api_key=$_apiKey&page=$page&language=es-ES');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        appLogger.w('TMDB: Failed to load $endpoint, status code ${response.statusCode}');
        return const [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? const [];
      return results.map((item) => _parseMediaItem(item, forceKind: kind)).whereType<MediaItem>().toList();
    } catch (e, st) {
      appLogger.e('TMDB: Error fetching $endpoint', error: e, stackTrace: st);
      return const [];
    }
  }

  static MediaItem? _parseMediaItem(dynamic jsonMap, {MediaKind? forceKind}) {
    if (jsonMap is! Map<String, dynamic>) return null;

    final id = jsonMap['id'] as int;
    final mediaType = jsonMap['media_type'] as String?;
    
    MediaKind kind = MediaKind.movie;
    if (forceKind != null) {
      kind = forceKind;
    } else if (mediaType == 'tv') {
      kind = MediaKind.show;
    } else if (mediaType == 'movie') {
      kind = MediaKind.movie;
    } else {
      // Default guess if media_type is omitted (some section endpoints)
      final hasName = jsonMap.containsKey('name') || jsonMap.containsKey('first_air_date');
      kind = hasName ? MediaKind.show : MediaKind.movie;
    }

    final title = jsonMap['title'] as String? ?? jsonMap['name'] as String? ?? '';
    if (title.isEmpty) return null;

    final releaseDate = jsonMap['release_date'] as String? ?? jsonMap['first_air_date'] as String?;
    int? year;
    if (releaseDate != null && releaseDate.length >= 4) {
      year = int.tryParse(releaseDate.substring(0, 4));
    }

    final rating = (jsonMap['vote_average'] as num?)?.toDouble();
    final genres = _mapGenreIds(jsonMap['genre_ids'] as List<dynamic>?);

    String? imdbId = jsonMap['imdb_id'] as String?;
    if (imdbId == null && jsonMap['external_ids'] is Map) {
      imdbId = jsonMap['external_ids']['imdb_id'] as String?;
    }
    final guid = imdbId != null && imdbId.isNotEmpty ? 'imdb://$imdbId' : null;

    return MediaItem.tmdb(
      id: 'tmdb_$id',
      kind: kind,
      guid: guid,
      title: title,
      summary: jsonMap['overview'] as String?,
      tagline: jsonMap['tagline'] as String?,
      thumbPath: _imagePath(jsonMap['poster_path'] as String?, 'w500'),
      artPath: _imagePath(jsonMap['backdrop_path'] as String?, 'w1280'),
      year: year,
      originallyAvailableAt: releaseDate,
      rating: rating,
      genres: genres.isNotEmpty ? genres : null,
    );
  }
}
