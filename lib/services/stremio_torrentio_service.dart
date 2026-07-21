import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';

class TorrentioStream {
  final String title;
  final String? infoHash;
  final int? fileIdx;
  final String? url;
  final List<String> sources;

  // Parsed metadata
  final String quality;
  final String codec;
  final String size;
  final String source;
  final int seeders;

  TorrentioStream({
    required this.title,
    this.infoHash,
    this.fileIdx,
    this.url,
    this.sources = const [],
    this.quality = '',
    this.codec = '',
    this.size = '',
    required this.source,
    this.seeders = 0,
  });

  String? get magnetLink {
    if (infoHash == null || infoHash!.isEmpty) return null;
    final trackers = sources
        .where((s) => s.startsWith('tracker:'))
        .map((s) => s.replaceFirst('tracker:', ''))
        .toList();
    
    var magnet = 'magnet:?xt=urn:btih:$infoHash';
    for (final tracker in trackers) {
      magnet += '&tr=${Uri.encodeComponent(tracker)}';
    }
    return magnet;
  }

  factory TorrentioStream.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String?) ?? '';
    final hash = json['infoHash'] as String?;
    final fileIdx = (json['fileIdx'] as num?)?.toInt();
    final url = json['url'] as String?;
    final sources = ((json['sources'] as List?) ?? [])
        .map((s) => s.toString())
        .toList();

    // Parse metadata from title lines
    final lines = title.split('\n');
    String quality = '';
    String codec = '';
    String size = '';
    String sourceName = '';
    int seeds = 0;

    for (final line in lines) {
      final ln = line.trim();
      
      // Extract Quality
      if (RegExp(r'2160p|4K', caseSensitive: false).hasMatch(ln)) {
        quality = '4K';
      } else if (RegExp(r'1080p', caseSensitive: false).hasMatch(ln)) {
        quality = '1080p';
      } else if (RegExp(r'720p', caseSensitive: false).hasMatch(ln)) {
        quality = '720p';
      } else if (RegExp(r'480p', caseSensitive: false).hasMatch(ln)) {
        quality = '480p';
      }

      // Extract Codec
      if (RegExp(r'HEVC|H\.265|x265', caseSensitive: false).hasMatch(ln)) {
        codec = 'HEVC';
      } else if (RegExp(r'AV1', caseSensitive: false).hasMatch(ln)) {
        codec = 'AV1';
      } else if (RegExp(r'H\.264|x264', caseSensitive: false).hasMatch(ln)) {
        codec = 'H.264';
      }

      // Extract Size
      final sizeMatch = RegExp(r'(\d+\.?\d*)\s*(GB|MB|TB)', caseSensitive: false).firstMatch(ln);
      if (sizeMatch != null) {
        size = sizeMatch.group(0) ?? '';
      }

      // Extract Seeders (looks like 👤 12 or 👤12)
      final seedsMatch = RegExp(r'👤\s*(\d+)').firstMatch(ln);
      if (seedsMatch != null) {
        seeds = int.tryParse(seedsMatch.group(1) ?? '0') ?? 0;
      }

      // Source name (first non-empty line usually)
      if (sourceName.isEmpty && ln.isNotEmpty && !ln.startsWith('👤') && !ln.startsWith('💾')) {
        sourceName = ln;
      }
    }

    return TorrentioStream(
      title: title,
      infoHash: hash,
      fileIdx: fileIdx,
      url: url,
      sources: sources,
      quality: quality,
      codec: codec,
      size: size,
      source: sourceName.isNotEmpty ? sourceName : 'Torrentio',
      seeders: seeds,
    );
  }
}

class StremioTorrentioService {
  StremioTorrentioService._();
  static final StremioTorrentioService instance = StremioTorrentioService._();

  static const String _defaultBaseUrl = 'https://torrentio.strem.fun';

  /// Fetches movie stream options from Torrentio.
  Future<List<TorrentioStream>> fetchMovieStreams({required String imdbId}) async {
    final endpoint = '$_defaultBaseUrl/stream/movie/$imdbId.json';
    return _fetchStreams(endpoint);
  }

  /// Fetches series episode stream options from Torrentio.
  Future<List<TorrentioStream>> fetchSeriesStreams({
    required String imdbId,
    required int season,
    required int episode,
  }) async {
    final endpoint = '$_defaultBaseUrl/stream/series/$imdbId:$season:$episode.json';
    return _fetchStreams(endpoint);
  }

  Future<List<TorrentioStream>> _fetchStreams(String endpoint) async {
    appLogger.d('[Torrentio] Fetching stream links from: $endpoint');
    try {
      final res = await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        appLogger.w('[Torrentio] HTTP error ${res.statusCode} fetching streams');
        return [];
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final streamsJson = (json['streams'] as List<dynamic>?) ?? [];
      
      final streams = streamsJson
          .whereType<Map<String, dynamic>>()
          .map(TorrentioStream.fromJson)
          .toList();

      // Sort by seeders descending
      streams.sort((a, b) => b.seeders.compareTo(a.seeders));
      return streams;
    } catch (e) {
      appLogger.e('[Torrentio] Error fetching streams from Torrentio', error: e);
      return [];
    }
  }
}
