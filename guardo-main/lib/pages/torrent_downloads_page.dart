import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/torrent_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/app_models.dart';
import '../widgets/media_widgets.dart';
import 'anime_downloads_detail_page.dart';


class TorrentDownloadsPage extends StatefulWidget {
  const TorrentDownloadsPage({
    super.key,
    this.embeddedMode = false,
    this.initialTabIndex = 0,
  });

  final bool embeddedMode;
  final int initialTabIndex;

  @override
  State<TorrentDownloadsPage> createState() => _TorrentDownloadsPageState();
}

class LocalAnimeDownload {
  final String id;
  final String title;
  final String? coverImage;
  final int totalSize;
  final int count;
  final Map<String, dynamic> metadata;
  final List<FileSystemEntity> entities;

  LocalAnimeDownload({
    required this.id,
    required this.title,
    this.coverImage,
    required this.totalSize,
    required this.count,
    required this.metadata,
    required this.entities,
  });
}

class _LocalDownloadsSnapshot {
  final List<LocalAnimeDownload> downloads;
  final String basePath;

  const _LocalDownloadsSnapshot({
    required this.downloads,
    required this.basePath,
  });
}

class _TorrentDownloadsPageState extends State<TorrentDownloadsPage> {
  final _api = ApiService.instance;
  final _storage = StorageService.instance;

  List<TorrentBackendInfo> _torrents = _cachedTorrents;
  List<LocalAnimeDownload> _localDownloads = _cachedLocalDownloads;
  bool _loading = true;
  String? _error;
  String? _currentPath;
  Timer? _pollTimer;
  Map<String, String>? _networkInfo;
  AppSettings? _settings;
  int _activeTabIndex = 0;
  
  // Cache estático para persistir entre recreaciones del widget
  static List<TorrentBackendInfo> _cachedTorrents = [];
  static List<LocalAnimeDownload> _cachedLocalDownloads = [];
  static bool _hasLoadedOnce = false;
  final _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activeTabIndex = widget.initialTabIndex;
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted && !_hasLoadedOnce) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _api.torrent.listTorrents(),
        _loadLocalDownloads(),
        _api.torrent.getNetworkInfo(),
        _storage.getAppSettings(),
      ]);
      final list = results[0] as List<TorrentBackendInfo>;
      final snapshot = results[1] as _LocalDownloadsSnapshot;
      final netInfo = results[2] as Map<String, String>?;
      final settings = results[3] as AppSettings;

      list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      snapshot.downloads.sort((a, b) => b.totalSize.compareTo(a.totalSize));

      if (!mounted) return;
      setState(() {
        _torrents = list;
        _cachedTorrents = list;
        _localDownloads = snapshot.downloads;
        _cachedLocalDownloads = snapshot.downloads;
        _currentPath = snapshot.basePath;
        _networkInfo = netInfo;
        _settings = settings;
        _loading = false;
        _error = null;
        _hasLoadedOnce = true;
        if (_pathController.text != snapshot.basePath) {
          _pathController.text = snapshot.basePath;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar estado de torrents: $e';
      });
    }
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
    }

    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}${Platform.pathSeparator}torrents';
  }

  bool _isInternalFile(FileSystemEntity entity) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.startsWith('.')) return true;
    if (name == 'metadata.json') return true;
    if (name.contains('.torrent.db')) return true;
    return false;
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

  Future<LocalAnimeDownload> _processAnimeFolder(Directory dir, String id) async {
    String title = id;
    String? cover;
    Map<String, dynamic> metadata = {};
    int size = 0;
    int count = 0;
    final items = <FileSystemEntity>[];

    final metadataFile = File('${dir.path}${Platform.pathSeparator}metadata.json');
    if (await metadataFile.exists()) {
      try {
        metadata = jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
        title = metadata['title']?.toString() ?? title;
        cover = metadata['coverImage']?.toString();
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

    return LocalAnimeDownload(
      id: id,
      title: title,
      coverImage: cover,
      totalSize: size,
      count: count,
      metadata: metadata,
      entities: items,
    );
  }

  Future<_LocalDownloadsSnapshot> _loadLocalDownloads() async {
    final basePath = await _getBasePath();
    final baseDir = Directory(basePath);
    final animeList = <LocalAnimeDownload>[];

    if (!await baseDir.exists()) {
      return _LocalDownloadsSnapshot(downloads: const [], basePath: basePath);
    }

    final entities = await baseDir.list().toList();
    for (final entity in entities) {
      if (entity is Directory) {
        final id = entity.path.split(Platform.pathSeparator).last;
        if (RegExp(r'^\d+$').hasMatch(id)) {
          animeList.add(await _processAnimeFolder(entity, id));
        } else {
          final size = await _calculateSize(entity);
          animeList.add(
            LocalAnimeDownload(
              id: id,
              title: id,
              totalSize: size,
              count: 1,
              metadata: const {},
              entities: [entity],
            ),
          );
        }
      } else if (entity is File) {
        if (_isInternalFile(entity)) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.')) continue;
        animeList.add(
          LocalAnimeDownload(
            id: name,
            title: name,
            totalSize: await entity.length(),
            count: 1,
            metadata: const {},
            entities: [entity],
          ),
        );
      }
    }

    return _LocalDownloadsSnapshot(downloads: animeList, basePath: basePath);
  }

  Future<void> _deleteAnime(LocalAnimeDownload anime) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar descargas'),
        content: Text('¿Quieres eliminar "${anime.title}" y liberar ${_formatSize(anime.totalSize)}?'),
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

    if (confirmed != true) return;

    try {
      if (RegExp(r'^\d+$').hasMatch(anime.id)) {
        final basePath = await _getBasePath();
        final dir = Directory('$basePath${Platform.pathSeparator}${anime.id}');
        if (await dir.exists()) await dir.delete(recursive: true);
      } else {
        for (final entity in anime.entities) {
          if (await entity.exists()) {
            await entity.delete(recursive: true);
          }
        }
      }

      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Descarga eliminada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double value = bytes.toDouble();
    while (value >= 1024 && i < suffixes.length - 1) {
      value /= 1024;
      i++;
    }
    final precision = value >= 100 ? 0 : 1;
    return '${value.toStringAsFixed(precision)} ${suffixes[i]}';
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    final whole = bytesPerSec.round();
    return '${_formatSize(whole)}/s';
  }

  bool _isSeeding(TorrentBackendInfo t) {
    return t.progress >= 99.95 || (t.downloadSpeed <= 0.01 && t.uploadSpeed > 0.01);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topInset = Platform.isWindows ? 42.0 : MediaQuery.of(context).padding.top;
    final isOled = _settings?.oledBlack ?? false;
    final scaffoldBg = isOled ? Colors.black : colorScheme.surface;
    final sidebarBg = const Color(0xFF000000);
    
    final orientation = MediaQuery.of(context).orientation;
    final isVertical = orientation == Orientation.portrait;

    final content = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, isVertical ? 24 : 52, 24, 10),
            child: Row(
              children: [
                if (isVertical) ...[
                  Builder(
                    builder: (context) => IconButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: Icon(LucideIcons.menu, size: 28),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _getTabTitle(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_activeTabIndex),
                child: _buildCurrentTabView(colorScheme),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.embeddedMode) {
      return Column(
        children: [
          Expanded(child: _buildCurrentTabView(colorScheme)),
        ],
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      drawer: isVertical 
          ? Drawer(
              backgroundColor: sidebarBg,
              width: 260,
              child: _buildSidebarContent(topInset, isDrawer: true),
            )
          : null,
      body: Row(
        children: [
          if (!isVertical)
            _buildSidebarContent(topInset),
          if (!isVertical) const SizedBox(width: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildSidebarContent(double topInset, {bool isDrawer = false}) {
    final sidebarBg = const Color(0xFF000000);
    
    return Container(
      width: isDrawer ? null : 200,
      padding: EdgeInsets.only(
        top: isDrawer ? 48 : topInset + 10, 
        left: 16, 
        right: 16
      ),
      decoration: BoxDecoration(
        color: sidebarBg,
        border: isDrawer 
            ? null 
            : Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.03))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDrawer) ...[
             const Padding(
               padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
               child: Text(
                 'Anityng',
                 style: TextStyle(
                   fontSize: 24,
                   fontWeight: FontWeight.w900,
                   letterSpacing: -1,
                 ),
               ),
             ),
             const SizedBox(height: 10),
          ] else ...[
            const SizedBox(height: 20),
          ],
          _buildSidebarItem(0, 'Actividad', LucideIcons.download, Colors.white),
          _buildSidebarItem(1, 'Biblioteca', LucideIcons.folder, Colors.white),
          _buildSidebarItem(2, 'Debrid', LucideIcons.cloud, Colors.white),
          _buildSidebarItem(3, 'Ajustes', LucideIcons.settings, Colors.white),
          const Spacer(),
          Center(
            child: IconButton(
              onPressed: () {
                _refresh();
                if (isDrawer) Navigator.pop(context);
              },
              icon: Icon(LucideIcons.refreshCw, size: 20),
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getTabTitle() {
    switch (_activeTabIndex) {
      case 0: return 'Actividad Actual';
      case 1: return 'Biblioteca Local';
      case 2: return 'Real-Debrid Sync';
      case 3: return 'Ajustes del Motor';
      default: return 'Descargas';
    }
  }

  Widget _buildSidebarItem(int index, String label, IconData icon, Color color) {
    final isActive = _activeTabIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _activeTabIndex = index);
            if (MediaQuery.of(context).orientation == Orientation.portrait) {
              Navigator.pop(context);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.black : Colors.white60,
                  size: 18,
                ),
                const SizedBox(width: 12),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                    color: isActive ? Colors.black : Colors.white60,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabView(ColorScheme colorScheme) {
    if (_loading && _torrents.isEmpty && _localDownloads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_activeTabIndex) {
      case 0:
        return _buildActiveTorrentsView(colorScheme);
      case 1:
        return _buildLocalLibraryView(colorScheme);
      case 2:
        return _buildDebridPlaceholder(colorScheme);
      case 3:
        return _buildSettingsView(colorScheme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildErrorView(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: () => _refresh(), child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTorrentsView(ColorScheme colorScheme) {
    if (_torrents.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.cloud_off_rounded,
        title: 'Sin actividad',
        subtitle: 'Tus descargas activas aparecerán aquí.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _torrents.length,
      itemBuilder: (context, index) {
        final t = _torrents[index];
        return _TorrentItem(
          torrent: t,
          isSeeding: _isSeeding(t),
          formatSize: _formatSize,
          formatSpeed: _formatSpeed,
        );
      },
    );
  }

  Widget _buildLocalLibraryView(ColorScheme colorScheme) {
    if (_localDownloads.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.folder_open_rounded,
        title: 'Biblioteca vacía',
        subtitle: 'Los archivos completados se mostrarán aquí.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _localDownloads.length,
      itemBuilder: (context, index) {
        final anime = _localDownloads[index];
        return _LocalAnimeCard(
          anime: anime,
          colorScheme: colorScheme,
          currentPath: _currentPath,
          onRefresh: () => _refresh(),
          onDelete: () => _deleteAnime(anime),
          formatSize: _formatSize,
        );
      },
    );
  }

  Widget _buildDebridPlaceholder(ColorScheme colorScheme) {
    return const _EmptyPanel(
      icon: Icons.diamond_rounded,
      title: 'Debrid Downloads',
      subtitle: 'Próximamente: Integración directa con servicios Debrid.',
    );
  }

  Widget _buildSettingsView(ColorScheme colorScheme) {
    if (_settings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSettingsHeader('LIMITADOR DE VELOCIDAD', Icons.speed_rounded, Colors.white),
        _buildSpeedSetting(
          'Descarga Máxima',
          'Límite actual: Ilimitado',
          0,
          (_) {},
        ),
        _buildSpeedSetting(
          'Subida Máxima',
          'Límite actual: Ilimitado',
          0,
          (_) {},
        ),
        const SizedBox(height: 30),
        _buildSettingsHeader('CONFIGURACIÓN DE RED', Icons.lan_rounded, Colors.white),
        _buildNetworkInfoCard(colorScheme),
        const SizedBox(height: 30),
        _buildSettingsHeader('ALMACENAMIENTO', Icons.folder_rounded, Colors.white),
        _buildPathCard(colorScheme),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSettingsHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5),
      child: Row(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.8), size: 18),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedSetting(String title, String subtitle, int value, Function(int) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value == 0 ? '∞' : '$value',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: value.toDouble().clamp(0, 10240),
              min: 0,
              max: 10240,
              divisions: 100,
              onChanged: (val) => onChanged(val.toInt()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkInfoCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Puerto escucha', _networkInfo?['port'] ?? '...', Icons.door_front_door_rounded, Colors.white),
          const Divider(height: 30, color: Colors.white10),
          _buildInfoRow('IP Local', _networkInfo?['localIP'] ?? '...', Icons.computer_rounded, Colors.white),
          const Divider(height: 30, color: Colors.white10),
          _buildInfoRow('IP Pública', _networkInfo?['publicIP'] ?? '...', Icons.public_rounded, Colors.white),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.7), size: 18),
        const SizedBox(width: 15),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPathCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Directorio de descarga', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _pathController,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.amberAccent),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.3),
              hintText: 'Ruta de descarga...',
              hintStyle: const TextStyle(color: Colors.white24),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.folder_open_rounded, color: Colors.amberAccent, size: 20),
                onPressed: _pickDirectory,
                tooltip: 'Seleccionar carpeta',
              ),
            ),
            onSubmitted: (value) async {
              // Path setting removed from AppSettings
            },
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'Presiona Enter para guardar los cambios manuales',
              style: TextStyle(fontSize: 10, color: Colors.white30, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDirectory() async {
    try {
      String? result = await FilePicker.getDirectoryPath(
        dialogTitle: 'Seleccionar carpeta de descargas',
      );

      if (result != null && mounted) {
        // Path setting removed from AppSettings
        await _refresh();
      }
    } catch (e) {
      debugPrint('[TorrentDownloadsPage] Error picking directory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar carpeta: $e')),
        );
      }
    }
  }

  Future<void> _updateSetting(AppSettings newSettings) async {
    setState(() => _settings = newSettings);
    await _storage.saveAppSettings(newSettings);
    await _api.torrent.syncSettingsWithBackend(newSettings);
  }
}

class _TorrentItem extends StatelessWidget {
  const _TorrentItem({
    required this.torrent,
    required this.isSeeding,
    required this.formatSize,
    required this.formatSpeed,
  });

  final TorrentBackendInfo torrent;
  final bool isSeeding;
  final String Function(int) formatSize;
  final String Function(double) formatSpeed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = (torrent.progress / 100).clamp(0.0, 1.0);
    final statusColor = isSeeding ? Colors.deepPurpleAccent : Colors.tealAccent.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isSeeding ? Icons.upload_rounded : Icons.download_rounded, size: 16, color: statusColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        torrent.name.isEmpty ? torrent.infoHash : torrent.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                    Text(
                      '${torrent.progress.toStringAsFixed(1)}%',
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: statusColor,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${formatSize(torrent.downloaded)} / ${formatSize(torrent.size)}',
                      style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Icon(Icons.speed_rounded, size: 12, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          isSeeding ? formatSpeed(torrent.uploadSpeed) : formatSpeed(torrent.downloadSpeed),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalAnimeCard extends StatelessWidget {
  const _LocalAnimeCard({
    required this.anime,
    required this.colorScheme,
    required this.currentPath,
    required this.onRefresh,
    required this.onDelete,
    required this.formatSize,
  });

  final LocalAnimeDownload anime;
  final ColorScheme colorScheme;
  final String? currentPath;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;
  final String Function(int) formatSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: currentPath == null
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnimeDownloadsDetailPage(
                        animeId: anime.id,
                        animeTitle: anime.title,
                        animeCover: anime.coverImage,
                        metadata: anime.metadata,
                        entities: anime.entities,
                        basePath: currentPath!,
                        onRefreshRequested: onRefresh,
                      ),
                    ),
                  );
                },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 70,
                  child: anime.coverImage != null
                      ? AppCachedImage(
                          anime.coverImage!,
                          fit: BoxFit.cover,
                        )
                      : _buildPlaceholder(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          anime.title,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: -0.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${anime.count} arch. • ${formatSize(anime.totalSize)}',
                              style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error.withValues(alpha: 0.5), size: 18),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie_rounded, color: colorScheme.outline.withValues(alpha: 0.5), size: 20),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradientColors,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
