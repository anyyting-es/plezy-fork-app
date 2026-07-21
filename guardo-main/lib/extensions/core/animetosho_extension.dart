import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/app_models.dart';
import '../models/extension_manifest.dart';
import 'extension_base.dart';

/// Modelo para un torrent retornado por AnimeTosho API v1
class AnimeToshoTorrent {
  final String title;
  final String infoHash;
  final String magnet;
  final String torrentUrl;
  final String viewUrl;
  final int seeders;
  final int leechers;
  final int downloads;
  final int sizeBytes;
  final String resolution;
  final String releaseGroup;
  final bool isBatch;
  final int fileCount;
  final String dateAdded;
  final int? seriesEpisodeNumber;
  final int? anidbAid;
  final int? anidbEid;

  AnimeToshoTorrent({
    required this.title,
    required this.infoHash,
    required this.magnet,
    required this.torrentUrl,
    required this.viewUrl,
    required this.seeders,
    required this.leechers,
    required this.downloads,
    required this.sizeBytes,
    required this.resolution,
    required this.releaseGroup,
    required this.isBatch,
    required this.fileCount,
    required this.dateAdded,
    this.seriesEpisodeNumber,
    this.anidbAid,
    this.anidbEid,
  });

  factory AnimeToshoTorrent.fromJson(Map<String, dynamic> json) {
    final series = json['series'] as Map<String, dynamic>? ?? {};
    int seeders = (json['seeders'] as num?)?.toInt() ?? 0;
    int leechers = (json['leechers'] as num?)?.toInt() ?? 0;
    // Clean up impossibly high seeder/leecher counts
    if (seeders > 100000) seeders = 0;
    if (leechers > 100000) leechers = 0;

    final urls = json['urls'] as Map<String, dynamic>? ?? {};

    return AnimeToshoTorrent(
      title: (json['title'] as String?) ?? '',
      infoHash: ((json['info_hash'] as String?) ?? '').toLowerCase(),
      magnet: (json['magnet'] as String?) ?? '',
      torrentUrl: (json['torrent_url'] as String?) ?? '',
      viewUrl: (urls['view'] as String?) ?? '',
      seeders: seeders,
      leechers: leechers,
      downloads: (json['downloads'] as num?)?.toInt() ?? 0,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      resolution: (json['resolution'] as String?) ?? '',
      releaseGroup: (json['release_group'] as String?) ?? '',
      isBatch: (json['is_batch'] as bool?) ?? false,
      fileCount: (json['file_count'] as num?)?.toInt() ?? 1,
      dateAdded: (json['date_added'] as String?) ?? '',
      seriesEpisodeNumber: (series['episode_number'] as num?)?.toInt(),
      anidbAid: (series['anidb_aid'] as num?)?.toInt(),
      anidbEid: (series['anidb_eid'] as num?)?.toInt(),
    );
  }

  bool get isActualBatch =>
      fileCount > 1 ||
      isBatch ||
      (RegExp(r'batch|complete|full|pack|~|season|S\d{1,2}', caseSensitive: false).hasMatch(title) &&
          !RegExp(
            r'(?:S\d{1,2}E\d{1,3}(?:v\d+)?|S\d{1,2}x\d{1,3}(?:v\d+)?|EP?\.?\s*\d{1,3}(?:v\d+)?|E\d{1,3}(?:v\d+)?|episode)\b|-\s*\d{1,3}\b',
            caseSensitive: false,
          ).hasMatch(title));

  String get formattedSize {
    if (sizeBytes == 0) return '0 Bytes';
    const sizes = ['Bytes', 'KiB', 'MiB', 'GiB', 'TiB'];
    double val = sizeBytes.toDouble();
    int unit = 0;
    while (val >= 1024 && unit < sizes.length - 1) {
      val /= 1024;
      unit++;
    }
    return '${val.toStringAsFixed(2)} ${sizes[unit]}';
  }
}

/// Extensión AnimeTosho usando la nueva API v1 (feed.animetosho.xyz/json/v1)
/// Es un TorrentProvider: en lugar de retornar streams directos, retorna
/// StreamLink con un magnet en los headers para que el reproductor lo procese
/// con el backend Go (anacrolix/torrent).
class AnimeToshoExtension extends ExtensionBase {
  static const String _defaultFeedUrl = 'https://feed.animetosho.xyz/json/v1';

  /// AniDB AID del anime actual (se setea antes de buscar)
  int? _currentAnidbAid;

  /// Títulos del anime actual
  String? _currentRomajiTitle;
  String? _currentEnglishTitle;
  int? _currentEpisodeCount;
  String? _currentFormat;

  AnimeToshoExtension()
      : super(
          ExtensionManifest(
            id: 'animetosho',
            name: 'AnimeTosho',
            version: '1.0.0',
            type: 'torrent',
            language: 'dart',
            author: 'Guardo',
            description: 'AnimeTosho torrent provider (API v1)',
            baseUrl: _defaultFeedUrl,
          ),
        );

  String get _baseUrl => _defaultFeedUrl;

  /// Setea el contexto del anime actual para búsquedas posteriores
  void setAnimeContext({
    int? anidbAid,
    String? romajiTitle,
    String? englishTitle,
    int? episodeCount,
    String? format,
  }) {
    _currentAnidbAid = anidbAid;
    _currentRomajiTitle = romajiTitle;
    _currentEnglishTitle = englishTitle;
    _currentEpisodeCount = episodeCount;
    _currentFormat = format;
    debugPrint('[AnimeTosho] Context set: aid=$anidbAid romaji="$romajiTitle" english="$englishTitle" eps=$episodeCount format=$format');
  }

  @override
  Future<void> initialize() async {
    debugPrint('[AnimeTosho] Extension initialized');
  }

  @override
  Future<List<SearchResult>> search(String query) async {
    // AnimeTosho no es una fuente de búsqueda general de anime
    return [];
  }

  /// Busca episodios para el anime configurado con setAnimeContext()
  @override
  Future<AnimeDetailsResult> getDetails(String idOrUrl) async {
    // idOrUrl puede ser un JSON con {anilistId, anidbAid, title, episodeCount, format}
    // o simplemente el título
    Map<String, dynamic>? ctx;
    try {
      ctx = jsonDecode(idOrUrl) as Map<String, dynamic>;
    } catch (_) {}

    final anidbAid = (ctx?['anidbAid'] as num?)?.toInt() ?? _currentAnidbAid;
    final romajiTitle = (ctx?['romajiTitle'] as String?) ?? _currentRomajiTitle ?? idOrUrl;
    final englishTitle = (ctx?['englishTitle'] as String?) ?? _currentEnglishTitle;
    final episodeCount = (ctx?['episodeCount'] as num?)?.toInt() ?? _currentEpisodeCount;
    final format = (ctx?['format'] as String?) ?? _currentFormat;
    final anilistId = (ctx?['anilistId'] as num?)?.toInt() ?? 0;

    debugPrint('[AnimeTosho] getDetails: aid=$anidbAid romaji="$romajiTitle" english="$englishTitle"');

    final episodes = await _fetchEpisodeList(
      anidbAid: anidbAid,
      romajiTitle: romajiTitle,
      englishTitle: englishTitle,
      episodeCount: episodeCount,
      format: format,
      anilistId: anilistId,
    );

    return AnimeDetailsResult(
      id: idOrUrl,
      title: romajiTitle,
      episodes: episodes,
    );
  }

  /// Dada una ID de episodio (JSON con contexto), retorna StreamLinks
  /// con los magnets disponibles para que el reproductor los use con el backend Go.
  @override
  Future<List<StreamLink>> extractVideos(String episodeIdOrUrl) async {
    Map<String, dynamic> ctx;
    try {
      ctx = jsonDecode(episodeIdOrUrl) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('[AnimeTosho] Invalid episodeId format: $episodeIdOrUrl');
      return [];
    }

    final episodeNum = (ctx['episode'] as num?)?.toInt();
    final anidbAid = (ctx['anidbAid'] as num?)?.toInt() ?? _currentAnidbAid;
    final anidbEid = (ctx['anidbEid'] as num?)?.toInt();
    final isBatchSearch = ctx['isBatch'] as bool? ?? false;

    debugPrint('[AnimeTosho] extractVideos: ep=$episodeNum aid=$anidbAid eid=$anidbEid batch=$isBatchSearch');

    List<AnimeToshoTorrent> torrents = [];

    // 1. Buscar por EID si disponible (más preciso para episodios individuales)
    if (!isBatchSearch && anidbEid != null && anidbEid > 0) {
      try {
        final url = Uri.parse('$_baseUrl/releases?eid=$anidbEid&limit=100');
        torrents = await _fetchTorrents(url);
        torrents = torrents.where((t) => !t.isActualBatch).toList();
        debugPrint('[AnimeTosho] Found ${torrents.length} by EID $anidbEid');
      } catch (e) {
        debugPrint('[AnimeTosho] EID search failed: $e');
      }
    }

    // 2. Buscar por AID si disponible
    if (torrents.isEmpty && anidbAid != null && anidbAid > 0) {
      try {
        final url = Uri.parse('$_baseUrl/releases?aid=$anidbAid&order=size-d&limit=100');
        final all = await _fetchTorrents(url);
        if (isBatchSearch) {
          torrents = all.where((t) => t.isActualBatch).toList();
          if (torrents.isEmpty) torrents = all;
        } else {
          // Filtrar por número de episodio
          torrents = all.where((t) {
            if (t.isActualBatch) return false;
            if (episodeNum == null) return true;
            if (t.seriesEpisodeNumber != null) return t.seriesEpisodeNumber == episodeNum;
            final extracted = _extractEpisodeNumber(t.title);
            return extracted == episodeNum;
          }).toList();
        }
        debugPrint('[AnimeTosho] Found ${torrents.length} by AID $anidbAid');
      } catch (e) {
        debugPrint('[AnimeTosho] AID search failed: $e');
      }
    }

    // 3. Fallback: buscar por título
    if (torrents.isEmpty) {
      final title = _currentRomajiTitle ?? _currentEnglishTitle ?? '';
      if (title.isNotEmpty && episodeNum != null) {
        try {
          final sanitized = _sanitizeTitle(title);
          final epStr = episodeNum.toString().padLeft(2, '0');
          final q = '$sanitized $epStr';
          final url = Uri.parse('$_baseUrl/search?q=${Uri.encodeQueryComponent(q)}&limit=100&only_tor=1&qx=1');
          final all = await _fetchTorrents(url);
          torrents = all.where((t) {
            if (t.isActualBatch) return false;
            final extracted = _extractEpisodeNumber(t.title);
            return extracted == episodeNum;
          }).toList();
          debugPrint('[AnimeTosho] Found ${torrents.length} by title search "$q"');
        } catch (e) {
          debugPrint('[AnimeTosho] Title search failed: $e');
        }
      }
    }

    if (torrents.isEmpty) {
      debugPrint('[AnimeTosho] No torrents found for episode $episodeNum');
      return [];
    }

    // Convertir a StreamLink con magnet en headers (lazyTorrent = true)
    final links = torrents.map((t) {
      final qualityLabel = [
        t.releaseGroup.isNotEmpty ? t.releaseGroup : 'Unknown',
        t.resolution.isNotEmpty ? t.resolution : _guessResolution(t.title),
        t.formattedSize,
        '${t.seeders} seeders',
      ].join(' • ');

      return StreamLink(
        url: t.magnet.isNotEmpty ? t.magnet : t.torrentUrl,
        quality: qualityLabel,
        isM3u8: false,
        headers: {
          'magnet': t.magnet,
          'infoHash': t.infoHash,
          'lazyTorrent': 'true',
          'torrentTitle': t.title,
          'torrentSize': t.sizeBytes.toString(),
          'torrentSeeders': t.seeders.toString(),
          'torrentResolution': t.resolution.isNotEmpty ? t.resolution : _guessResolution(t.title),
          'torrentGroup': t.releaseGroup,
          'torrentSource': 'animetosho',
        },
      );
    }).toList();

    // Ordenar por seeders descendente
    links.sort((a, b) {
      final aS = int.tryParse(a.headers?['torrentSeeders'] ?? '0') ?? 0;
      final bS = int.tryParse(b.headers?['torrentSeeders'] ?? '0') ?? 0;
      return bS.compareTo(aS);
    });

    debugPrint('[AnimeTosho] Returning ${links.length} stream options');
    return links;
  }

  @override
  void dispose() {}

  // ─── Internal helpers ──────────────────────────────────────────────────────

  Future<List<AnimeToshoTorrent>> _fetchTorrents(Uri url) async {
    debugPrint('[AnimeTosho] Fetching: $url');
    final res = await http.get(url, headers: {
      'User-Agent': 'Mozilla/5.0',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('AnimeTosho HTTP ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List<dynamic>?) ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AnimeToshoTorrent.fromJson)
        .toList();
  }

  Future<List<EpisodeInfo>> _fetchEpisodeList({
    int? anidbAid,
    required String romajiTitle,
    String? englishTitle,
    int? episodeCount,
    String? format,
    required int anilistId,
  }) async {
    final isMovieOrSingle = format == 'MOVIE' || episodeCount == 1;
    final episodeMap = <int, AnimeToshoTorrent>{};

    // 1. Por AID
    if (anidbAid != null && anidbAid > 0) {
      try {
        final url = Uri.parse('$_baseUrl/releases?aid=$anidbAid&order=size-d&limit=100');
        final torrents = await _fetchTorrents(url);
        for (final t in torrents) {
          if (!isMovieOrSingle && t.isActualBatch) continue;
          final ep = t.seriesEpisodeNumber ?? _extractEpisodeNumber(t.title);
          if (ep <= 0) continue;
          final existing = episodeMap[ep];
          if (existing == null || t.seeders > existing.seeders) {
            episodeMap[ep] = t;
          }
        }
        debugPrint('[AnimeTosho] AID lookup: ${episodeMap.length} episodes from ${torrents.length} torrents');
      } catch (e) {
        debugPrint('[AnimeTosho] AID episode list failed: $e');
      }
    }

    // 2. Fallback por título
    if (episodeMap.isEmpty) {
      for (final title in [englishTitle, romajiTitle].whereType<String>()) {
        if (title.trim().isEmpty) continue;
        try {
          final q = _sanitizeTitle(title);
          final url = Uri.parse('$_baseUrl/search?q=${Uri.encodeQueryComponent(q)}&limit=100&only_tor=1');
          final torrents = await _fetchTorrents(url);
          for (final t in torrents) {
            if (!isMovieOrSingle && t.isActualBatch) continue;
            final ep = t.seriesEpisodeNumber ?? _extractEpisodeNumber(t.title);
            if (ep <= 0) continue;
            final existing = episodeMap[ep];
            if (existing == null || t.seeders > existing.seeders) {
              episodeMap[ep] = t;
            }
          }
          if (episodeMap.isNotEmpty) {
            debugPrint('[AnimeTosho] Title "$q" lookup: ${episodeMap.length} episodes');
            break;
          }
        } catch (e) {
          debugPrint('[AnimeTosho] Title search failed: $e');
        }
      }
    }

    final episodes = episodeMap.entries.map((entry) {
      final epNum = entry.key;
      final t = entry.value;
      // El episodeId lleva todo el contexto necesario para extractVideos()
      final episodeId = jsonEncode({
        'type': 'torrent',
        'source': 'animetosho',
        'anilistId': anilistId,
        'anidbAid': anidbAid,
        'anidbEid': t.anidbEid,
        'episode': epNum,
        'isBatch': false,
      });

      return EpisodeInfo(
        id: episodeId,
        number: epNum,
        title: 'Episodio $epNum',
        hasDub: t.title.toLowerCase().contains('dual') ||
            t.title.toLowerCase().contains('latino'),
      );
    }).toList();

    episodes.sort((a, b) => a.number.compareTo(b.number));
    debugPrint('[AnimeTosho] Total episodes found: ${episodes.length}');
    return episodes;
  }

  int _extractEpisodeNumber(String title) {
    final patterns = [
      RegExp(r'[Ss]\d{1,2}[\s\-_.]?[Ee](\d{1,4})'),
      RegExp(r'\b\d{1,2}x(\d{1,4})\b'),
      RegExp(r'[Ee][Pp]?[\s\-]?(\d+)'),
      RegExp(r'[\s\[\(-](\d+)[\s\]\)-]'),
      RegExp(r'[\s\-]+(\d+)[\s]+'),
      RegExp(r'[\s\[\(-](\d+)v[\s\[\]-]'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(title);
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '');
        if (num != null && num > 0 && !_isResolutionOrYear(num)) {
          return num;
        }
      }
    }
    return -1;
  }

  bool _isResolutionOrYear(int v) {
    const resolutions = {240, 360, 480, 540, 720, 1080, 1440, 2160, 264, 265};
    return resolutions.contains(v) || (v >= 1900 && v <= 2100) || v > 9999;
  }

  String _sanitizeTitle(String t) {
    return t
        .replaceAll(RegExp(r'[-]+'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _guessResolution(String title) {
    final match = RegExp(r'(2160|1440|1080|720|480|360)p?', caseSensitive: false).firstMatch(title);
    if (match != null) return '${match.group(1)}p';
    return '';
  }
}
