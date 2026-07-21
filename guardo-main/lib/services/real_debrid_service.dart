import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for interacting with the Real-Debrid API.
/// 
/// Flow: addMagnet → selectFiles → poll torrentInfo → unrestrictLink → play.
class RealDebridService {
  static const _baseUrl = 'https://api.real-debrid.com/rest/1.0';
  
  RealDebridService._();
  static final RealDebridService instance = RealDebridService._();

  String _apiKey = '';
  
  bool get isConfigured => _apiKey.isNotEmpty;

  void setApiKey(String? key) {
    _apiKey = key?.trim() ?? '';
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_apiKey',
  };

  // ─── PUBLIC API ──────────────────────────────────────────────────────

  /// Verify the API key by fetching user info.
  /// Returns user data map on success, null on failure.
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/user'),
        headers: _headers,
      );
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[RealDebrid] getUserInfo error: $e');
      return null;
    }
  }

  /// Add a magnet link. Returns { "id": "...", "uri": "..." }.
  Future<Map<String, dynamic>> addMagnet(String magnet) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/torrents/addMagnet'),
      headers: _headers,
      body: {'magnet': magnet},
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw RealDebridException('Error al agregar magnet: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Select files for a torrent. Defaults to "all".
  Future<void> selectFiles(String torrentId, {String files = 'all'}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/torrents/selectFiles/$torrentId'),
      headers: _headers,
      body: {'files': files},
    );
    // 204 = success, 202 = accepted
    if (res.statusCode != 204 && res.statusCode != 202 && res.statusCode != 200) {
      throw RealDebridException('Error al seleccionar archivos: ${res.statusCode} ${res.body}');
    }
  }

  /// Get torrent info (status, files, links).
  Future<Map<String, dynamic>> getTorrentInfo(String torrentId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/torrents/info/$torrentId'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw RealDebridException('Error al obtener info del torrent: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Unrestrict a hoster link to get the direct download URL.
  Future<String> unrestrictLink(String link) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/unrestrict/link'),
      headers: _headers,
      body: {'link': link},
    );
    if (res.statusCode != 200) {
      throw RealDebridException('Error al desrestringir link: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final download = data['download'] as String?;
    if (download == null || download.isEmpty) {
      throw RealDebridException('No se obtuvo URL de descarga');
    }
    return download;
  }

  /// Delete a torrent from the user's list (cleanup).
  Future<void> deleteTorrent(String torrentId) async {
    try {
      await http.delete(
        Uri.parse('$_baseUrl/torrents/delete/$torrentId'),
        headers: _headers,
      );
    } catch (_) {}
  }

  /// Check which torrent hashes are instantly available (cached) on RD servers.
  /// Returns a Set of hashes that are cached.
  Future<Set<String>> checkInstantAvailability(List<String> hashes) async {
    if (hashes.isEmpty || !isConfigured) return {};
    try {
      // RD accepts multiple hashes separated by /
      final hashPath = hashes.join('/');
      final res = await http.get(
        Uri.parse('$_baseUrl/torrents/instantAvailability/$hashPath'),
        headers: _headers,
      );
      if (res.statusCode != 200) return {};
      final data = jsonDecode(res.body);
      if (data is! Map) return {};
      
      final cached = <String>{};
      for (final hash in hashes) {
        final hashLower = hash.toLowerCase();
        // Check both original and lowercase since RD may return either
        final entry = data[hash] ?? data[hashLower];
        if (entry is Map && entry.isNotEmpty) {
          // Has at least one hoster with cached files
          final rd = entry['rd'];
          if (rd is List && rd.isNotEmpty) {
            cached.add(hashLower);
          }
        }
      }
      debugPrint('[RealDebrid] Instant availability: ${cached.length}/${hashes.length} cached');
      return cached;
    } catch (e) {
      debugPrint('[RealDebrid] checkInstantAvailability error: $e');
      return {};
    }
  }

  // ─── ORCHESTRATION ───────────────────────────────────────────────────

  /// Full flow: magnet → direct streaming URL.
  /// 
  /// [onStatusUpdate] is called with human-readable messages for the UI.
  /// Throws [RealDebridException] on any failure.
  Future<String> resolveMagnetToStream(
    String magnet, {
    void Function(String status)? onStatusUpdate,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    // Step 1: Add magnet
    onStatusUpdate?.call('Enviando torrent a Real-Debrid...');
    final addResult = await addMagnet(magnet);
    final torrentId = addResult['id'] as String;
    debugPrint('[RealDebrid] Torrent added: $torrentId');

    try {
      // Step 2: Select all files
      onStatusUpdate?.call('Seleccionando archivos...');
      await selectFiles(torrentId);

      // Step 3: Poll until downloaded
      final deadline = DateTime.now().add(timeout);
      Map<String, dynamic> info = {};
      
      while (DateTime.now().isBefore(deadline)) {
        info = await getTorrentInfo(torrentId);
        final status = info['status'] as String? ?? '';
        final progress = info['progress'] as num? ?? 0;

        debugPrint('[RealDebrid] Status: $status, Progress: $progress%');

        switch (status) {
          case 'downloaded':
            // Done! Move to step 4.
            break;
          case 'downloading':
            onStatusUpdate?.call('Descargando en Real-Debrid... ${progress.toInt()}%');
            await Future.delayed(const Duration(seconds: 2));
            continue;
          case 'magnet_conversion':
            onStatusUpdate?.call('Convirtiendo magnet...');
            await Future.delayed(const Duration(seconds: 2));
            continue;
          case 'waiting_files_selection':
            // Shouldn't happen since we already selected, but retry
            await selectFiles(torrentId);
            await Future.delayed(const Duration(seconds: 2));
            continue;
          case 'queued':
            onStatusUpdate?.call('En cola de Real-Debrid...');
            await Future.delayed(const Duration(seconds: 3));
            continue;
          case 'compressing':
            onStatusUpdate?.call('Comprimiendo archivos...');
            await Future.delayed(const Duration(seconds: 2));
            continue;
          case 'uploading':
            onStatusUpdate?.call('Subiendo a servidores RD...');
            await Future.delayed(const Duration(seconds: 2));
            continue;
          case 'magnet_error':
          case 'error':
          case 'virus':
          case 'dead':
            throw RealDebridException('Real-Debrid reportó error: $status');
          default:
            onStatusUpdate?.call('Estado: $status');
            await Future.delayed(const Duration(seconds: 2));
            continue;
        }
        // If we reached here, status is 'downloaded'
        break;
      }

      // Check we actually got to 'downloaded'
      final finalStatus = info['status'] as String? ?? '';
      if (finalStatus != 'downloaded') {
        throw RealDebridException('Tiempo de espera agotado (el torrent no se descargó a tiempo)');
      }

      // Step 4: Get links and unrestrict the first one
      final links = (info['links'] as List<dynamic>?) ?? [];
      if (links.isEmpty) {
        throw RealDebridException('Real-Debrid no devolvió links de descarga');
      }

      // Find the best link (prefer video files)
      onStatusUpdate?.call('Obteniendo link de streaming...');
      final streamUrl = await unrestrictLink(links.first.toString());
      
      onStatusUpdate?.call('¡Listo! Reproduciendo...');
      debugPrint('[RealDebrid] Stream URL resolved: $streamUrl');
      return streamUrl;
    } catch (e) {
      // Attempt cleanup on failure
      try { await deleteTorrent(torrentId); } catch (_) {}
      rethrow;
    }
  }
}

class RealDebridException implements Exception {
  final String message;
  RealDebridException(this.message);
  
  @override
  String toString() => message;
}
