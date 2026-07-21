import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'real_debrid_service.dart';

/// A single stream result from Torrentio.
class TorrentioStream {
  final String title;
  final String? infoHash;
  final int? fileIdx;
  final String? url;
  final List<String> sources;

  // Parsed metadata from title
  final String quality; // e.g. "1080p", "720p"
  final String codec; // e.g. "HEVC", "x264"
  final String size; // e.g. "1.4 GB"
  final String source_; // e.g. "Erai-raws", "SubsPlease"
  final bool isRdCached; // RD+ cached indicator

  TorrentioStream({
    required this.title,
    this.infoHash,
    this.fileIdx,
    this.url,
    this.sources = const [],
    this.quality = '',
    this.codec = '',
    this.size = '',
    this.source_ = '',
    this.isRdCached = false,
  });

  /// Build a magnet link from the infoHash.
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
    String source = '';
    bool isRdCached = false;

    for (final line in lines) {
      final ln = line.trim();
      // Check for quality indicators
      if (RegExp(r'2160p|4K', caseSensitive: false).hasMatch(ln)) {
        quality = '4K';
      } else if (RegExp(r'1080p', caseSensitive: false).hasMatch(ln)) quality = '1080p';
      else if (RegExp(r'720p', caseSensitive: false).hasMatch(ln)) quality = '720p';
      else if (RegExp(r'480p', caseSensitive: false).hasMatch(ln)) quality = '480p';

      // Check for codec
      if (RegExp(r'HEVC|H\.265|x265', caseSensitive: false).hasMatch(ln)) {
        codec = 'HEVC';
      } else if (RegExp(r'AV1', caseSensitive: false).hasMatch(ln)) codec = 'AV1';
      else if (RegExp(r'H\.264|x264', caseSensitive: false).hasMatch(ln)) codec = 'H.264';

      // Check for size
      final sizeMatch = RegExp(r'(\d+\.?\d*)\s*(GB|MB|TB)', caseSensitive: false).firstMatch(ln);
      if (sizeMatch != null) size = sizeMatch.group(0) ?? '';

      // Check for RD+ (cached)
      if (ln.contains('⚡') || ln.contains('[RD+]') || ln.contains('RD+')) {
        isRdCached = true;
      }
      if (ln.contains('[RD download]')) {
        isRdCached = false; // Not cached, just available
      }

      // Source name (usually first line)
      if (source.isEmpty && ln.isNotEmpty && !ln.startsWith('👤') && !ln.startsWith('💾')) {
        source = ln;
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
      source_: source,
      isRdCached: isRdCached,
    );
  }
}

/// Service to interact with a Torrentio addon instance.
///
/// Example base URL: https://torrentio.strem.fun/language=latino|spanish/
/// The user pastes their config URL, and we extract the base from it.
class TorrentioService {
  TorrentioService._();
  static final TorrentioService instance = TorrentioService._();

  String _baseUrl = '';
  
  bool get isConfigured => _baseUrl.isNotEmpty;

  /// Set the Torrentio configuration URL.
  /// Accepts URLs like:
  ///   https://torrentio.strem.fun/language=latino|spanish/manifest.json
  ///   https://torrentio.strem.fun/language=latino|spanish
  ///   https://torrentio.strem.fun/realdebrid=API_KEY/language=latino/
  void setConfigUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      _baseUrl = '';
      return;
    }
    var cleaned = url.trim();
    // Remove trailing manifest.json
    if (cleaned.endsWith('/manifest.json')) {
      cleaned = cleaned.substring(0, cleaned.length - '/manifest.json'.length);
    }
    // Ensure trailing slash
    if (!cleaned.endsWith('/')) cleaned += '/';
    _baseUrl = cleaned;
    debugPrint('[Torrentio] Config URL set: $_baseUrl');
  }

  /// Fetch streams for a series episode.
  /// 
  /// [imdbId] - IMDB ID like "tt1234567"
  /// [season] - season number
  /// [episode] - episode number
  Future<List<TorrentioStream>> fetchStreams({
    required String imdbId,
    required int season,
    required int episode,
  }) async {
    if (!isConfigured) {
      debugPrint('[Torrentio] Not configured, skipping stream fetch');
      return [];
    }
    
    final endpoint = '${_baseUrl}stream/series/$imdbId:$season:$episode.json';
    debugPrint('[Torrentio] Fetching: $endpoint');

    try {
      final res = await http.get(Uri.parse(endpoint)).timeout(
        const Duration(seconds: 15),
      );
      
      if (res.statusCode != 200) {
        debugPrint('[Torrentio] Error ${res.statusCode}: ${res.body}');
        return [];
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final streams = (json['streams'] as List<dynamic>?) ?? [];
      
      final results = streams
          .whereType<Map<String, dynamic>>()
          .map(TorrentioStream.fromJson)
          .toList();
      
      debugPrint('[Torrentio] Found ${results.length} streams for $imdbId S${season}E$episode');
      return results;
    } catch (e) {
      debugPrint('[Torrentio] Error fetching streams: $e');
      return [];
    }
  }

  /// Resolve a TorrentioStream to a direct playable URL using Real-Debrid.
  /// 
  /// If the stream has a direct URL, returns it.
  /// If it has an infoHash, uses RD to resolve it.
  Future<String?> resolveStreamUrl(
    TorrentioStream stream, {
    void Function(String status)? onStatusUpdate,
  }) async {
    // Direct URL (e.g., from debrid pre-resolved)
    if (stream.url != null && stream.url!.isNotEmpty) {
      return stream.url;
    }

    // Needs Real-Debrid resolution
    final magnet = stream.magnetLink;
    if (magnet == null) {
      debugPrint('[Torrentio] No URL or magnet available for stream');
      return null;
    }

    final rd = RealDebridService.instance;
    if (!rd.isConfigured) {
      debugPrint('[Torrentio] Real-Debrid not configured, cannot resolve magnet');
      return null;
    }

    try {
      final directUrl = await rd.resolveMagnetToStream(
        magnet,
        onStatusUpdate: onStatusUpdate,
      );
      return directUrl;
    } catch (e) {
      debugPrint('[Torrentio] Error resolving via RD: $e');
      rethrow;
    }
  }

  /// Check which streams are cached on Real-Debrid.
  /// Returns the set of infoHashes that are cached.
  Future<Set<String>> checkCachedStreams(List<TorrentioStream> streams) async {
    final rd = RealDebridService.instance;
    if (!rd.isConfigured) return {};

    final hashes = streams
        .where((s) => s.infoHash != null && s.infoHash!.isNotEmpty)
        .map((s) => s.infoHash!)
        .toList();

    if (hashes.isEmpty) return {};

    return rd.checkInstantAvailability(hashes);
  }
}
