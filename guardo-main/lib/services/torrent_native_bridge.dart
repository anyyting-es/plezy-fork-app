import 'dart:convert';

import 'package:flutter/services.dart';

class TorrentNativeBridge {
  static const MethodChannel _channel = MethodChannel('anityng/torrent_native');

  Future<void> setBaseUrl(String baseUrl) async {
    await _channel.invokeMethod<void>('setBaseUrl', {'baseUrl': baseUrl});
  }

  Future<bool> health() async {
    final result = await _channel.invokeMethod<bool>('health');
    return result ?? false;
  }

  Future<Map<String, dynamic>?> addTorrent({String? magnetLink, String? infoHash}) async {
    final raw = await _channel.invokeMethod<String>('addTorrent', {
      'magnetLink': magnetLink,
      'infoHash': infoHash,
    });
    if (raw == null || raw.isEmpty) return null;
    final json = jsonDecode(raw);
    if (json is Map<String, dynamic>) return json;
    return null;
  }

  Future<Map<String, dynamic>?> getTorrentInfo(String infoHash) async {
    final raw = await _channel.invokeMethod<String>('getTorrentInfo', {'infoHash': infoHash});
    if (raw == null || raw.isEmpty) return null;
    final json = jsonDecode(raw);
    if (json is Map<String, dynamic>) return json;
    return null;
  }

  Future<List<Map<String, dynamic>>> listTorrents() async {
    final raw = await _channel.invokeMethod<String>('listTorrents');
    if (raw == null || raw.isEmpty) return const [];
    final json = jsonDecode(raw);
    if (json is! List) return const [];
    return json.whereType<Map<String, dynamic>>().toList();
  }

  Future<bool> removeTorrent(String infoHash, {bool deleteFiles = false}) async {
    final result = await _channel.invokeMethod<bool>('removeTorrent', {
      'infoHash': infoHash,
      'deleteFiles': deleteFiles,
    });
    return result ?? false;
  }

  Future<String?> getStreamUrl(String infoHash, int fileIndex) async {
    final result = await _channel.invokeMethod<String>('getStreamUrl', {
      'infoHash': infoHash,
      'fileIndex': fileIndex,
    });
    return result;
  }
}
