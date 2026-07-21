import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime_media.dart';
import '../../utils/app_logger.dart';

/// Client for the AniList GraphQL API.
///
/// Endpoint: https://graphql.anilist.co
/// Authentication: Not required for public data (read-only queries).
/// Rate limit: ~90 requests per minute.
class AniListService {
  AniListService._();

  static const String _endpoint = 'https://graphql.anilist.co';

  /// GraphQL fields shared by all media queries.
  static const String _mediaFields = '''
    id
    idMal
    title { romaji english native }
    coverImage { large extraLarge color }
    bannerImage
    episodes
    averageScore
    format
    status
    season
    seasonYear
    genres
    description(asHtml: false)
  ''';

  // ── Public query methods ─────────────────────────────────────────────────

  /// Search anime by text query.
  static Future<List<AnimeMedia>> search(String search, {int perPage = 20}) async {
    const query = r'''
      query SearchAnime($search: String, $perPage: Int) {
        Page(perPage: $perPage) {
          media(
            type: ANIME
            search: $search
            sort: POPULARITY_DESC
            isAdult: false
          ) {
            ''' +
        _mediaFields +
        r'''
          }
        }
      }
    ''';
    return _queryMediaList(query, {'search': search, 'perPage': perPage});
  }

  /// Trending anime right now (sorted by TRENDING_DESC).
  static Future<List<AnimeMedia>> getTrending({
    int page = 1,
    int perPage = 10,
  }) async {
    const query = r'''
      query TrendingAnime($page: Int, $perPage: Int) {
        Page(page: $page, perPage: $perPage) {
          media(
            type: ANIME
            sort: TRENDING_DESC
            status_not: NOT_YET_RELEASED
            isAdult: false
          ) {
            ''' +
        _mediaFields +
        r'''
          }
        }
      }
    ''';
    return _queryMediaList(query, {'page': page, 'perPage': perPage});
  }

  /// Anime airing in the given season/year (sorted by POPULARITY_DESC).
  static Future<List<AnimeMedia>> getSeasonal({
    required String season,
    required int year,
    int perPage = 20,
  }) async {
    const query = r'''
      query SeasonalAnime($season: MediaSeason, $year: Int, $perPage: Int) {
        Page(perPage: $perPage) {
          media(
            type: ANIME
            season: $season
            seasonYear: $year
            sort: POPULARITY_DESC
            isAdult: false
          ) {
            ''' +
        _mediaFields +
        r'''
          }
        }
      }
    ''';
    return _queryMediaList(
      query,
      {'season': season, 'year': year, 'perPage': perPage},
    );
  }

  /// All-time most popular anime.
  static Future<List<AnimeMedia>> getPopular({int perPage = 20}) async {
    const query = r'''
      query PopularAnime($perPage: Int) {
        Page(perPage: $perPage) {
          media(
            type: ANIME
            sort: POPULARITY_DESC
            isAdult: false
          ) {
            ''' +
        _mediaFields +
        r'''
          }
        }
      }
    ''';
    return _queryMediaList(query, {'perPage': perPage});
  }

  /// Upcoming (not yet released) anime sorted by popularity.
  static Future<List<AnimeMedia>> getUpcoming({int perPage = 15}) async {
    const query = r'''
      query UpcomingAnime($perPage: Int) {
        Page(perPage: $perPage) {
          media(
            type: ANIME
            status: NOT_YET_RELEASED
            sort: POPULARITY_DESC
            isAdult: false
          ) {
            ''' +
        _mediaFields +
        r'''
          }
        }
      }
    ''';
    return _queryMediaList(query, {'perPage': perPage});
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static Future<List<AnimeMedia>> _queryMediaList(
    String query,
    Map<String, dynamic> variables,
  ) async {
    try {
      final body = jsonEncode({'query': query, 'variables': variables});
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        appLogger.w(
          'AniList: HTTP ${response.statusCode} — ${response.body.substring(0, 200.clamp(0, response.body.length))}',
        );
        return [];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['errors'] != null) {
        appLogger.w('AniList: GraphQL errors — ${decoded['errors']}');
        return [];
      }

      final pageData =
          decoded['data']?['Page'] as Map<String, dynamic>?;
      final mediaList =
          (pageData?['media'] as List<dynamic>?) ?? [];

      return mediaList
          .whereType<Map<String, dynamic>>()
          .map(AnimeMedia.fromJson)
          .toList();
    } catch (e, st) {
      appLogger.e('AniList: query failed', error: e, stackTrace: st);
      return [];
    }
  }

  // ── Season helpers ───────────────────────────────────────────────────────

  /// Returns the current AniList season string (WINTER|SPRING|SUMMER|FALL).
  static String currentSeason() {
    final month = DateTime.now().month;
    return switch (month) {
      1 || 2 || 3 => 'WINTER',
      4 || 5 || 6 => 'SPRING',
      7 || 8 || 9 => 'SUMMER',
      _ => 'FALL',
    };
  }

  static int currentYear() => DateTime.now().year;
}
