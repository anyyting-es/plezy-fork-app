import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';
import 'torrent_engine_service.dart';
import 'settings_service.dart';

class ExtensionPlugin {
  final String id;
  final String name;
  final String filename;
  final String contentType;

  ExtensionPlugin({
    required this.id,
    required this.name,
    required this.filename,
    required this.contentType,
  });

  factory ExtensionPlugin.fromJson(Map<String, dynamic> json) {
    return ExtensionPlugin(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? _deduceContentType(json['id']?.toString() ?? ''),
    );
  }

  static String _deduceContentType(String id) {
    final idLower = id.toLowerCase();
    if (idLower.contains('anime') || idLower.contains('tosho') || idLower.contains('neko') || idLower.contains('bt')) {
      return 'anime';
    }
    if (idLower.contains('manga')) {
      return 'manga';
    }
    return 'general';
  }
}

class PluginExtensionsService {
  PluginExtensionsService._();

  static String get _backendBaseUrl {
    final engineUrl = TorrentEngineService.instance.baseUrl;
    return engineUrl.isNotEmpty ? engineUrl : 'http://127.0.0.1:9876';
  }

  /// Lists all loaded JS extensions on the backend.
  static Future<List<ExtensionPlugin>> listExtensions() async {
    final Uri uri = Uri.parse('$_backendBaseUrl/extensions/list');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final list = jsonDecode(response.body) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ExtensionPlugin.fromJson)
          .toList();
    } catch (e, st) {
      appLogger.e('[PluginExtensions] Failed to list extensions', error: e, stackTrace: st);
      return [];
    }
  }

  /// Calls a method on a provider with arguments.
  static Future<dynamic> callMethod({
    required String providerId,
    required String method,
    required List<dynamic> args,
  }) async {
    final Uri uri = Uri.parse(
      '$_backendBaseUrl/extensions/call?provider=$providerId&method=$method&args=${Uri.encodeComponent(jsonEncode(args))}',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('Extension call failed: HTTP ${response.statusCode} - ${response.body}');
      }
      return jsonDecode(response.body);
    } catch (e, st) {
      appLogger.e('[PluginExtensions] Method call failed: $providerId.$method', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// High-level method to resolve direct HLS stream for an anime title & episode number.
  /// Loops dynamically through all enabled online extension plugins.
  static Future<String?> getOnlineStreamUrl({
    required String title,
    required int episodeNumber,
    String type = 'sub',
  }) async {
    // 1. Fetch all extensions from backend
    final list = await listExtensions();
    final settings = SettingsService.instance;
    final disabledList = settings.read(SettingsService.disabledExtensions);

    final activeType = settings.read(SettingsService.discoverContentType);
    final String activeTypeStr = activeType == DiscoverContentType.anime ? 'anime' : 'general';

    // 2. Filter enabled online extensions matching the active content type
    final onlineExtensions = list.where((ext) {
      if (disabledList.contains(ext.id)) return false;
      if (ext.contentType != activeTypeStr) return false;
      return !(ext.id.contains('torrent') || ext.id.contains('tosho') || ext.id.contains('bt') || ext.id.contains('torrentio'));
    }).toList();

    if (onlineExtensions.isEmpty) {
      appLogger.w('[PluginExtensions] No enabled online extensions available for $activeTypeStr to resolve stream.');
      return null;
    }

    // Try queries on each online provider in sequence
    for (final ext in onlineExtensions) {
      final providerId = ext.id;
      appLogger.i('[PluginExtensions] Resolving online stream via provider "$providerId" for: "$title" E$episodeNumber');

      final List<String> queries = [title];

      final cleanedTitle = title
          .replaceAll(
            RegExp(
              r'(:?\s*(Season|Part|Cour|2nd Season|3rd Season|4th Season)\s*\d*.*)',
              caseSensitive: false,
            ),
            '',
          )
          .trim();

      if (cleanedTitle.isNotEmpty && cleanedTitle != title) {
        queries.add(cleanedTitle);
      }

      final words = title.split(RegExp(r'\s+'));
      if (words.length > 3) {
        queries.add(words.take(3).join(' '));
      }

      for (final query in queries) {
        try {
          final searchUrl = Uri.parse(
            '$_backendBaseUrl/extensions/search?provider=$providerId&query=${Uri.encodeComponent(query)}&isDub=${type == 'dub'}',
          );
          final searchResp = await http.get(searchUrl).timeout(const Duration(seconds: 15));
          if (searchResp.statusCode != 200) continue;

          final results = jsonDecode(searchResp.body) as List;
          if (results.isEmpty) continue;

          final bestResult = results.first as Map<String, dynamic>;
          final slug = bestResult['slug']?.toString();
          if (slug == null || slug.isEmpty) continue;

          appLogger.i('[PluginExtensions] Matched slug: "$slug" for query "$query" on "$providerId"');

          final serverUrl = Uri.parse(
            '$_backendBaseUrl/extensions/server?provider=$providerId&slug=${Uri.encodeComponent(slug)}&episode=$episodeNumber&type=$type',
          );
          final serverResp = await http.get(serverUrl).timeout(const Duration(seconds: 15));
          if (serverResp.statusCode != 200) continue;

          final serverData = jsonDecode(serverResp.body) as Map<String, dynamic>;
          final m3u8Url = serverData['url']?.toString();
          if (m3u8Url != null && m3u8Url.isNotEmpty) {
            appLogger.i('[PluginExtensions] Successfully resolved HLS stream URL: "$m3u8Url"');
            return m3u8Url;
          }
        } catch (e, st) {
          appLogger.e('[PluginExtensions] Error matching online stream via "$providerId" for query "$query"', error: e, stackTrace: st);
        }
      }
    }

    return null;
  }

  /// Installs an extension from a JS URL.
  static Future<bool> installExtension({
    required String id,
    required String url,
  }) async {
    final Uri uri = Uri.parse('$_backendBaseUrl/extensions/install');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'url': url}),
      ).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        appLogger.e('[PluginExtensions] Install failed: HTTP ${response.statusCode} - ${response.body}');
        return false;
      }
      return true;
    } catch (e, st) {
      appLogger.e('[PluginExtensions] Failed to install extension $id from $url', error: e, stackTrace: st);
      return false;
    }
  }

  /// Uninstalls an extension.
  static Future<bool> uninstallExtension({
    required String id,
  }) async {
    final Uri uri = Uri.parse('$_backendBaseUrl/extensions/uninstall');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        appLogger.e('[PluginExtensions] Uninstall failed: HTTP ${response.statusCode} - ${response.body}');
        return false;
      }
      return true;
    } catch (e, st) {
      appLogger.e('[PluginExtensions] Failed to uninstall extension $id', error: e, stackTrace: st);
      return false;
    }
  }
}
