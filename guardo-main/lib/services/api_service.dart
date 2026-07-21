import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/app_models.dart';
import '../providers/torrent_provider.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const String _anilistBase = 'https://graphql.anilist.co';

  final _torrent = TorrentProvider();
  TorrentProvider get torrent => _torrent;

  // ─── ANILIST GRAPHQL ───────────────────────────────────────────

  Future<Map<String, dynamic>> _post(String query, Map<String, dynamic> variables) async {
    try {
      final res = await http.post(
        Uri.parse(_anilistBase),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'query': query, 'variables': variables}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body.containsKey('errors')) {
          debugPrint('AniList errors: ${body['errors']}');
          return {};
        }
        return body;
      } else {
        debugPrint('AniList HTTP ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('AniList request failed: $e');
    }
    return {};
  }

  /// Fetch a page of media (anime or manga).
  Future<AnilistPage> fetchPage({
    String? search,
    required bool isManga,
    List<String>? genres,
    String? format,
    String? status,
    int? year,
    String? season,
    List<String>? sort,
    int page = 1,
    int perPage = 20,
  }) async {
    const gql = r'''
      query ($search: String, $page: Int, $perPage: Int, $type: MediaType, $sort: [MediaSort], $genre: [String], $format: MediaFormat, $status: MediaStatus, $year: Int, $season: MediaSeason) {
        Page(page: $page, perPage: $perPage) {
          pageInfo { total currentPage lastPage hasNextPage perPage }
          media(search: $search, type: $type, sort: $sort, genre_in: $genre, format: $format, status: $status, seasonYear: $year, season: $season) {
            id idMal title { romaji english native }
            coverImage { extraLarge large color }
            bannerImage description averageScore genres synonyms
            format status season seasonYear episodes chapters volumes
            startDate { year month day }
          }
        }
      }
    ''';

    final variables = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      'type': isManga ? 'MANGA' : 'ANIME',
      'sort': sort ?? ['TRENDING_DESC'],
    };
    if (search != null && search.isNotEmpty) variables['search'] = search;
    if (genres != null && genres.isNotEmpty) variables['genre'] = genres;
    if (format != null && format.isNotEmpty) variables['format'] = format;
    if (status != null && status.isNotEmpty) variables['status'] = status;
    if (year != null && year > 0) variables['year'] = year;
    if (season != null && season.isNotEmpty) variables['season'] = season;

    final data = await _post(gql, variables);
    final pageData = data['data']?['Page'];
    if (pageData == null) {
      debugPrint('AniList fetchPage returned null data for search="$search" page=$page');
      return AnilistPage.empty();
    }
    return AnilistPage.fromJson(pageData);
  }

  static final Map<int, Map<String, dynamic>> _mediaCache = {};
  static final Map<int, ManhwaDetails> _manhwaDetailsCache = {};

  Map<String, dynamic>? getCachedMedia(int id) => _mediaCache[id];
  ManhwaDetails? getCachedManhwaDetails(int id) => _manhwaDetailsCache[id];

  void cacheMedia(int id, Map<String, dynamic> data) {
    _mediaCache[id] = data;
  }

  void cacheManhwaDetails(int id, ManhwaDetails details) {
    _manhwaDetailsCache[id] = details;
  }

  /// Fetch a single media by ID.
  Future<Map<String, dynamic>?> fetchMediaById(int id, {bool isManga = false}) async {
    if (_mediaCache.containsKey(id) && _mediaCache[id]!.containsKey('relations')) {
      return _mediaCache[id];
    }
    const gql = r'''
      query ($id: Int, $type: MediaType) {
        Media(id: $id, type: $type) {
          id idMal title { romaji english native }
          coverImage { extraLarge large color }
          bannerImage description averageScore genres synonyms
          format status season seasonYear episodes chapters volumes duration
          startDate { year month day }
          endDate { year month day }
          nextAiringEpisode { airingAt timeUntilAiring episode }
          studios { nodes { name } }
          characters(sort: ROLE, perPage: 12) { nodes { name { full } image { large } } }
          recommendations { nodes { mediaRecommendation { id title { romaji english } coverImage { large } type } } }
          relations { edges { node { id title { romaji english } coverImage { large } type } relationType } }
        }
      }
    ''';

    final data = await _post(gql, {
      'id': id,
      'type': isManga ? 'MANGA' : 'ANIME',
    });
    final media = data['data']?['Media'] as Map<String, dynamic>?;
    if (media != null) {
      _mediaCache[id] = media;
    }
    return media;
  }

  /// Batch fetch anime by IDs (for carousel enrichment).
  Future<List<dynamic>> fetchAnimesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    const gql = r'''
      query ($ids: [Int]) {
        Page {
          media(id_in: $ids, type: ANIME) {
            id idMal title { romaji english native }
            coverImage { extraLarge large color }
            bannerImage description averageScore genres synonyms
            format status season seasonYear episodes
          }
        }
      }
    ''';

    final data = await _post(gql, {'ids': ids});
    return (data['data']?['Page']?['media'] as List?) ?? [];
  }

  // ─── MANGADEX ─────────────────────────────────────────────────

  static const String _manhwaBase = 'https://api.mangadex.org';

  Future<List<dynamic>> manhwaSearch(String query) async {
    final url = '$_manhwaBase/manga?title=$query&limit=5&includes[]=cover_art';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List list = data['data'] ?? [];
        return list.map((m) {
          final attr = m['attributes'] ?? {};
          final rels = m['relationships'] as List? ?? [];
          final coverRel = rels.firstWhere((r) => r['type'] == 'cover_art', orElse: () => null);
          String? cover;
          if (coverRel != null && coverRel['attributes'] != null) {
            cover = 'https://uploads.mangadex.org/covers/${m['id']}/${coverRel['attributes']['fileName']}';
          }
          return {
            'id': m['id'],
            'title': attr['title']?['en'] ?? attr['title']?['ja-ro'] ?? 'No Title',
            'slug': m['id'],
            'image': cover,
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<ManhwaDetails?> manhwaGetDetails(String id, {String? slug}) async {
    final url = '$_manhwaBase/manga/$id?includes[]=cover_art';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        final attr = data['attributes'];
        final rels = data['relationships'] as List? ?? [];
        final coverRel = rels.firstWhere((r) => r['type'] == 'cover_art', orElse: () => null);
        String image = '';
        if (coverRel != null && coverRel['attributes'] != null) {
          image = 'https://uploads.mangadex.org/covers/$id/${coverRel['attributes']['fileName']}';
        }

        final feedUrl = '$_manhwaBase/manga/$id/feed?translatedLanguage[]=en&limit=100&order[chapter]=desc';
        final feedRes = await http.get(Uri.parse(feedUrl));
        final List chapters = [];
        if (feedRes.statusCode == 200) {
          final feedData = jsonDecode(feedRes.body)['data'] as List? ?? [];
          for (var ch in feedData) {
            final cattr = ch['attributes'];
            chapters.add({
              'id': ch['id'],
              'number': double.tryParse(cattr['chapter'] ?? '0') ?? 0.0,
              'title': cattr['title'] ?? 'Chapter ${cattr['chapter']}',
            });
          }
        }

        return ManhwaDetails(
          id: id,
          slug: id,
          title: attr['title']?['en'] ?? attr['title']?['ja-ro'] ?? '',
          image: image,
          description: attr['description']?['en'] ?? '',
          status: attr['status'] ?? '',
          type: 'manga',
          genres: (attr['tags'] as List? ?? []).map((t) => t['attributes']?['name']?['en']?.toString() ?? '').where((t) => t.isNotEmpty).toList(),
          chapters: chapters.cast<Map<String, dynamic>>(),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> manhwaGetChapterPages(String mangaId, String chapterId) async {
    final url = '$_manhwaBase/at-home/server/$chapterId';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final baseUrl = data['baseUrl'];
        final hash = data['chapter']['hash'];
        final List files = data['chapter']['data'] ?? [];
        return files.map((f) => '$baseUrl/data/$hash/$f').toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── CONSTANTS ─────────────────────────────────────────────────

  static const List<String> genreOptions = [
    'Action', 'Adventure', 'Comedy', 'Drama', 'Ecchi',
    'Fantasy', 'Horror', 'Mahou Shoujo', 'Mecha', 'Music',
    'Mystery', 'Psychological', 'Romance', 'Sci-Fi',
    'Slice of Life', 'Sports', 'Supernatural', 'Thriller',
  ];

  static const Map<String, String> mangaSectionQueries = {
    'trending': 'TRENDING_DESC',
    'popular': 'POPULARITY_DESC',
    'manhwa': 'manhwa',
    'action': 'action',
    'romance': 'romance',
    'fantasy': 'fantasy',
    'comedy': 'comedy',
  };
}

class AnilistPage {
  final int total;
  final int currentPage;
  final int lastPage;
  final bool hasNextPage;
  final int perPage;
  final List<dynamic> media;

  AnilistPage({
    required this.total,
    required this.currentPage,
    required this.lastPage,
    required this.hasNextPage,
    required this.perPage,
    required this.media,
  });

  factory AnilistPage.fromJson(Map<String, dynamic> json) {
    final info = json['pageInfo'] as Map<String, dynamic>? ?? {};
    return AnilistPage(
      total: (info['total'] as num?)?.toInt() ?? 0,
      currentPage: (info['currentPage'] as num?)?.toInt() ?? 1,
      lastPage: (info['lastPage'] as num?)?.toInt() ?? 1,
      hasNextPage: info['hasNextPage'] as bool? ?? false,
      perPage: (info['perPage'] as num?)?.toInt() ?? 20,
      media: (json['media'] as List?) ?? [],
    );
  }

  factory AnilistPage.empty() => AnilistPage(
    total: 0,
    currentPage: 1,
    lastPage: 1,
    hasNextPage: false,
    perPage: 20,
    media: [],
  );
}
