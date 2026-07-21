import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/media_widgets.dart';
import 'anime_downloads_detail_page.dart';

class AnimeDownload {
  final String id;
  final String title;
  final String? coverImage;
  final int totalSize;
  final int count;
  final Map<String, dynamic> metadata;
  final List<FileSystemEntity> entities;

  AnimeDownload({
    required this.id,
    required this.title,
    this.coverImage,
    required this.totalSize,
    required this.count,
    required this.metadata,
    required this.entities,
  });
}

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<AnimeDownload> _animeDownloads = [];
  bool _loading = true;
  String? _error;
  String? _currentPath;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<String> _getBasePath() async {
    try {
      // AppSettings no longer has torrentDownloadPath
    } catch (_) {}

    if (Platform.isAndroid) {
      try {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final parts = directory.path.split('/');
          final emulatedIdx = parts.indexOf('Android');
          if (emulatedIdx != -1) {
            final base = parts.sublist(0, emulatedIdx).join('/');
            return '$base/Download/Anityng/Torrents';
          }
        }
      } catch (_) {}
      final directory = await getExternalStorageDirectory();
      return '${directory?.path}/torrents';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}${Platform.pathSeparator}torrents';
    }
  }

  Future<void> _loadDownloads() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final basePath = await _getBasePath();
      _currentPath = basePath;
      final baseDir = Directory(basePath);
      
      if (!await baseDir.exists()) {
        setState(() {
          _animeDownloads = [];
          _loading = false;
        });
        return;
      }

      final entities = await baseDir.list().toList();
      final List<AnimeDownload> animeList = [];

      for (final entity in entities) {
        if (entity is Directory) {
          final id = entity.path.split(Platform.pathSeparator).last;
          if (RegExp(r'^\d+$').hasMatch(id)) {
            // Es una carpeta de Anime ID
            final download = await _processAnimeFolder(entity, id);
            animeList.add(download);
          } else {
            // Carpeta normal (posible torrent antiguo)
            final size = await _calculateSize(entity);
            animeList.add(AnimeDownload(
              id: id,
              title: id,
              totalSize: size,
              count: 1,
              metadata: {},
              entities: [entity],
            ));
          }
        } else if (entity is File) {
          if (_isInternalFile(entity)) continue;
          
          final name = entity.path.split(Platform.pathSeparator).last;
          if (name.startsWith('.')) continue;
          
          animeList.add(AnimeDownload(
            id: name,
            title: name,
            totalSize: await entity.length(),
            count: 1,
            metadata: {},
            entities: [entity],
          ));
        }
      }

      setState(() {
        _animeDownloads = animeList;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Error al cargar descargas: $e';
        });
      }
    }
  }

  bool _isInternalFile(FileSystemEntity entity) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.startsWith('.')) return true;
    if (name == 'metadata.json') return true;
    if (name.contains('.torrent.db')) return true;
    return false;
  }

  Future<AnimeDownload> _processAnimeFolder(Directory dir, String id) async {
    String title = id;
    String? cover;
    Map<String, dynamic> metadata = {};
    int size = 0;
    int count = 0;
    final List<FileSystemEntity> items = [];

    final metadataFile = File('${dir.path}${Platform.pathSeparator}metadata.json');
    if (await metadataFile.exists()) {
      try {
        metadata = jsonDecode(await metadataFile.readAsString());
        title = metadata['title'] ?? title;
        cover = metadata['coverImage'];
      } catch (_) {}
    }

    final entities = await dir.list().toList();
    for (final e in entities) {
      if (_isInternalFile(e)) continue;
      items.add(e);
      count++;
      if (e is File) {
        size += await e.length();
      } else if (e is Directory) {
        size += await _calculateSize(e);
      }
    }

    return AnimeDownload(
      id: id,
      title: title,
      coverImage: cover,
      totalSize: size,
      count: count,
      metadata: metadata,
      entities: items,
    );
  }

  Future<int> _calculateSize(Directory dir) async {
    int totalSize = 0;
    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (_) {}
    return totalSize;
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  Future<void> _deleteAnime(AnimeDownload anime) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar descargas'),
        content: Text('¿Quieres eliminar todo el contenido de "${anime.title}" y liberar ${_formatSize(anime.totalSize)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error, 
              foregroundColor: Theme.of(context).colorScheme.onError
            ),
            child: const Text('Eliminar Todo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Obtenemos la carpeta base si es un ID de anime
        if (RegExp(r'^\d+$').hasMatch(anime.id)) {
          final basePath = await _getBasePath();
          final dir = Directory('$basePath${Platform.pathSeparator}${anime.id}');
          if (await dir.exists()) await dir.delete(recursive: true);
        } else {
          // Si son archivos sueltos o carpetas de torrent viejas
          for (final entity in anime.entities) {
            if (await entity.exists()) await entity.delete(recursive: true);
          }
        }
        
        _loadDownloads();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminado correctamente')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topInset = Platform.isWindows ? 42.0 : MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: colorScheme.error)))
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        padding: EdgeInsets.fromLTRB(20, topInset + 10, 20, 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primaryContainer.withValues(alpha: 0.3),
                              colorScheme.surface,
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Biblioteca',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1,
                                      ),
                                ),
                                Text(
                                  'Archivos descargados en el dispositivo',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: _loadDownloads,
                              icon: const Icon(Icons.refresh_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_animeDownloads.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(colorScheme),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final anime = _animeDownloads[index];
                              return _buildAnimeCard(anime, colorScheme);
                            },
                            childCount: _animeDownloads.length,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_off_rounded, size: 64, color: colorScheme.outlineVariant),
          ),
          const SizedBox(height: 24),
          const Text('Sin descargas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('Tu biblioteca local está vacía por ahora', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          if (_currentPath != null) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Directorio: $_currentPath',
                style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimeCard(AnimeDownload anime, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnimeDownloadsDetailPage(
                  animeId: anime.id,
                  animeTitle: anime.title,
                  animeCover: anime.coverImage,
                  metadata: anime.metadata,
                  entities: anime.entities,
                  basePath: _currentPath!,
                  onRefreshRequested: _loadDownloads,
                ),
              ),
            );
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 90,
                  child: anime.coverImage != null
                      ? AppCachedImage(
                          anime.coverImage!,
                          fit: BoxFit.cover,
                        )
                      : _buildPlaceholderCover(colorScheme),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          anime.title,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: -0.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _InfoBadge(
                              icon: Icons.folder_open_rounded,
                              label: '${anime.count} arch.',
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            _InfoBadge(
                              icon: Icons.storage_rounded,
                              label: _formatSize(anime.totalSize),
                              color: colorScheme.secondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error.withValues(alpha: 0.7)),
                    onPressed: () => _deleteAnime(anime),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie_rounded, color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

