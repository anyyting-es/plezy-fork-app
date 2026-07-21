import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path_provider;
import '../utils/app_logger.dart';

/// Represents a snapshot of an active torrent from the Go backend.
class TorrentInfo {
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

  TorrentInfo({
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
  });

  factory TorrentInfo.fromJson(Map<String, dynamic> json) {
    final filesJson = (json['files'] as List<dynamic>?) ?? const [];
    return TorrentInfo(
      infoHash: (json['infoHash'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      size: (json['size'] as int?) ?? 0,
      downloaded: (json['downloaded'] as int?) ?? 0,
      downloadSpeed: (json['downloadSpeed'] as num?)?.toDouble() ?? 0.0,
      uploadSpeed: (json['uploadSpeed'] as num?)?.toDouble() ?? 0.0,
      seeders: (json['seeders'] as int?) ?? 0,
      leechers: (json['leechers'] as int?) ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      files: filesJson.map((f) => TorrentFile.fromJson(f as Map<String, dynamic>)).toList(),
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

/// Service that spawns, manages, and communicates with the local Go torrent daemon.
class TorrentEngineService {
  TorrentEngineService._();
  static final TorrentEngineService instance = TorrentEngineService._();

  Process? _backendProcess;
  int? _port;
  bool _starting = false;
  Completer<bool>? _startCompleter;

  bool get isRunning => _backendProcess != null && _port != null;
  String get baseUrl => isRunning ? 'http://127.0.0.1:$_port' : '';

  /// Resolves the default download directory for torrents
  Future<String> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final extDir = await path_provider.getExternalStorageDirectory();
      return '${extDir?.path}/torrents';
    } else {
      final appDocDir = await path_provider.getApplicationDocumentsDirectory();
      return '${appDocDir.path}${Platform.pathSeparator}torrents';
    }
  }

  /// Locates the Go backend binary based on platform and current environment.
  /// On Android, extracts the binary from assets on first run.
  Future<String?> _findBackendBinary() async {
    // Android: extract the arch-appropriate binary from assets to a writable dir
    if (Platform.isAndroid) {
      return _findOrExtractAndroidBinary();
    }

    final exeName = Platform.isWindows ? 'aniting-backend.exe' : 'aniting-backend';

    // 1. Check next to the Flutter runner executable (production release layout)
    final runnerDir = Directory(Platform.resolvedExecutable).parent.path;
    final prodPath = '$runnerDir${Platform.pathSeparator}$exeName';
    if (await File(prodPath).exists()) {
      return prodPath;
    }

    // 2. Check development path relative to workspace root (Aniting/backend/aniting-backend)
    final projectDir = Directory.current.path;
    final devPath = '$projectDir${Platform.pathSeparator}backend${Platform.pathSeparator}$exeName';
    if (await File(devPath).exists()) {
      return devPath;
    }

    return null;
  }

  /// Extracts the Go backend binary from Flutter assets to the app files dir.
  /// Returns the path to the extracted executable, or null on failure.
  Future<String?> _findOrExtractAndroidBinary() async {
    try {
      // Determine CPU ABI
      final abi = await _getAndroidAbi();
      final assetName = 'backend/aniting-backend-$abi';

      final filesDir = await path_provider.getApplicationSupportDirectory();
      final destFile = File('${filesDir.path}/aniting-backend');

      // Check if asset exists for this ABI
      ByteData? assetData;
      try {
        assetData = await rootBundle.load(assetName);
      } catch (_) {
        appLogger.e('[torrent] No bundled backend found for ABI: $abi (asset: $assetName)');
        return null;
      }

      // Write binary to disk
      final bytes = assetData.buffer.asUint8List();
      await destFile.writeAsBytes(bytes, flush: true);

      // Make executable
      await Process.run('chmod', ['+x', destFile.path]);

      appLogger.d('[torrent] Extracted backend binary to ${destFile.path} (${bytes.length} bytes)');
      return destFile.path;
    } catch (e) {
      appLogger.e('[torrent] Failed to extract Android backend binary: $e');
      return null;
    }
  }

  /// Returns the primary ABI of the current Android device (e.g. "arm64", "x86_64").
  Future<String> _getAndroidAbi() async {
    try {
      final result = await Process.run('getprop', ['ro.product.cpu.abi']);
      final abi = (result.stdout as String).trim();
      // Map Android ABI strings to our asset naming convention
      if (abi.startsWith('arm64')) return 'arm64';
      if (abi.startsWith('armeabi')) return 'arm';
      if (abi.startsWith('x86_64')) return 'x86_64';
      if (abi.startsWith('x86')) return 'x86';
      return 'arm64'; // default fallback
    } catch (_) {
      return 'arm64';
    }
  }

  /// Starts the local Go torrent engine if it isn't already running.
  Future<bool> start() async {
    if (isRunning) return true;
    if (_starting) return _startCompleter!.future;

    _starting = true;
    final completer = Completer<bool>();
    _startCompleter = completer;

    try {
      // 1. Clean up potential orphaned backend instances
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/f', '/im', 'aniting-backend.exe']);
      } else {
        await Process.run('pkill', ['-f', 'aniting-backend']);
      }
    } catch (_) {}

    try {
      final binaryPath = await _findBackendBinary();
      if (binaryPath == null) {
        appLogger.e('[torrent] Go backend binary not found. Make sure to build it first.');
        _starting = false;
        completer.complete(false);
        return false;
      }

      final downloadDir = await getDownloadDirectory();
      appLogger.d('[torrent] Starting engine at $binaryPath with data dir: $downloadDir');

      _backendProcess = await Process.start(
        binaryPath,
        [downloadDir],
        mode: ProcessStartMode.normal,
      );

      final portCompleter = Completer<int>();

      // Read output stream to catch the port printed at start
      _backendProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        appLogger.d('[torrent-backend] $line');
        if (line.contains('ANITING_BACKEND_PORT=')) {
          final portStr = line.split('=').last.trim();
          final portNum = int.tryParse(portStr);
          if (portNum != null && !portCompleter.isCompleted) {
            portCompleter.complete(portNum);
          }
        }
      });

      _backendProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        appLogger.e('[torrent-backend ERR] $line');
      });

      // Wait for port resolution with a 15-second timeout
      final resolvedPort = await portCompleter.future.timeout(const Duration(seconds: 15));
      _port = resolvedPort;

      appLogger.i('[torrent] Engine started successfully on port $_port');
      _starting = false;
      completer.complete(true);
      return true;

    } catch (e, stack) {
      appLogger.e('[torrent] Failed to start engine', error: e, stackTrace: stack);
      _backendProcess?.kill();
      _backendProcess = null;
      _port = null;
      _starting = false;
      if (!completer.isCompleted) completer.complete(false);
      return false;
    }
  }

  /// Stops the Go daemon.
  Future<void> stop() async {
    if (_backendProcess != null) {
      appLogger.i('[torrent] Stopping torrent engine...');
      _backendProcess!.kill();
      _backendProcess = null;
      _port = null;
    }
  }

  // ─── API Client Endpoints ──────────────────────────────────────────────────

  Future<bool> checkHealth() async {
    if (!isRunning) return false;
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Adds a magnet link or hash to the daemon. Returns the [TorrentInfo] metadata.
  Future<TorrentInfo?> addTorrent(String magnetOrHash) async {
    if (!isRunning && !await start()) return null;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'magnetLink': magnetOrHash}),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return TorrentInfo.fromJson(decoded);
      } else {
        appLogger.w('[torrent] Failed to add torrent: ${res.body}');
      }
    } catch (e) {
      appLogger.e('[torrent] Error adding torrent', error: e);
    }
    return null;
  }

  /// Gets the statistics of a specific active torrent.
  Future<TorrentInfo?> getTorrentInfo(String infoHash) async {
    if (!isRunning) return null;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/torrent/${infoHash.toLowerCase()}'),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return TorrentInfo.fromJson(decoded);
      }
    } catch (e) {
      appLogger.e('[torrent] Error getting torrent info for $infoHash', error: e);
    }
    return null;
  }

  /// Removes a torrent from the active list.
  Future<bool> removeTorrent(String infoHash, {bool deleteFiles = true}) async {
    if (!isRunning) return false;
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/torrent/${infoHash.toLowerCase()}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deleteFiles': deleteFiles}),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (e) {
      appLogger.e('[torrent] Error removing torrent $infoHash', error: e);
      return false;
    }
  }

  /// Lists all active torrents currently managed by the Go backend.
  Future<List<TorrentInfo>> listTorrents() async {
    if (!isRunning) return const [];
    try {
      final res = await http.get(Uri.parse('$baseUrl/list')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as List<dynamic>;
        return decoded.map((item) => TorrentInfo.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      appLogger.e('[torrent] Error listing active torrents', error: e);
    }
    return const [];
  }

  /// Returns the stream URL that should be fed into the media player.
  /// Format: `http://127.0.0.1:<port>/stream/<infoHash>/<fileIndex>`
  Future<String?> getStreamUrl(String infoHash, int fileIndex) async {
    if (!isRunning && !await start()) return null;
    return '$baseUrl/stream/${infoHash.toLowerCase()}/$fileIndex';
  }
}
