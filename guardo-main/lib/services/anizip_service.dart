import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AnizipEpisode {
  final int episodeNumber;
  final bool isSpecial;
  final int? absoluteEpisodeNumber;
  final String title;
  final String? overview;
  final String? image;
  final int? seasonNumber;
  final String? airDate;
  final int? runtime;

  AnizipEpisode({
    required this.episodeNumber,
    this.isSpecial = false,
    this.absoluteEpisodeNumber,
    required this.title,
    this.overview,
    this.image,
    this.seasonNumber,
    this.airDate,
    this.runtime,
  });

  factory AnizipEpisode.fromJson(String key, Map<String, dynamic> json) {
    final isSpecial = key.startsWith('S');
    final episodeNumber = json['episodeNumber'] as int? ?? 
                         int.tryParse(isSpecial ? key.substring(1) : key) ?? 0;

    final titleRaw = json['title'];
    String title;
    if (titleRaw is Map) {
      title = (titleRaw['en'] as String?) ??
          (titleRaw['x-jat'] as String?) ??
          (titleRaw['ja'] as String?) ??
          'Episode $key';
    } else if (titleRaw is String) {
      title = titleRaw;
    } else {
      title = 'Episode $key';
    }

    return AnizipEpisode(
      episodeNumber: episodeNumber,
      isSpecial: isSpecial,
      absoluteEpisodeNumber: json['absoluteEpisodeNumber'] as int?,
      title: title,
      overview: json['overview'] as String?,
      image: json['image'] as String?,
      seasonNumber: json['seasonNumber'] as int?,
      airDate: json['airDate'] as String?,
      runtime: json['runtime'] as int?,
    );
  }
}

class AnizipResponse {
  final Map<String, String> titles;
  final Map<String, AnizipEpisode> episodes;
  final int episodeCount;
  final int specialCount;
  final List<AnizipImage> images;
  final Map<String, dynamic>? mappings;

  AnizipResponse({
    required this.titles,
    required this.episodes,
    required this.episodeCount,
    required this.specialCount,
    required this.images,
    this.mappings,
  });

  factory AnizipResponse.fromJson(Map<String, dynamic> json) {
    final titlesRaw = json['titles'] as Map<String, dynamic>? ?? {};
    final titles = <String, String>{};
    titlesRaw.forEach((k, v) => titles[k] = v?.toString() ?? '');

    final episodesRaw = json['episodes'] as Map<String, dynamic>? ?? {};
    final episodes = <String, AnizipEpisode>{};
    episodesRaw.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        episodes[key] = AnizipEpisode.fromJson(key, value);
      }
    });

    final images = (json['images'] as List<dynamic>?)
        ?.map((e) => AnizipImage.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    return AnizipResponse(
      titles: titles,
      episodes: episodes,
      episodeCount: (json['episodeCount'] as num?)?.toInt() ?? 0,
      specialCount: (json['specialCount'] as num?)?.toInt() ?? 0,
      images: images,
      mappings: json['mappings'] as Map<String, dynamic>?,
    );
  }
}

class AnizipImage {
  final String coverType;
  final String url;

  AnizipImage({required this.coverType, required this.url});

  factory AnizipImage.fromJson(Map<String, dynamic> json) {
    return AnizipImage(
      coverType: json['coverType'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

class AnizipService {
  AnizipService._();
  static final AnizipService instance = AnizipService._();

  static const String _baseUrl = 'https://api.ani.zip';
  static final Map<int, AnizipResponse> _episodesCache = {};

  AnizipResponse? getCachedEpisodes(int anilistId) => _episodesCache[anilistId];

  Future<AnizipResponse?> getAnime(int anilistId) async {
    if (_episodesCache.containsKey(anilistId)) {
      return _episodesCache[anilistId];
    }
    try {
      final url = Uri.parse('$_baseUrl/mappings?anilist_id=$anilistId');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final response = AnizipResponse.fromJson(jsonDecode(res.body));
        _episodesCache[anilistId] = response;
        return response;
      }
      debugPrint('AniZip: ${res.statusCode} for id $anilistId');
    } catch (e) {
      debugPrint('AniZip error: $e');
    }
    return null;
  }
}
