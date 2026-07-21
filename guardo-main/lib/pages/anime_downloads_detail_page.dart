import 'dart:io';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/app_models.dart' as models;
import '../widgets/media_widgets.dart';
import 'watch/watch_page.dart';

class AnimeDownloadsDetailPage extends StatefulWidget {
  final String animeId;
  final String animeTitle;
  final String? animeCover;
  final Map<String, dynamic> metadata;
  final List<FileSystemEntity> entities;
  final String basePath;
  final Function() onRefreshRequested;

  const AnimeDownloadsDetailPage({
    super.key,
    required this.animeId,
    required this.animeTitle,
    this.animeCover,
    required this.metadata,
    required this.entities,
    required this.basePath,
    required this.onRefreshRequested,
  });

  @override
  State<AnimeDownloadsDetailPage> createState() => _AnimeDownloadsDetailPageState();
}

class _AnimeDownloadsDetailPageState extends State<AnimeDownloadsDetailPage> {
  late List<FileSystemEntity> _entities;
  late Map<String, dynamic> _episodesMetadata;

  @override
  void initState() {
    super.initState();
    _entities = widget.entities;
    _episodesMetadata = widget.metadata['episodes'] ?? {};
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

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    final name = entity.path.split(Platform.pathSeparator).last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text('¿Estás seguro de que quieres eliminar "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final meta = _episodesMetadata.values.firstWhere(
          (m) {
            final tName = m['torrentName']?.toString();
            if (tName != null && tName.isNotEmpty && name == tName) return true;
            final epNumStr = m['number']?.toString() ?? '';
            final epNumInt = m['number']?.toInt().toString() ?? '';
            return name.contains('Episode $epNumStr') || 
                   name.contains('Episode $epNumInt') ||
                   name.contains(' - $epNumInt ') ||
                   name.contains(' $epNumInt ') ||
                   name.contains(m['id'] ?? '---');
          },
          orElse: () => null,
        );
        
        final infoHash = meta?['infoHash']?.toString();
        if (infoHash != null && infoHash.isNotEmpty) {
            try {
              await ApiService.instance.torrent.removeTorrent(infoHash);
              await Future.delayed(const Duration(milliseconds: 500));
            } catch (_) {}
        }

        await entity.delete(recursive: true);
        setState(() {
          _entities.removeWhere((e) => e.path == entity.path);
        });
        widget.onRefreshRequested();
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

  bool _isInternalFile(FileSystemEntity entity) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.startsWith('.')) return true;
    if (name == 'metadata.json') return true;
    if (name.contains('.torrent.db')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Si no quedan entidades, cerramos la página
    if (_entities.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }

    final filteredEntities = _entities.where((e) => !_isInternalFile(e)).toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Poster and Title
            SizedBox(
              width: 280,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Left align the column content
                  children: [
                    // Back Button aligned with poster (minimal style)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 12),
                    // Poster
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: widget.animeCover != null
                              ? AppCachedImage(
                                  widget.animeCover!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(Icons.movie_rounded, size: 64, color: colorScheme.primary),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Title
                    Center(
                      child: Text(
                        widget.animeTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (widget.metadata['type'] != null || widget.metadata['year'] != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          '${widget.metadata['type'] ?? ''} ${widget.metadata['year'] ?? ''}'.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Divider
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),

            // Right Column: Episode List
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Row(
                      children: [
                        Text(
                          'CONTENIDO EN DISCO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: colorScheme.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      itemCount: filteredEntities.length,
                      itemBuilder: (context, index) {
                        final entity = filteredEntities[index];
                        final name = entity.path.split(Platform.pathSeparator).last;
                        
                        var meta = _episodesMetadata.values.firstWhere(
                          (m) {
                            final tName = m['torrentName']?.toString();
                            if (tName != null && tName.isNotEmpty && name == tName) return true;
                            final epNumStr = m['number'].toString();
                            final epNumInt = m['number'].toInt().toString();
                            return name.contains('Episode $epNumStr') || 
                                   name.contains('Episode $epNumInt') ||
                                   name.contains(' - $epNumInt ') ||
                                   name.contains(' $epNumInt ') ||
                                   name.contains(m['id'] ?? '---');
                          },
                          orElse: () => null,
                        );

                        return _buildEpisodeItem(entity, name, meta, colorScheme);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeItem(FileSystemEntity entity, String name, dynamic meta, ColorScheme colorScheme) {
    final title = meta?['title'] ?? (meta?['number'] != null ? 'Episodio ${meta['number']}' : name);
    // Use banner as fallback for episode thumbnails if they are empty
    final cover = meta?['coverImage'] ?? widget.metadata['bannerImage'] ?? widget.animeCover;
    final isFile = entity is File;

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
          onTap: () => _startPlayback(meta, entity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          cover != null
                              ? AppCachedImage(cover, fit: BoxFit.cover)
                              : _buildEpPlaceholder(colorScheme),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 30,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black54],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: -0.2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // File name label (blueish tag)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), size: 20),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteEntity(entity);
                        } else if (value == 'external') {
                          _openExternally(entity.path);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'external',
                          child: Row(
                            children: [
                              Icon(Icons.open_in_new_rounded, size: 18),
                              SizedBox(width: 12),
                              Text('Abrir externamente'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: colorScheme.error),
                              const SizedBox(width: 12),
                              const Text('Eliminar archivo'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.storage_rounded, size: 12, color: colorScheme.outline),
                    const SizedBox(width: 6),
                    FutureBuilder<int>(
                      future: isFile ? (entity).length() : _calculateSize(entity as Directory),
                      builder: (context, snapshot) {
                        final sizeStr = snapshot.hasData ? _formatSize(snapshot.data!) : '...';
                        return Text(
                          sizeStr,
                          style: TextStyle(fontSize: 10, color: colorScheme.outline, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isFile ? 'ARCHIVO' : 'CARPETA',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openExternally(String path) {
    if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', '', path]);
    } else {
      // For other platforms, we might need url_launcher, but prioritizing Windows for now as requested
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abrir externamente no soportado en esta plataforma')));
    }
  }

  void _startPlayback(dynamic meta, FileSystemEntity entity) {
    if (entity is! File) return;
    
    final int episodeNumber = (meta?['number'] as num?)?.toInt() ?? 1;
    
    // Map existing metadata episodes to models.EpisodeInfo
    final List<models.EpisodeInfo> episodes = [];
    _episodesMetadata.forEach((key, val) {
       episodes.add(models.EpisodeInfo(
         id: val['id'] ?? key,
         number: (val['number'] as num?)?.toInt() ?? 0,
         title: val['title'] ?? 'Episodio ${val['number']}',
         image: val['coverImage'] ?? widget.animeCover,
       ));
    });
    
    if (episodes.isEmpty) {
      // Fallback if no metadata
       episodes.add(models.EpisodeInfo(
         id: 'local-${widget.animeId}-$episodeNumber',
         number: episodeNumber,
         title: widget.animeTitle,
         image: widget.animeCover,
       ));
    }
    
    // Ensure the list is sorted
    episodes.sort((a, b) => a.number.compareTo(b.number));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WatchPage(
          providerId: 'local',
          anime: widget.metadata,
          episodes: episodes,
          tvdbEpisodes: const {},
          initialEpisodeNumber: episodeNumber,
        ),
      ),
    );
  }

  Widget _buildEpPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.play_circle_outline_rounded, color: colorScheme.outline.withValues(alpha: 0.5)),
    );
  }

  Future<int> _calculateSize(Directory dir) async {
    int totalSize = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) totalSize += await entity.length();
      }
    } catch (_) {}
    return totalSize;
  }
}
