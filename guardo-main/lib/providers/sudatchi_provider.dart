import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import 'video_provider.dart';

class SudatchiProvider implements VideoProvider {
  static const _baseUrl = 'https://sudatchi.com';

  @override
  String get id => 'sudatchi';

  @override
  String get name => 'Sudatchi';

  Future<dynamic> _getJson(String url, {Map<String, String>? headers}) async {
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Referer': '$_baseUrl/',
          ...?headers,
        },
      ).timeout(const Duration(seconds: 15));
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        debugPrint('[Sudatchi] HTTP ${res.statusCode} for $url');
      }
    } catch (e) {
      debugPrint('[Sudatchi] Error fetching $url: $e');
    }
    return null;
  }

  @override
  Future<AnimeDetailsResult> getDetails({
    required int anilistId,
    required String slug,
    required String romajiTitle,
    required String englishTitle,
    int? anidbId,
  }) async {
    debugPrint('[Sudatchi] getDetails for Anilist ID: $anilistId');
    final data = await _getJson('$_baseUrl/api/anime/$anilistId');
    if (data is! Map) {
      debugPrint('[Sudatchi] Failed to get anime data for $anilistId');
      return AnimeDetailsResult(id: anilistId.toString(), title: romajiTitle, episodes: []);
    }

    final episodesList = data['episodes'];
    final episodes = <EpisodeInfo>[];

    if (episodesList is List) {
      for (var i = 0; i < episodesList.length; i++) {
        final ep = episodesList[i];
        if (ep is! Map) continue;
        
        final numberObj = ep['number'];
        final number = (numberObj is num) ? numberObj.toInt() : (int.tryParse(numberObj?.toString() ?? '') ?? i + 1);

        final payload = jsonEncode({
          'provider': 'sudatchi',
          'animeId': anilistId.toString(),
          'number': number,
        });

        final imgPath = ep['imgUrl']?.toString() ?? ep['thumbnail']?.toString();
        final fullImgPath = (imgPath != null && imgPath.startsWith('/')) ? '$_baseUrl$imgPath' : imgPath;

        episodes.add(EpisodeInfo(
          id: payload,
          number: number,
          title: ep['title']?.toString() ?? 'Episodio $number',
          url: '$_baseUrl/watch/$anilistId/$number',
          image: fullImgPath,
          hasDub: true, // Sudatchi embeds dub tracks if available, we assume true for now.
        ));
      }
    }

    String? apiTitle;
    final tObj = data['title'];
    if (tObj is Map) {
      apiTitle = tObj['romaji']?.toString() ?? tObj['english']?.toString() ?? tObj['native']?.toString();
    } else if (tObj is String) {
      apiTitle = tObj;
    }

    final title = (data['titleRomaji']?.toString()) ?? (data['titleEnglish']?.toString()) ?? apiTitle ?? romajiTitle;
    debugPrint('[Sudatchi] Found ${episodes.length} episodes for $title');

    return AnimeDetailsResult(
      id: anilistId.toString(),
      title: title,
      episodes: episodes,
    );
  }

  @override
  Future<List<StreamLink>> getStreams(String episodeId, {String overrideType = 'sub'}) async {
    debugPrint('[Sudatchi] getStreams for payload: $episodeId');
    try {
      final parsed = jsonDecode(episodeId);
      final animeId = parsed['animeId'] as String;
      final number = (parsed['number'] as num).toInt();

      final epData = await _getJson('$_baseUrl/api/episode/$animeId/$number');
      if (epData is! Map) return [];

      final epsList = epData['episodes'];
      if (epsList is! List) return [];

      Map<String, dynamic>? targetEp;
      for (final ep in epsList) {
        if (ep is Map && ep['number'] == number) {
          targetEp = Map<String, dynamic>.from(ep);
          break;
        }
      }

      if (targetEp == null || targetEp['id'] == null) {
        debugPrint('[Sudatchi] Episode $number not found in response');
        return [];
      }
      final targetEpId = targetEp['id'];
      debugPrint('[Sudatchi] Found targetEpId: $targetEpId for ep $number');

      final subtitleTracks = <SubtitleTrack>[];
      final subtitleRes = await _getJson('$_baseUrl/api/subtitles/$targetEpId');
      if (subtitleRes is Map && subtitleRes['subtitles'] is List) {
        final subs = subtitleRes['subtitles'] as List;
        for (var i = 0; i < subs.length; i++) {
          final sub = subs[i];
          if (sub is! Map || sub['file'] == null) continue;
          
          final fileUrl = (sub['file'] as String).startsWith('http') 
              ? sub['file'] as String 
              : '$_baseUrl${sub['file']}';
              
          subtitleTracks.add(SubtitleTrack(
            id: (sub['lang'] as String?) ?? (sub['label'] as String?) ?? 'sub-$i',
            name: (sub['label'] as String?) ?? (sub['lang'] as String?) ?? 'Subtitle ${i + 1}',
            language: (sub['lang'] as String?) ?? (sub['label'] as String?) ?? 'Unknown',
            url: fileUrl,
            headers: const {'Referer': '$_baseUrl/', 'Origin': _baseUrl},
            isDefault: i == 0,
          ));
        }
      }

      final streamUrl = '$_baseUrl/api/streams?episodeId=$targetEpId';
      String realHlsUrl = streamUrl;

      return [
        StreamLink(
          url: realHlsUrl,
          quality: 'Sudatchi HLS',
          isM3u8: true,
          headers: {
            'Referer': '$_baseUrl/watch/$animeId/$number',
            'Origin': _baseUrl,
          },
          subtitles: subtitleTracks,
        )
      ];
    } catch (_) {
      return [];
    }
  }
}
