import 'dart:async';
import '../utils/app_logger.dart';
import 'torrent_engine_service.dart';

class TorrentPlaybackService {
  TorrentPlaybackService._();
  static final TorrentPlaybackService instance = TorrentPlaybackService._();

  /// Resolves a magnet link or infohash to a local HTTP streaming URL.
  ///
  /// If it is a multi-file torrent (e.g., a full TV season), it attempts to match
  /// the file name to the desired season/episode indices.
  /// If no match is found or it's a movie, it defaults to the largest video file.
  Future<String?> resolveAndStream(
    String magnetOrHash, {
    int? seasonIndex,
    int? episodeIndex,
    void Function(String)? onProgressUpdate,
  }) async {
    onProgressUpdate?.call('Iniciando motor de torrents...');
    
    // 1. Ensure Go engine is running
    final ok = await TorrentEngineService.instance.start();
    if (!ok) {
      throw Exception('No se pudo iniciar el motor de torrents. Verifica la consola de logs.');
    }

    onProgressUpdate?.call('Obteniendo metadatos del torrent (esto puede tardar unos segundos)...');

    // 2. Add torrent and wait for metadata
    final info = await TorrentEngineService.instance.addTorrent(magnetOrHash);
    if (info == null) {
      throw Exception('Error al descargar los metadatos del torrent. ¿Tiene seeders activos?');
    }

    onProgressUpdate?.call('Analizando archivos en el torrent...');

    // 3. Find target file index
    int targetIndex = 0;
    if (info.files.isNotEmpty) {
      targetIndex = _findBestFileIndex(
        info.files,
        seasonIndex: seasonIndex,
        episodeIndex: episodeIndex,
      );
    }

    final targetFile = info.files[targetIndex];
    appLogger.i('[torrent-playback] Selected file index $targetIndex: "${targetFile.path}" (${_formatSize(targetFile.size)})');

    onProgressUpdate?.call('Conectando con peers...');

    // 4. Return local stream URL
    return await TorrentEngineService.instance.getStreamUrl(info.infoHash, targetIndex);
  }

  /// Helper to choose the best file index from the torrent file list.
  int _findBestFileIndex(
    List<TorrentFile> files, {
    int? seasonIndex,
    int? episodeIndex,
  }) {
    final videoExtensions = {'.mkv', '.mp4', '.webm', '.avi', '.mov', '.m4v'};
    
    // Filter only video files
    final videoFiles = files.where((f) {
      final ext = f.path.substring(f.path.lastIndexOf('.')).toLowerCase();
      return videoExtensions.contains(ext);
    }).toList();

    if (videoFiles.isEmpty) {
      // Fallback to largest file overall if no typical video extension matches
      return _getLargestFileIndex(files);
    }

    // If it's a TV show and we have target season/episode indices
    if (seasonIndex != null && episodeIndex != null) {
      final s = seasonIndex;
      final ep = episodeIndex;

      // Try multiple typical naming conventions (e.g. S01E02, s1e2, 1x02, etc.)
      final patterns = [
        RegExp('s0*${s}e0*$ep\\b', caseSensitive: false),
        RegExp('\\b0*${s}x0*$ep\\b', caseSensitive: false),
        RegExp('ep0*$ep\\b', caseSensitive: false),
        RegExp('\\b0*$ep\\b'), // last resort: look for the raw episode number as a standalone token
      ];

      for (final pattern in patterns) {
        for (final vf in videoFiles) {
          if (pattern.hasMatch(vf.path)) {
            return vf.index;
          }
        }
      }
    }

    // Default: choose the largest video file (standard for movies)
    return _getLargestFileIndex(videoFiles);
  }

  int _getLargestFileIndex(List<TorrentFile> files) {
    int largestIdx = 0;
    int maxSize = 0;
    for (final f in files) {
      if (f.size > maxSize) {
        maxSize = f.size;
        largestIdx = f.index;
      }
    }
    return largestIdx;
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }
}
