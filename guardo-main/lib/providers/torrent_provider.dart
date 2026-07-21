import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional imports for platform-specific libraries
import 'dart:ffi' if (dart.library.html) '../stubs/ffi_stub.dart' as ffi;
import 'dart:io' if (dart.library.html) '../stubs/io_stub.dart';
import 'package:ffi/ffi.dart' if (dart.library.html) '../stubs/ffi_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/app_models.dart';
import '../services/storage_service.dart';
import '../services/torrent_native_bridge.dart';
import '../extensions/extension_service.dart';
import 'video_provider.dart';

enum TorrentSearchSource { animetosho, nyaa }

// FFI Typedefs
typedef StartServerNative = ffi.Int32 Function(ffi.Pointer<Utf8> downloadDir);
typedef StartServerDart = int Function(ffi.Pointer<Utf8> downloadDir);

typedef StopServerNative = ffi.Void Function();
typedef StopServerDart = void Function();

/// Torrent backend configuration
class TorrentConfig {
  static const String defaultBaseUrl = 'http://127.0.0.1:9876';
  
  final String baseUrl;
  final bool autoStartBackend;
  final int startupTimeoutSeconds;
  
  const TorrentConfig({
    this.baseUrl = defaultBaseUrl,
    this.autoStartBackend = true,
    this.startupTimeoutSeconds = 30,
  });
}

/// Response from the torrent backend
class TorrentBackendInfo {
  final String infoHash;
  final String name;
  final int size;
  final int downloaded;
  final double downloadSpeed;
  final double uploadSpeed;
  final int seeders;
  final int leechers;
  final double progress;
  final List<TorrentFile> files;
  final int addedAt;

  TorrentBackendInfo({
    required this.infoHash,
    required this.name,
    required this.size,
    required this.downloaded,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.seeders,
    required this.leechers,
    required this.progress,
    required this.files,
    required this.addedAt,
  });

  factory TorrentBackendInfo.fromJson(Map<String, dynamic> json) {
    final filesJson = (json['files'] as List<dynamic>?) ?? const [];
    return TorrentBackendInfo(
      infoHash: (json['infoHash'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      size: (json['size'] as int?) ?? 0,
      downloaded: (json['downloaded'] as int?) ?? 0,
      downloadSpeed: (json['downloadSpeed'] as num?)?.toDouble() ?? 0.0,
      uploadSpeed: (json['uploadSpeed'] as num?)?.toDouble() ?? 0.0,
      seeders: (json['seeders'] as int?) ?? 0,
      leechers: (json['leechers'] as int?) ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      files: filesJson.map((f) => TorrentFile.fromJson(f as Map<String, dynamic>)).toList(),
      addedAt: (json['addedAt'] as int?) ?? 0,
    );
  }
}

class TorrentFile {
  final int index;
  final String path;
  final int size;
  final int downloaded;

  TorrentFile({
    required this.index,
    required this.path,
    required this.size,
    required this.downloaded,
  });

  factory TorrentFile.fromJson(Map<String, dynamic> json) {
    return TorrentFile(
      index: (json['index'] as int?) ?? 0,
      path: (json['path'] as String?) ?? '',
      size: (json['size'] as int?) ?? 0,
      downloaded: (json['downloaded'] as int?) ?? 0,
    );
  }
}

/// Provider for torrent-based anime streams
class TorrentProvider implements VideoProvider {
  static const String _baseUrl = TorrentConfig.defaultBaseUrl;
  static const String _androidNativeBaseUrl = String.fromEnvironment(
    'TORRENT_ANDROID_BASE_URL',
    defaultValue: 'http://10.0.2.2:9876',
  );

  // Cache de torrents activos: infoHash -> TorrentBackendInfo
  final Map<String, TorrentBackendInfo> _activeTorrents = {};

  bool _androidBridgeConfigured = false;
  String _androidBridgeBaseUrl = '';
  final _nativeBridge = TorrentNativeBridge();
  bool _backendStarted = false;
  Completer<bool>? _backendStarting;
  int? _currentAnilistId;
  Map<String, dynamic>? _currentAnimeData;
  String _currentDownloadBaseDir = '';

  ffi.DynamicLibrary? _lib;
  StartServerDart? _startServer;
  StopServerDart? _stopServer;
  String _dynamicBaseUrl = TorrentConfig.defaultBaseUrl;
  Process? _windowsBackendProcess; // Para manejar el proceso en Windows
  TorrentSearchSource _searchSource = TorrentSearchSource.animetosho;

  void setSearchSource(TorrentSearchSource source) {
    _searchSource = source;
  }

  TorrentSearchSource get searchSource => _searchSource;




  void setEpisodeMetadata({
    required String episodeId,
    required double number,
    required String title,
    String? infoHash,      // <-- NUEVO
    String? torrentName,   // <-- NUEVO (Este es el nombre feo del archivo)
    String? coverImage,
    String? synopsis,
  }) {
    if (_currentAnilistId == null) return;
    final epData = {
      'id': episodeId,
      'number': number,
      'title': title,
      'coverImage': coverImage,
      'synopsis': synopsis,
      'infoHash': infoHash,       // <-- NUEVO
      'torrentName': torrentName, // <-- NUEVO
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    
    _currentAnimeData ??= {'id': _currentAnilistId};
    final episodes = Map<String, dynamic>.from(_currentAnimeData!['episodes'] ?? {});
    episodes[episodeId] = epData;
    _currentAnimeData!['episodes'] = episodes;
    
    debugPrint('[TorrentProvider] episode metadata set for Ep: $number');
    
    // Auto-save if backend is already running in the correct dir
    if (_backendStarted && _currentDownloadBaseDir.endsWith(_currentAnilistId.toString())) {
      _saveMetadata(_currentDownloadBaseDir);
    }
  }

  void _loadLibrary() {
    if (kIsWeb) return;
    if (_lib != null) return;

    String libName;
    if (Platform.isWindows) {
      libName = 'libtorrent.dll';
    } else if (Platform.isAndroid || Platform.isLinux) {
      libName = 'libtorrent.so';
    } else {
      throw UnsupportedError('Platform not supported for Torrent FFI');
    }

    try {
      if (Platform.isAndroid) {
        // En Android, lo más fiable es usar el nombre corto (sin lib ni .so)
        // El sistema se encarga de buscarlo en los directorios del APK.
        try {
          _lib = ffi.DynamicLibrary.open('libtorrent.so');
        } catch (e) {
          debugPrint('[TorrentProvider] Failed with libtorrent.so: $e');
          debugPrint('[TorrentProvider] Trying short name "torrent"...');
          _lib = ffi.DynamicLibrary.open('torrent');
        }
      } else {
        _lib = ffi.DynamicLibrary.open(libName);
      }

      _startServer = _lib!
          .lookupFunction<StartServerNative, StartServerDart>('StartServer') as dynamic;
      _stopServer = _lib!
          .lookupFunction<StopServerNative, StopServerDart>('StopServer') as dynamic;
      debugPrint('[TorrentProvider] FFI Library loaded successfully: $libName');
    } catch (e) {
      debugPrint('[TorrentProvider] FATAL: Could not load FFI library ($libName): $e');
      rethrow;
    }
  }
  
  @override
  String get id => 'torrent';

  @override
  String get name => 'Torrent';

  bool get _useAndroidNativeBridge => false; // Changed from Platform.isAndroid to use FFI

  String _normalizeBaseUrl(String url) => url.trim().replaceAll(RegExp(r'/$'), '');

  Future<String> _resolveConfiguredBaseUrl() async {
    const envUrl = String.fromEnvironment('TORRENT_BACKEND_URL', defaultValue: '');
    final normalizedEnv = _normalizeBaseUrl(envUrl);
    if (normalizedEnv.isNotEmpty) {
      return normalizedEnv;
    }

    try {
      // Backend URL from environment or defaults only
      // No more reading from AppSettings since we removed it
    } catch (_) {}

    if (_useAndroidNativeBridge) {
      return _androidNativeBaseUrl;
    }

    return _dynamicBaseUrl;
  }

  Future<bool> _checkHealth(String baseUrl) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(
        const Duration(seconds: 2),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> getDownloadDirectory() async {
    // Use platform defaults - settings-based path removed
    try {
      // no-op: AppSettings no longer has torrentDownloadPath
    } catch (_) {}

    if (Platform.isAndroid) {
      // Intentar usar la carpeta de descargas pública en Android
      // /storage/emulated/0/Download/Anityng/Torrents
      try {
        // Una forma común de obtener /storage/emulated/0
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final parts = directory.path.split('/');
          final emulatedIdx = parts.indexOf('Android');
          if (emulatedIdx != -1) {
            final base = parts.sublist(0, emulatedIdx).join('/');
            final publicDownloads = '$base/Download/Anityng/Torrents';
            final dir = Directory(publicDownloads);
            if (!await dir.exists()) {
              await dir.create(recursive: true);
            }
            return publicDownloads;
          }
        }
      } catch (e) {
        debugPrint('[TorrentProvider] Error resolving public downloads path: $e');
      }
      
      final directory = await getExternalStorageDirectory();
      return '${directory?.path}/torrents';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}${Platform.pathSeparator}torrents';
    }
  }

  Future<void> _saveMetadata(String downloadDir) async {
    if (_currentAnilistId == null || _currentAnimeData == null) return;
    if (kIsWeb) return;
    try {
      final dir = Directory(downloadDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      
      final file = File('$downloadDir${Platform.pathSeparator}metadata.json');
      
      // Merge with existing metadata if it exists
      Map<String, dynamic> finalData = Map.from(_currentAnimeData!);
      if (await file.exists()) {
        try {
          final existing = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          // Merge episodes
          final existingEpisodes = (existing['episodes'] as Map<String, dynamic>?) ?? {};
          final newEpisodes = (finalData['episodes'] as Map<String, dynamic>?) ?? {};
          final finalMergedEpisodes = {...existingEpisodes, ...newEpisodes};
          finalData = {...existing, ...finalData};
          finalData['episodes'] = finalMergedEpisodes;
        } catch (_) {}
      }

      await file.writeAsString(jsonEncode(finalData));
      debugPrint('[TorrentProvider] Metadata saved/updated at: ${file.path}');
    } catch (e) {
      debugPrint('[TorrentProvider] Error saving metadata: $e');
    }
  }

  /// Starts the Go backend if not already running
  Future<bool> ensureBackendRunning() async {
    return _ensureBackendRunning();
  }
  
  /// Get the configured base URL
  Future<String> getBackendUrl() async {
    await _ensureBackendRunning();
    return _resolveConfiguredBaseUrl();
  }

  Future<bool> _ensureBackendRunning() async {
    if (kIsWeb) return false;
    // 1. Move gate check to the VERY top to prevent any race condition
    if (_backendStarting != null) {
      return _backendStarting!.future;
    }

    // 2. Gate early before any await
    final completer = Completer<bool>();
    _backendStarting = completer;

    try {
      final targetBaseUrl = await _resolveConfiguredBaseUrl();
      
      // First try health for configured backend
      if (await _checkHealth(targetBaseUrl)) {
        _backendStarted = true;
        completer.complete(true);
        return true;
      }

      if (_useAndroidNativeBridge) {
        try {
          if (!_androidBridgeConfigured || _androidBridgeBaseUrl != targetBaseUrl) {
            await _nativeBridge.setBaseUrl(targetBaseUrl);
            _androidBridgeConfigured = true;
            _androidBridgeBaseUrl = targetBaseUrl;
          }
          final ok = await _nativeBridge.health();
          _backendStarted = ok;
          completer.complete(ok);
          return ok;
        } catch (e) {
          debugPrint('[TorrentProvider] Native bridge health error: $e');
          completer.complete(false);
          return false;
        }
      }

      // Resolve where we want to save files
      final baseDir = await getDownloadDirectory();
      String actualDownloadDir = baseDir;
      if (_currentAnilistId != null) {
        actualDownloadDir = '$baseDir${Platform.pathSeparator}$_currentAnilistId';
      }

      // If backend is running for a different path, we must restart it to change DataDir
      if (_backendStarted && _currentDownloadBaseDir != actualDownloadDir) {
        debugPrint('[TorrentProvider] Restarting backend to change directory');
        await stopBackend();
      }

      if (!Platform.isWindows && !Platform.isLinux && !Platform.isAndroid) {
        completer.complete(false);
        return false;
      }

      if (Platform.isWindows || Platform.isLinux) {
        // Cleanup orphaned processes before starting
        try {
          if (Platform.isWindows) {
            await Process.run('taskkill', ['/f', '/im', 'aniting-backend.exe']);
          } else {
            await Process.run('pkill', ['-f', 'aniting-backend']);
          }
        } catch (_) {}

        final exeName = Platform.isWindows ? 'aniting-backend.exe' : 'aniting-backend';
        final exePath = '${Directory(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}$exeName';
        String finalExePath = exePath;
        
        if (!await File(exePath).exists()) {
          final debugPath = '${Directory.current.path}${Platform.pathSeparator}aniting-backend${Platform.pathSeparator}$exeName';
          if (await File(debugPath).exists()) {
            finalExePath = debugPath;
          } else {
            debugPrint('[TorrentProvider] Backend executable not found at $debugPath');
            completer.complete(false);
            return false;
          }
        }

        debugPrint('[TorrentProvider] Starting backend process: $finalExePath');
        await _saveMetadata(actualDownloadDir);

        // Set environment variable for extensions dir
        final extensionsDir = '${baseDir}${Platform.pathSeparator}extensions';
        final environment = Map<String, String>.from(Platform.environment);
        environment['ANITYNG_EXTENSIONS_DIR'] = extensionsDir;

        _windowsBackendProcess = await Process.start(
          finalExePath,
          [actualDownloadDir],
          mode: ProcessStartMode.detachedWithStdio,
          environment: environment,
        );

        final portCompleter = Completer<int>();
        _windowsBackendProcess!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
          debugPrint('[TorrentBackend] $line');
          if (line.contains('Standalone server started on port')) {
            final match = RegExp(r'port (\d+)').firstMatch(line);
            if (match != null) {
              final portNum = int.parse(match.group(1)!);
              if (!portCompleter.isCompleted) portCompleter.complete(portNum);
            }
          }
        });

        _windowsBackendProcess!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
          debugPrint('[TorrentBackend ERR] $line');
        });

        try {
          final port = await portCompleter.future.timeout(const Duration(seconds: 10));
          _dynamicBaseUrl = 'http://127.0.0.1:$port';
          _backendStarted = true;
          _currentDownloadBaseDir = actualDownloadDir;

          final storage = StorageService.instance;
          final settings = await storage.getAppSettings();
          await syncSettingsWithBackend(settings);
          completer.complete(true);
          return true;
        } catch (e) {
          debugPrint('[TorrentProvider] Failed to detect port: $e');
          completer.complete(false);
          return false;
        }
      }

      // Android FFI
      _loadLibrary();

      if (_startServer == null) {
        completer.complete(false);
        return false;
      }

      debugPrint('[TorrentProvider] Starting backend (FFI)');
      await _saveMetadata(actualDownloadDir);

      final downloadDirPtr = actualDownloadDir.toNativeUtf8();
      final port = _startServer!(downloadDirPtr);
      malloc.free(downloadDirPtr);

      if (port <= 0) {
        completer.complete(false);
        return false;
      }

      _dynamicBaseUrl = 'http://127.0.0.1:$port';
      
      final timeout = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(timeout)) {
        if (await _checkHealth(_dynamicBaseUrl)) {
          _backendStarted = true;
          _currentDownloadBaseDir = actualDownloadDir;
          
          final storage = StorageService.instance;
          final settings = await storage.getAppSettings();
          await syncSettingsWithBackend(settings);
          completer.complete(true);
          return true;
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }

      completer.complete(false);
      return false;
    } catch (e) {
      debugPrint('[TorrentProvider] Failed to start backend: $e');
      if (!completer.isCompleted) completer.complete(false);
      return false;
    } finally {
      _backendStarting = null;
    }
  }

  /// Adds a torrent from magnet link
  Future<TorrentBackendInfo?> addTorrent(String magnetLink) async {
    if (_useAndroidNativeBridge) {
      if (!await _ensureBackendRunning()) {
        return null;
      }
      try {
        final raw = await _nativeBridge.addTorrent(magnetLink: magnetLink);
        if (raw == null) return null;
        final info = TorrentBackendInfo.fromJson(raw);
        _activeTorrents[info.infoHash.toLowerCase()] = info;
        return info;
      } on PlatformException catch (e) {
        debugPrint('[TorrentProvider] Native addTorrent error: ${e.message}');
        return null;
      } catch (e) {
        debugPrint('[TorrentProvider] Native addTorrent exception: $e');
        return null;
      }
    }

    if (!await _ensureBackendRunning()) {
      return null;
    }

    final baseUrl = await _resolveConfiguredBaseUrl();

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'magnetLink': magnetLink}),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final info = TorrentBackendInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        _activeTorrents[info.infoHash] = info;
        return info;
      } else {
        debugPrint('[TorrentProvider] Failed to add torrent: ${res.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[TorrentProvider] Error adding torrent: $e');
      return null;
    }
  }

  /// Gets torrent info from backend
  Future<TorrentBackendInfo?> getTorrentInfo(String infoHash) async {
    if (_useAndroidNativeBridge) {
      if (!await _ensureBackendRunning()) {
        return null;
      }
      try {
        final raw = await _nativeBridge.getTorrentInfo(infoHash.toLowerCase());
        if (raw == null) return null;
        return TorrentBackendInfo.fromJson(raw);
      } on PlatformException catch (e) {
        debugPrint('[TorrentProvider] Native getTorrentInfo error: ${e.message}');
        return null;
      } catch (e) {
        debugPrint('[TorrentProvider] Native getTorrentInfo exception: $e');
        return null;
      }
    }

    if (!await _ensureBackendRunning()) {
      return null;
    }

    final baseUrl = await _resolveConfiguredBaseUrl();

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/torrent/$infoHash'),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return TorrentBackendInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[TorrentProvider] Error getting torrent info: $e');
      return null;
    }
  }

  /// Gets the streaming URL for a file in a torrent
  Future<String?> getStreamUrl(String infoHash, int fileIndex) async {
    if (_useAndroidNativeBridge) {
      if (!await _ensureBackendRunning()) {
        return null;
      }
      try {
        return await _nativeBridge.getStreamUrl(infoHash.toLowerCase(), fileIndex);
      } on PlatformException catch (e) {
        debugPrint('[TorrentProvider] Native getStreamUrl error: ${e.message}');
        return null;
      } catch (e) {
        debugPrint('[TorrentProvider] Native getStreamUrl exception: $e');
        return null;
      }
    }

    if (!await _ensureBackendRunning()) {
      return null;
    }

    final baseUrl = await _resolveConfiguredBaseUrl();

    // Return direct URL to backend stream endpoint
    return '$baseUrl/stream/$infoHash/$fileIndex';
  }

  /// Removes a torrent from the backend
  Future<bool> removeTorrent(String infoHash, {bool deleteFiles = false}) async {
    if (_useAndroidNativeBridge) {
      if (!await _ensureBackendRunning()) {
        return false;
      }
      try {
        return await _nativeBridge.removeTorrent(infoHash.toLowerCase(), deleteFiles: deleteFiles);
      } on PlatformException catch (e) {
        debugPrint('[TorrentProvider] Native removeTorrent error: ${e.message}');
        return false;
      } catch (e) {
        debugPrint('[TorrentProvider] Native removeTorrent exception: $e');
        return false;
      }
    }

    if (!await _ensureBackendRunning()) {
      return false;
    }

    final baseUrl = await _resolveConfiguredBaseUrl();

    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/torrent/$infoHash'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deleteFiles': deleteFiles}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 204 || res.statusCode == 200) {
        _activeTorrents.remove(infoHash);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[TorrentProvider] Error removing torrent: $e');
      return false;
    }
  }

  /// Lists all active torrents
  Future<List<TorrentBackendInfo>> listTorrents() async {
    if (_useAndroidNativeBridge) {
      if (!await _ensureBackendRunning()) {
        return [];
      }
      try {
        final list = await _nativeBridge.listTorrents();
        return list.map(TorrentBackendInfo.fromJson).toList();
      } on PlatformException catch (e) {
        debugPrint('[TorrentProvider] Native listTorrents error: ${e.message}');
        return [];
      } catch (e) {
        debugPrint('[TorrentProvider] Native listTorrents exception: $e');
        return [];
      }
    }

    if (!await _ensureBackendRunning()) {
      return [];
    }

    final baseUrl = await _resolveConfiguredBaseUrl();

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/list'),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((item) => TorrentBackendInfo.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[TorrentProvider] Error listing torrents: $e');
      return [];
    }
  }

  /// Gets a stream that periodically updates torrent info
  Stream<TorrentBackendInfo?> getTorrentStatusStream(String infoHash) async* {
    while (true) {
      final info = await getTorrentInfo(infoHash);
      yield info;
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Checks if backend is running
  Future<bool> isBackendRunning() async {
    if (_useAndroidNativeBridge) {
      try {
        final targetBaseUrl = await _resolveConfiguredBaseUrl();
        if (!_androidBridgeConfigured || _androidBridgeBaseUrl != targetBaseUrl) {
          await _nativeBridge.setBaseUrl(targetBaseUrl);
          _androidBridgeConfigured = true;
          _androidBridgeBaseUrl = targetBaseUrl;
        }
        return await _nativeBridge.health();
      } catch (_) {
        return false;
      }
    }

    final baseUrl = await _resolveConfiguredBaseUrl();
    return _checkHealth(baseUrl);
  }

  /// Stops the backend process
  Future<void> stopBackend() async {
    if (_useAndroidNativeBridge) {
      return;
    }

    if (_stopServer != null) {
      try {
        _stopServer!();
        debugPrint('[TorrentProvider] Backend stopped via FFI');
      } catch (e) {
        debugPrint('[TorrentProvider] Error stopping backend via FFI: $e');
      }
    }

    if (_windowsBackendProcess != null) {
      _windowsBackendProcess!.kill();
      _windowsBackendProcess = null;
      debugPrint('[TorrentProvider] Backend process killed (Windows)');
    }
    
    _backendStarted = false;
  }

  Future<void> syncSettingsWithBackend(AppSettings settings) async {
    final baseUrl = await _resolveConfiguredBaseUrl();
    try {
      await http.post(
        Uri.parse('$baseUrl/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'downloadLimit': 0,
          'uploadLimit': 0,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[TorrentProvider] Error syncing settings: $e');
    }
  }

  Future<Map<String, String>?> getNetworkInfo() async {
    // Robustly ensure backend is running and wait for it if necessary
    if (!await _ensureBackendRunning()) {
      debugPrint('[TorrentProvider] getNetworkInfo failed: Backend not running');
      return null;
    }
    
    final baseUrl = await _resolveConfiguredBaseUrl();
    try {
      final res = await http.get(Uri.parse('$baseUrl/network')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return Map<String, String>.from(jsonDecode(res.body));
      } else {
        debugPrint('[TorrentProvider] getNetworkInfo failed with status: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[TorrentProvider] Error getting network info: $e');
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
    debugPrint(
      '[TorrentProvider] getDetails anilist=$anilistId anidb=$anidbId '
      'slug="$slug" romaji="$romajiTitle" english="$englishTitle" '
      'source=$_searchSource',
    );
    
    // Almacenamos los datos para guardarlos en metadata.json si se inicia una descarga
    _currentAnilistId = anilistId;
    _currentAnimeData = {
      'id': anilistId,
      'title': romajiTitle,
      'titleEnglish': englishTitle,
      'slug': slug,
      // Intentaremos obtener el cover de la respuesta de Anizip o similar si es posible, 
      // pero por ahora lo dejamos listo para cuando se llame a getDetails
    };

    // Store title and ID for later use in getStreams and search methods
    _currentSearchTitle = romajiTitle;
    _currentSearchTitleEnglish = englishTitle;
    _currentSearchSlug = slug;
    _currentAniDbId = anidbId;

    final episodes = _searchSource == TorrentSearchSource.nyaa
      ? await _searchNyaa(romajiTitle, englishTitle, anilistId)
      : await _searchAnimeTosho(romajiTitle, englishTitle, anilistId);

    return AnimeDetailsResult(
      id: anilistId.toString(),
      title: romajiTitle,
      episodes: episodes,
    );
  }

  String? _currentSearchTitle;
  String? _currentSearchTitleEnglish;
  String? _currentSearchSlug;
  int? _currentAniDbId;

  /// Sets metadata for the current anime to prepare for search/download
  void setAnimeMetadata({
    required int id,
    required String title,
    String? titleEnglish,
    String? slug,
    int? anidbId,
    String? coverImage,
  }) {
    debugPrint(
      '[TorrentProvider] metadata set id=$id anidb=$anidbId slug="$slug" '
      'title="$title" english="$titleEnglish"',
    );
    _currentAnilistId = id;
    _currentSearchTitle = title;
    _currentSearchTitleEnglish = titleEnglish;
    _currentSearchSlug = slug;
    _currentAniDbId = anidbId;
    
    _currentAnimeData = {
      'id': id,
      'title': title,
      'titleEnglish': titleEnglish,
      'slug': slug,
      'anidbId': anidbId,
      'coverImage': coverImage,
      'episodes': <String, dynamic>{}, // To be populated with episode metadata
    };
  }

  /// Searches AnimeTosho for torrents using the Dart extension (API v1)
  /// Falls back to the old direct HTTP approach if extension fails.
  Future<List<EpisodeInfo>> _searchAnimeTosho(
    String romajiTitle,
    String englishTitle,
    int anilistId,
  ) async {
    // Configure the AnimeTosho extension with current anime context
    final ext = ExtensionService().animeTosho;
    if (ext != null) {
      ext.setAnimeContext(
        anidbAid: _currentAniDbId,
        romajiTitle: romajiTitle,
        englishTitle: englishTitle.isNotEmpty ? englishTitle : null,
        episodeCount: null,
        format: null,
      );
      try {
        final contextJson = jsonEncode({
          'anilistId': anilistId,
          'anidbAid': _currentAniDbId,
          'romajiTitle': romajiTitle,
          'englishTitle': englishTitle,
          'episodeCount': null,
          'format': null,
        });
        final result = await ext.getDetails(contextJson);
        if (result.episodes.isNotEmpty) {
          debugPrint('[TorrentProvider] AnimeTosho extension found ${result.episodes.length} episodes');
          return result.episodes;
        }
        debugPrint('[TorrentProvider] AnimeTosho extension returned no episodes, falling back');
      } catch (e) {
        debugPrint('[TorrentProvider] AnimeTosho extension error: $e — falling back to direct API');
      }
    }

    // Fallback: old direct AnimeTosho JSON feed
    return _searchAnimeToshoLegacy(romajiTitle, englishTitle, anilistId);
  }

  /// Legacy direct AnimeTosho search (old feed.animetosho.org/json API)
  Future<List<EpisodeInfo>> _searchAnimeToshoLegacy(
    String romajiTitle,
    String englishTitle,
    int anilistId,
  ) async {
    try {
      // Use AnimeTosho JSON feed API
      final baseUrl = 'https://feed.animetosho.org/json';
      final aidEpisodeMap = <int, Map<String, dynamic>>{};
      final titleBestEpisodeMap = <int, Map<String, dynamic>>{};
      final triedQueries = <String>{};

      if (_currentAniDbId != null && _currentAniDbId! > 0) {
        debugPrint('[TorrentProvider] AnimeTosho AID-first lookup aid=$_currentAniDbId');
        final aidTorrents = await _fetchAnimeToshoByAid(baseUrl, _currentAniDbId!);
        _collectBestEpisodesFromTorrents(aidTorrents, aidEpisodeMap);
        debugPrint(
          '[TorrentProvider] AID episodes collected=${aidEpisodeMap.length} '
          'fromTorrents=${aidTorrents.length}',
        );
      }

      final candidateTitles = <String>[
        englishTitle,
        _slugToTitle(_currentSearchSlug),
        romajiTitle,
      ].where((t) => t.trim().isNotEmpty).toList();
      debugPrint('[TorrentProvider] Fallback title candidates=${candidateTitles.join(' | ')}');

      for (final candidate in candidateTitles) {
        final query = _sanitizeTitle(candidate);
        if (query.isEmpty || triedQueries.contains(query.toLowerCase())) {
          continue;
        }
        triedQueries.add(query.toLowerCase());

        final res = await http.get(
          Uri.parse('$baseUrl?q=${Uri.encodeQueryComponent(query)}&limit=500'),
        ).timeout(const Duration(seconds: 15));

        if (res.statusCode != 200) {
          debugPrint('[TorrentProvider] AnimeTosho API error: ${res.statusCode} for query "$query"');
          continue;
        }

        final torrents = jsonDecode(res.body) as List<dynamic>;
        final candidateEpisodeMap = <int, Map<String, dynamic>>{};
        _collectBestEpisodesFromTorrents(torrents, candidateEpisodeMap);
        if (candidateEpisodeMap.length > titleBestEpisodeMap.length) {
          titleBestEpisodeMap
            ..clear()
            ..addAll(candidateEpisodeMap);
        }
        debugPrint(
          '[TorrentProvider] Query "$query" returned torrents=${torrents.length} '
          'episodes=${candidateEpisodeMap.length} bestTitleEpisodes=${titleBestEpisodeMap.length}',
        );
      }

      final episodeMap = <int, Map<String, dynamic>>{};
      if (titleBestEpisodeMap.length > aidEpisodeMap.length) {
        episodeMap.addAll(titleBestEpisodeMap);
        debugPrint(
          '[TorrentProvider] Using TITLE dataset over AID '
          '(title=${titleBestEpisodeMap.length} > aid=${aidEpisodeMap.length})',
        );
      } else if (aidEpisodeMap.isNotEmpty) {
        episodeMap.addAll(aidEpisodeMap);
        debugPrint(
          '[TorrentProvider] Using AID dataset '
          '(aid=${aidEpisodeMap.length}, titleBest=${titleBestEpisodeMap.length})',
        );
      } else {
        episodeMap.addAll(titleBestEpisodeMap);
      }

      // Convert to EpisodeInfo list
      final episodes = <EpisodeInfo>[];
      for (final entry in episodeMap.entries) {
        final epNum = entry.key;
        final data = entry.value;

        final episodeId = jsonEncode({
          'type': 'torrent',
          'source': 'animetosho',
          'anilistId': anilistId,
          'anidbId': _currentAniDbId,
          'episode': epNum,
        });

        episodes.add(EpisodeInfo(
          id: episodeId,
          number: epNum,
          title: 'Episodio $epNum',
          hasDub: data['title'].toString().toLowerCase().contains('dual') ||
                  data['title'].toString().toLowerCase().contains('latino'),
        ));
      }

      // Sort by episode number
      episodes.sort((a, b) => a.number.compareTo(b.number));

      final logTitle = englishTitle.trim().isNotEmpty ? englishTitle : romajiTitle;
      final nums = episodes.map((e) => e.number).toList();
      debugPrint('[TorrentProvider] Found ${episodes.length} episodes for $logTitle -> $nums');
      return episodes;
    } catch (e) {
      debugPrint('[TorrentProvider] Search error: $e');
      return [];
    }
  }

  void _collectBestEpisodesFromTorrents(
    List<dynamic> torrents,
    Map<int, Map<String, dynamic>> episodeMap,
  ) {
    final before = episodeMap.length;
    for (final torrent in torrents) {
      if (torrent is! Map<String, dynamic>) continue;

      final infoHash = (torrent['info_hash'] as String?) ?? '';
      if (infoHash.isEmpty) continue;

      final title = (torrent['title'] as String?) ?? '';
      if (title.isEmpty) continue;

      final seeders = (torrent['seeders'] as int?) ?? 0;

      var episodeNumber = _extractEpisodeNumber(title);
      if (episodeNumber < 0) {
        if (_isLikelyMovieReleaseTitle(title)) {
          episodeNumber = 1;
        } else {
          continue;
        }
      }

      final magnetUri = (torrent['magnet_uri'] as String?) ?? '';
      final totalSize = (torrent['total_size'] as int?) ?? 0;
      final releaseGroup = _extractReleaseGroup(title);

      final existing = episodeMap[episodeNumber];
      if (existing == null || totalSize > (existing['size'] as int? ?? 0)) {
        episodeMap[episodeNumber] = {
          'infoHash': infoHash,
          'magnet': magnetUri,
          'title': title,
          'size': totalSize,
          'seeders': seeders,
          'releaseGroup': releaseGroup,
        };
      }
    }
    final after = episodeMap.length;
    debugPrint('[TorrentProvider] Parsed torrents=${torrents.length} addedEpisodes=${after - before} totalEpisodes=$after');
  }

  Future<List<dynamic>> _fetchAnimeToshoByAid(String baseUrl, int anidbId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl?order=size&aid=$anidbId&q='),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        debugPrint('[TorrentProvider] AnimeTosho AID API error: ${res.statusCode} for aid=$anidbId');
        return const [];
      }

      final decoded = jsonDecode(res.body);
      if (decoded is List<dynamic>) {
        debugPrint('[TorrentProvider] AnimeTosho AID response aid=$anidbId torrents=${decoded.length}');
        return decoded;
      }
      return const [];
    } catch (e) {
      debugPrint('[TorrentProvider] AnimeTosho AID search error: $e');
      return const [];
    }
  }

  Future<List<EpisodeInfo>> _searchNyaa(
    String romajiTitle,
    String englishTitle,
    int anilistId,
  ) async {
    try {
      final items = await _searchNyaaItemsForTitles([romajiTitle, englishTitle]);
      final episodeMap = <int, Map<String, dynamic>>{};

      for (final item in items) {
        final infoHash = (item['infoHash'] as String?) ?? '';
        final title = (item['title'] as String?) ?? '';
        final seeders = (item['seeders'] as int?) ?? 0;
        final size = (item['size'] as int?) ?? 0;

        if (infoHash.isEmpty || title.isEmpty) continue;

        var episodeNumber = _extractEpisodeNumber(title);
        if (episodeNumber < 0) {
          if (_isLikelyMovieReleaseTitle(title)) {
            episodeNumber = 1;
          } else {
            continue;
          }
        }

        final existing = episodeMap[episodeNumber];
        if (existing == null || size > (existing['size'] as int? ?? 0)) {
          episodeMap[episodeNumber] = {
            'hash': infoHash,
            'title': title,
            'seeders': seeders,
            'size': size,
          };
        }
      }

      final episodes = <EpisodeInfo>[];
      for (final entry in episodeMap.entries) {
        final epNum = entry.key;
        final data = entry.value;
        final title = (data['title'] as String?) ?? '';

        final episodeId = jsonEncode({
          'type': 'torrent',
          'source': 'nyaa',
          'anilistId': anilistId,
          'episode': epNum,
        });

        episodes.add(EpisodeInfo(
          id: episodeId,
          number: epNum,
          title: 'Episodio $epNum',
          hasDub: title.toLowerCase().contains('dual') ||
              title.toLowerCase().contains('latino'),
        ));
      }

      episodes.sort((a, b) => a.number.compareTo(b.number));
      debugPrint('[TorrentProvider] Found ${episodes.length} Nyaa episodes for $romajiTitle');
      return episodes;
    } catch (e) {
      debugPrint('[TorrentProvider] Nyaa search error: $e');
      return [];
    }
  }

  /// Extracts release group from torrent title
  String _extractReleaseGroup(String title) {
    // Patterns like [Erai-raws], [Judas], [Subsplease], etc.
    final patterns = [
      RegExp(r'\[([^\]]+)\]'), // [Group Name]
      RegExp(r'^([^\s\-]+)\s+-'), // Group - Title
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(title);
      if (match != null && match.group(1) != null) {
        final group = match.group(1)!.trim();
        if (group.isNotEmpty && group.length < 30) {
          return group;
        }
      }
    }

    return 'Unknown';
  }

  /// Extracts episode number from torrent title
  int _extractEpisodeNumber(String title) {
    // Common patterns: S02E24, 2x24, Episode 24, E24, [24]
    final patterns = [
      RegExp(r'[Ss]\d{1,2}[\s\-_.]?[Ee](\d{1,4})'), // S02E24, S2.E24
      RegExp(r'\b\d{1,2}x(\d{1,4})\b'), // 2x24
      RegExp(r'[Ee][Pp]?[\s\-]?(\d+)'), // E01, EP01, E 01, E123
      RegExp(r'[\s\[\(-](\d+)[\s\]\)-]'), // Standalone number
      RegExp(r'[\s\-]+(\d+)[\s]+'), // " - 05 "
      RegExp(r'[\s\[\(-](\d+)v[\s\[\]-]'), // 01v2, 01v3
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(title);
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '');
        if (num != null && num > 0 && !_isLikelyResolutionOrYear(num)) {
          return num;
        }
      }
    }

    return -1;
  }

  bool _isLikelyResolutionOrYear(int value) {
    const commonResolutions = {240, 360, 480, 540, 720, 1080, 1440, 2160};
    const commonCodecs = {264, 265};
    if (commonResolutions.contains(value)) return true;
    if (commonCodecs.contains(value)) return true;
    if (value >= 1900 && value <= 2100) return true;
    if (value > 9999) return true;
    return false;
  }

  bool _isLikelyMovieReleaseTitle(String title) {
    final lower = title.toLowerCase();
    return lower.contains('movie') ||
        lower.contains('film') ||
        lower.contains('gekijouban') ||
        lower.contains('complete') ||
        lower.contains('one shot') ||
        lower.contains('oneshot');
  }

  String _sanitizeTitle(String title) {
    return title
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp("[\\[\\]\\(\\)\\{\\}:;!\"'\\.,/\\\\]+"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

    String _slugToTitle(String? slug) {
      if (slug == null) return '';
      final clean = slug.trim();
      if (clean.isEmpty) return '';
      return clean
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
    }

  @override
  Future<List<StreamLink>> getStreams(String episodeId, {String overrideType = 'sub'}) async {
    debugPrint('[TorrentProvider] getStreams for episode: $episodeId');

    try {
      final parsed = jsonDecode(episodeId) as Map<String, dynamic>;
      final anilistId = parsed['anilistId'] as int?;
      final episode = parsed['episode'] as int?;
      final parsedAniDbId = (parsed['anidbId'] as num?)?.toInt();
        final source = (parsed['source'] as String?) ??
          (_searchSource == TorrentSearchSource.nyaa ? 'nyaa' : 'animetosho');

      if (anilistId == null || episode == null) {
        debugPrint('[TorrentProvider] Invalid episodeId format');
        return [];
      }

      debugPrint(
        '[TorrentProvider] getStreams context source=$source episode=$episode '
        'anilist=$anilistId anidb=${parsedAniDbId ?? _currentAniDbId}',
      );
      // Try using the AnimeTosho extension first (API v1)
      final ext = ExtensionService().animeTosho;
      if (source == 'animetosho' && ext != null) {
        try {
          final extLinks = await ext.extractVideos(jsonEncode({
            'type': 'torrent',
            'source': 'animetosho',
            'anilistId': anilistId,
            'anidbAid': parsedAniDbId ?? _currentAniDbId,
            'anidbEid': parsed['anidbEid'],
            'episode': episode,
            'isBatch': false,
          }));
          if (extLinks.isNotEmpty) {
            debugPrint('[TorrentProvider] AnimeTosho extension returned ${extLinks.length} streams');
            return extLinks;
          }
          debugPrint('[TorrentProvider] AnimeTosho extension returned no streams, falling back');
        } catch (e) {
          debugPrint('[TorrentProvider] AnimeTosho extension extractVideos error: $e');
        }
      }

        final releases = source == 'nyaa'
          ? await _searchEpisodeReleasesNyaa(episode)
          : await _searchEpisodeReleases(anilistId, episode, anidbId: parsedAniDbId ?? _currentAniDbId);
      
      if (releases.isEmpty) {
        debugPrint(
          '[TorrentProvider] No releases found for episode $episode '
          'anidb=${parsedAniDbId ?? _currentAniDbId} '
          'titles=[$_currentSearchTitleEnglish, ${_slugToTitle(_currentSearchSlug)}, $_currentSearchTitle]',
        );
        return [];
      }

      debugPrint('[TorrentProvider] Found ${releases.length} releases for episode $episode');

      // Return each release as a separate stream option
      final streamLinks = releases.map((release) {
        final magnetLink = release['magnet'] as String;
        final releaseGroup = release['group'] as String;
        final resolution = release['resolution'] as String;
        final size = release['size'] as int;
        final seeders = release['seeders'] as int;
        final rawTitle = (release['title'] as String?) ?? '';
        final source = (release['source'] as String?) ??
            (_searchSource == TorrentSearchSource.nyaa ? 'nyaa' : 'animetosho');
        final hash = (release['hash'] as String).toLowerCase();

        final qualityStr = '$releaseGroup • $resolution • ${_formatSize(size)} • $seeders seeders';

        return StreamLink(
          url: magnetLink, // We store magnet in url temporarily
          quality: qualityStr,
          isM3u8: false,
          headers: {
            'magnet': magnetLink,
            'infoHash': hash,
            'lazyTorrent': 'true',
            'torrentTitle': rawTitle,
            'torrentSize': size.toString(),
            'torrentSeeders': seeders.toString(),
            'torrentResolution': resolution,
            'torrentGroup': releaseGroup,
            'torrentSource': source,
          },
        );
      }).toList();

      debugPrint('[TorrentProvider] Returning ${streamLinks.length} stream options');
      return streamLinks;
    } catch (e) {
      debugPrint('[TorrentProvider] getStreams error: $e');
      return [];
    }
  }

  /// Search for ALL releases of a specific episode
  Future<List<Map<String, dynamic>>> _searchEpisodeReleases(
    int anilistId,
    int episodeNum, {
    int? anidbId,
  }) async {
    try {
      final baseUrl = 'https://feed.animetosho.org/json';
      if (anidbId != null && anidbId > 0) {
        debugPrint('[TorrentProvider] Release search AID-first aid=$anidbId ep=$episodeNum');
        final releasesByAid = await _fetchFromAnimeTosho(
          baseUrl,
          null,
          episodeNum,
          anidbId: anidbId,
        );
        if (releasesByAid.isNotEmpty) {
          debugPrint('[TorrentProvider] Release search resolved by AID aid=$anidbId count=${releasesByAid.length}');
          return releasesByAid;
        }
        debugPrint('[TorrentProvider] Release search AID had no match, falling back to title');
      }

      final candidates = <String?>[
        _currentSearchTitleEnglish,
        _slugToTitle(_currentSearchSlug),
        _currentSearchTitle,
      ];

      List<Map<String, dynamic>> releases = [];
      for (final searchTitle in candidates) {
        if (searchTitle == null || searchTitle.trim().isEmpty) {
          continue;
        }
        releases = await _fetchFromAnimeTosho(baseUrl, searchTitle, episodeNum);
        if (releases.isNotEmpty) {
          debugPrint('[TorrentProvider] Release search resolved by title "$searchTitle" count=${releases.length}');
          break;
        }
      }
      
      return releases;
    } catch (e) {
      debugPrint('[TorrentProvider] getStreams error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFromAnimeTosho(
    String baseUrl,
    String? searchTitle,
    int episodeNum, {
    int? anidbId,
  }) async {
    try {
      late final Uri uri;
      if (anidbId != null && anidbId > 0) {
        uri = Uri.parse('$baseUrl?order=size&aid=$anidbId&q=');
        debugPrint('[TorrentProvider] Searching AnimeTosho by AID: $anidbId (Ep: $episodeNum)');
      } else {
        if (searchTitle == null || searchTitle.isEmpty) {
          debugPrint('[TorrentProvider] No title stored for search');
          return [];
        }
        final query = _sanitizeTitle(searchTitle);
        if (query.isEmpty) {
          return [];
        }
        debugPrint('[TorrentProvider] Searching AnimeTosho: $query (Ep: $episodeNum)');
        uri = Uri.parse('$baseUrl?q=${Uri.encodeQueryComponent(query)}&limit=500');
      }

      final res = await http.get(
        uri,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        debugPrint('[TorrentProvider] AnimeTosho API error: ${res.statusCode}');
        return [];
      }

      final torrents = jsonDecode(res.body) as List<dynamic>;
      final releases = <Map<String, dynamic>>[];
      final movieFallback = <Map<String, dynamic>>[];

      for (final torrent in torrents) {
        if (torrent is! Map<String, dynamic>) continue;

        final infoHash = (torrent['info_hash'] as String?) ?? '';
        if (infoHash.isEmpty) continue;

        final title = (torrent['title'] as String?) ?? '';
        if (title.isEmpty) continue;

        final seeders = (torrent['seeders'] as int?) ?? 0;

        // Check if this matches our episode
        final epNum = _extractEpisodeNumber(title);
        if (epNum != episodeNum) {
          if (!(episodeNum == 1 && epNum < 0 && _isLikelyMovieReleaseTitle(title))) {
            continue;
          }
        }

        final magnetUri = (torrent['magnet_uri'] as String?) ?? '';
        final totalSize = (torrent['total_size'] as int?) ?? 0;
        final resolution = _extractResolution(title);
        final releaseGroup = _extractReleaseGroup(title);

        final entry = {
          'hash': infoHash,
          'magnet': magnetUri,
          'title': title,
          'size': totalSize,
          'seeders': seeders,
          'resolution': resolution,
          'group': releaseGroup,
          'source': 'animetosho',
        };

        if (epNum == episodeNum) {
          releases.add(entry);
        } else {
          movieFallback.add(entry);
        }
      }

      if (releases.isEmpty && movieFallback.isNotEmpty && episodeNum == 1) {
        releases.addAll(movieFallback);
      }

      // Sort by seeders (best first)
      releases.sort((a, b) => (b['seeders'] as int).compareTo(a['seeders'] as int));

      debugPrint('[TorrentProvider] Found ${releases.length} releases for episode $episodeNum');
      return releases;
    } catch (e) {
      debugPrint('[TorrentProvider] _searchEpisodeReleases error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchEpisodeReleasesNyaa(int episodeNum) async {
    final candidates = <String>[];
    if (_currentSearchTitle != null && _currentSearchTitle!.isNotEmpty) {
      candidates.add(_currentSearchTitle!);
    }
    if (_currentSearchTitleEnglish != null && _currentSearchTitleEnglish!.isNotEmpty) {
      candidates.add(_currentSearchTitleEnglish!);
    }

    for (final title in candidates) {
      final releases = await _fetchFromNyaa(title, episodeNum);
      if (releases.isNotEmpty) {
        return releases;
      }
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchFromNyaa(String searchTitle, int episodeNum) async {
    try {
      final items = await _searchNyaaItemsForTitles([searchTitle]);
      final releases = <Map<String, dynamic>>[];
      final movieFallback = <Map<String, dynamic>>[];

      for (final item in items) {
        final title = (item['title'] as String?) ?? '';
        final infoHash = ((item['infoHash'] as String?) ?? '').toLowerCase();
        final seeders = (item['seeders'] as int?) ?? 0;
        final size = (item['size'] as int?) ?? 0;

        if (title.isEmpty || infoHash.isEmpty) continue;

        final extractedEp = _extractEpisodeNumber(title);
        final isEpisodeMatch = extractedEp == episodeNum;
        final isMovieMatch = episodeNum == 1 && extractedEp < 0 && _isLikelyMovieReleaseTitle(title);
        if (!isEpisodeMatch && !isMovieMatch) continue;

        final magnet = _buildMagnet(infoHash, title);
        final entry = {
          'hash': infoHash,
          'magnet': magnet,
          'title': title,
          'size': size,
          'seeders': seeders,
          'resolution': _extractResolution(title),
          'group': _extractReleaseGroup(title),
          'source': 'nyaa',
        };

        if (isEpisodeMatch) {
          releases.add(entry);
        } else {
          movieFallback.add(entry);
        }
      }

      if (releases.isEmpty && movieFallback.isNotEmpty && episodeNum == 1) {
        releases.addAll(movieFallback);
      }

      releases.sort((a, b) => (b['seeders'] as int).compareTo(a['seeders'] as int));
      return releases;
    } catch (e) {
      debugPrint('[TorrentProvider] Nyaa release search error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchNyaaItemsForTitles(List<String?> rawTitles) async {
    final allItems = <Map<String, dynamic>>[];
    final seenHashes = <String>{};

    for (final raw in rawTitles) {
      if (raw == null || raw.trim().isEmpty) continue;
      final queries = _buildNyaaQueries(raw);

      for (final query in queries) {
        final rssUrl = Uri.parse(
          'https://nyaa.si/?page=rss&c=1_0&f=0&q=${Uri.encodeQueryComponent(query)}',
        );

        final res = await http.get(rssUrl).timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) continue;

        final items = _parseNyaaItems(res.body);
        for (final item in items) {
          final hash = (item['infoHash'] as String?) ?? '';
          if (hash.isEmpty || seenHashes.contains(hash)) continue;
          seenHashes.add(hash);
          allItems.add(item);
        }
      }
    }

    return allItems;
  }

  List<String> _buildNyaaQueries(String title) {
    final full = title.trim();
    final clean = _sanitizeTitle(full);
    final beforeColon = full.split(':').first.trim();
    final beforeDash = full.split('-').first.trim();

    final queries = <String>{
      full,
      clean,
      beforeColon,
      _sanitizeTitle(beforeColon),
      beforeDash,
      _sanitizeTitle(beforeDash),
    };

    return queries.where((q) => q.isNotEmpty && q.length >= 3).toList();
  }

  List<Map<String, dynamic>> _parseNyaaItems(String xml) {
    final itemRegex = RegExp(r'<item>([\s\S]*?)</item>', multiLine: true);
    return itemRegex
        .allMatches(xml)
        .map((match) => _parseNyaaItem(match.group(1) ?? ''))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _parseNyaaItem(String itemXml) {
    String tag(String name) {
      final m = RegExp('<$name>([\\s\\S]*?)</$name>', multiLine: true).firstMatch(itemXml);
      return m?.group(1)?.trim() ?? '';
    }

    final title = _decodeXmlEntities(tag('title'));
    final infoHash = tag('nyaa:infoHash').toLowerCase();
    final seeders = int.tryParse(tag('nyaa:seeders')) ?? 0;
    final sizeStr = tag('nyaa:size');
    final size = _parseHumanSize(sizeStr);

    if (title.isEmpty || infoHash.isEmpty) return {};

    return {
      'title': title,
      'infoHash': infoHash,
      'seeders': seeders,
      'size': size,
    };
  }

  String _decodeXmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  int _parseHumanSize(String value) {
    final m = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*([KMGT]?i?B)', caseSensitive: false)
        .firstMatch(value);
    if (m == null) return 0;

    final amount = double.tryParse(m.group(1) ?? '') ?? 0;
    final unit = (m.group(2) ?? '').toUpperCase();
    final multiplier = switch (unit) {
      'B' => 1,
      'KB' || 'KIB' => 1024,
      'MB' || 'MIB' => 1024 * 1024,
      'GB' || 'GIB' => 1024 * 1024 * 1024,
      'TB' || 'TIB' => 1024 * 1024 * 1024 * 1024,
      _ => 1,
    };
    return (amount * multiplier).toInt();
  }

  String _buildMagnet(String infoHash, String title) {
    final trackers = [
      'udp://tracker.opentrackr.org:1337/announce',
      'udp://open.stealth.si:80/announce',
      'udp://tracker.torrent.eu.org:451/announce',
      'udp://tracker.cyberia.is:6969/announce',
    ];

    final dn = Uri.encodeQueryComponent(title);
    final tr = trackers.map((t) => '&tr=${Uri.encodeQueryComponent(t)}').join();
    return 'magnet:?xt=urn:btih:$infoHash&dn=$dn$tr';
  }

  String _extractResolution(String title) {
    if (title.contains('2160p')) return '4K';
    if (title.contains('1080p')) return '1080p';
    if (title.contains('720p')) return '720p';
    if (title.contains('480p')) return '480p';
    return 'Unknown';
  }

  String _formatSize(int bytes) {
    if (bytes == 0) return '0 B';
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final sizeIndex = (bytes > 0 ? (bytes.bitLength - 1) ~/ 10 : 0).clamp(0, sizes.length - 1);
    final size = bytes / (1 << (10 * sizeIndex));
    return '${size.toStringAsFixed(1)} ${sizes[sizeIndex]}';
  }

  /// Cleanup method to stop backend
  Future<void> dispose() async {
    await stopBackend();
  }
}
