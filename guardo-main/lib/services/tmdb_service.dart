import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TmdbService {
  TmdbService._();
  static final TmdbService instance = TmdbService._();

  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p';

  String get _apiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) async {
    if (_apiKey.isEmpty) {
      debugPrint('TMDB API Key is missing');
      return {};
    }
    
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: {
      'api_key': _apiKey,
      'language': 'es-ES',
      ...?query,
    });

    try {
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        debugPrint('TMDB HTTP ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('TMDB request failed: $e');
    }
    return {};
  }

  // Helper para mapear TMDB a nuestro formato (AniList-like)
  Map<String, dynamic> _mapToAnilistFormat(Map<String, dynamic> tmdbItem, {String? mediaType}) {
    final type = mediaType ?? tmdbItem['media_type'] ?? 'movie';
    final title = tmdbItem['title'] ?? tmdbItem['name'] ?? 'Desconocido';
    
    final posterPath = tmdbItem['poster_path'];
    final backdropPath = tmdbItem['backdrop_path'];
    
    final posterUrl = posterPath != null ? '$_imageBaseUrl/w500$posterPath' : null;
    final backdropUrl = backdropPath != null ? '$_imageBaseUrl/w1280$backdropPath' : null;
    
    String? logoUrl;
    if (tmdbItem['images'] != null && tmdbItem['images']['logos'] != null) {
      final logos = tmdbItem['images']['logos'] as List;
      // Tratar de buscar logo en español o inglés
      final logo = logos.firstWhere(
        (l) => l['iso_639_1'] == 'es',
        orElse: () => logos.firstWhere(
          (l) => l['iso_639_1'] == 'en',
          orElse: () => logos.isNotEmpty ? logos.first : null,
        ),
      );
      if (logo != null && logo['file_path'] != null) {
        logoUrl = '$_imageBaseUrl/w500${logo['file_path']}';
      }
    }

    String? releaseDate = tmdbItem['release_date'] ?? tmdbItem['first_air_date'];
    int? year;
    if (releaseDate != null && releaseDate.length >= 4) {
      year = int.tryParse(releaseDate.substring(0, 4));
    }

    return {
      'id': tmdbItem['id'],
      'title': {
        'romaji': title,
        'english': title,
        'native': tmdbItem['original_title'] ?? tmdbItem['original_name'],
      },
      'coverImage': {
        'extraLarge': posterUrl,
        'large': posterUrl,
        'color': '#2A2A2A', // Podríamos extraer color, pero por ahora estático
      },
      'bannerImage': backdropUrl,
      'customLogo': logoUrl,
      'description': tmdbItem['overview'],
      'averageScore': tmdbItem['vote_average'] != null ? (tmdbItem['vote_average'] * 10).toInt() : null,
      'format': type == 'tv' ? 'TV' : 'MOVIE',
      'status': tmdbItem['status']?.toString().toUpperCase() ?? 'RELEASING', // TMDB usa 'Returning Series', 'Ended', etc en details
      'seasonYear': year,
      'episodes': tmdbItem['number_of_episodes'], // Solo en TV details
      'startDate': year != null ? {'year': year} : null,
      'genres': (tmdbItem['genres'] as List?)?.map((g) => g['name']).toList() ?? [],
      '_rawTmdb': tmdbItem,
    };
  }

  // 1. Trending (Carousel)
  Future<List<dynamic>> getTrending({String type = 'all', String timeWindow = 'day'}) async {
    final data = await _get('/trending/$type/$timeWindow', query: {'append_to_response': 'images', 'include_image_language': 'es,en,null'});
    final results = data['results'] as List? ?? [];
    
    // Necesitamos hacer peticiones individuales para obtener los logos (append_to_response no funciona bien en listas)
    // Para optimizar, solo sacamos los detalles de los primeros 10
    final limited = results.take(10).toList();
    final enriched = await Future.wait(limited.map((item) async {
      final mediaType = item['media_type'] ?? 'movie';
      final details = await getDetails(item['id'], mediaType);
      return details ?? _mapToAnilistFormat(item, mediaType: mediaType);
    }));

    return enriched;
  }

  // 2. Por categoría (Películas populares, etc)
  Future<List<dynamic>> getSection(String mediaType, String category) async {
    final data = await _get('/$mediaType/$category');
    final results = data['results'] as List? ?? [];
    return results.map((e) => _mapToAnilistFormat(e, mediaType: mediaType)).toList();
  }

  // 3. Detalles con imágenes y episodios
  Future<Map<String, dynamic>?> getDetails(int id, String mediaType) async {
    final data = await _get('/$mediaType/$id', query: {
      'append_to_response': 'images,credits,recommendations,similar',
      'include_image_language': 'es,en,null'
    });
    if (data.isEmpty) return null;
    return _mapToAnilistFormat(data, mediaType: mediaType);
  }

  // 4. Buscar
  Future<List<dynamic>> search(String query) async {
    final data = await _get('/search/multi', query: {'query': query});
    final results = data['results'] as List? ?? [];
    return results
      .where((e) => e['media_type'] == 'movie' || e['media_type'] == 'tv')
      .map((e) => _mapToAnilistFormat(e)).toList();
  }
}
