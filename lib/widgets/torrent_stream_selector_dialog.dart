import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:http/http.dart' as http;
import '../media/media_item.dart';
import '../media/media_kind.dart';
import '../services/torrent_playback_service.dart';
import '../anime/services/anizip_service.dart';
import '../services/plugin_extensions_service.dart';
import '../services/settings_service.dart';
import '../services/torrent_engine_service.dart';
import '../utils/app_logger.dart';
import '../utils/platform_detector.dart';
import '../focus/input_mode_tracker.dart';

class TorrentStreamOption {
  final String title;
  final String magnet;
  final String infoHash;
  final String source;
  final String quality;
  final String size;
  final int seeders;
  final int leechers;

  TorrentStreamOption({
    required this.title,
    required this.magnet,
    required this.infoHash,
    required this.source,
    required this.quality,
    required this.size,
    required this.seeders,
    required this.leechers,
  });
}

class ExtensionSourceSelectorDialog extends StatefulWidget {
  final MediaItem metadata;
  final int? seasonNumber;
  final int? episodeNumber;
  final String imdbId;
  final BuildContext callerContext;

  const ExtensionSourceSelectorDialog({
    super.key,
    required this.metadata,
    this.seasonNumber,
    this.episodeNumber,
    required this.imdbId,
    required this.callerContext,
  });

  static Future<String?> show({
    required BuildContext context,
    required MediaItem metadata,
    int? seasonNumber,
    int? episodeNumber,
    required String imdbId,
  }) {
    return showDialog<String?>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: false,
      builder: (dialogContext) => ExtensionSourceSelectorDialog(
        metadata: metadata,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        imdbId: imdbId,
        callerContext: context,
      ),
    );
  }

  @override
  State<ExtensionSourceSelectorDialog> createState() => _ExtensionSourceSelectorDialogState();
}

class _ExtensionSourceSelectorDialogState extends State<ExtensionSourceSelectorDialog> {
  bool _loadingExtensions = true;
  List<ExtensionPlugin> _onlineExtensions = [];
  List<ExtensionPlugin> _torrentExtensions = [];

  // State for fetching/resolving specific extension
  bool _isResolving = false;
  String _resolvingStatus = '';
  String? _errorMessage;

  // Torrent options view state
  bool _showTorrentOptions = false;
  List<TorrentStreamOption> _torrentOptions = [];
  String _activeTorrentProvider = '';

  // Playback prep state
  bool _preparingPlayback = false;
  String _preparingStatus = '';

  // Focus nodes list for the current active list items
  List<FocusNode> _listFocusNodes = [];

  @override
  void initState() {
    super.initState();
    _loadExtensions();
  }

  @override
  void dispose() {
    _clearFocusNodes();
    super.dispose();
  }

  List<String> _parseTorrentTags(String title) {
    final tags = <String>[];
    
    // 1. Release Group (bracketed text at start, e.g. [ToonsHub])
    final groupMatch = RegExp(r'^\[([^\]]+)\]').firstMatch(title);
    if (groupMatch != null) {
      tags.add(groupMatch.group(1)!.trim());
    }

    // 2. Resolution (1080p, 720p, etc.)
    final resMatch = RegExp(r'\b(1080p|720p|480p|540p|2160p|4k)\b', caseSensitive: false).firstMatch(title);
    if (resMatch != null) {
      tags.add(resMatch.group(1)!.toLowerCase());
    } else {
      // Look for bracketed resolutions like [1080p] or [720p]
      final resMatchBracket = RegExp(r'\[(1080p|720p|480p|540p|2160p)\]', caseSensitive: false).firstMatch(title);
      if (resMatchBracket != null) {
        tags.add(resMatchBracket.group(1)!.toLowerCase());
      }
    }

    // 3. Audio/Dubbing (Dual-Audio, Multi-Audio, Dub)
    final audioMatch = RegExp(r'\b(dual[- ]audio|multi[- ]audio|dubbed|dub)\b', caseSensitive: false).firstMatch(title);
    if (audioMatch != null) {
      final raw = audioMatch.group(1)!.toLowerCase();
      if (raw.contains('dual')) {
        tags.add('DUAL');
      } else if (raw.contains('multi')) {
        tags.add('MULTI-AUDIO');
      } else {
        tags.add('DUB');
      }
    }

    // 4. Subtitles (Multi-Subs, Eng-Subs, Subbed)
    final subMatch = RegExp(r'\b(multi[- ]subs?|eng[- ]subs?|subbed|sub)\b', caseSensitive: false).firstMatch(title);
    if (subMatch != null) {
      final raw = subMatch.group(1)!.toLowerCase();
      if (raw.contains('multi')) {
        tags.add('MULTI-SUB');
      } else if (raw.contains('eng')) {
        tags.add('ENG-SUB');
      } else {
        tags.add('SUB');
      }
    }

    // 5. Codec (x265, x264, hevc, h.265, h.264)
    final codecMatch = RegExp(r'\b(x265|x264|hevc|h\.265|h\.264)\b', caseSensitive: false).firstMatch(title);
    if (codecMatch != null) {
      tags.add(codecMatch.group(1)!.toUpperCase());
    }

    return tags;
  }

  void _clearFocusNodes() {
    for (final node in _listFocusNodes) {
      node.dispose();
    }
    _listFocusNodes = [];
  }

  void _updateFocusNodes(int count) {
    _clearFocusNodes();
    _listFocusNodes = List.generate(count, (index) => FocusNode(debugLabel: 'SelectorItemFocus_$index'));
    _requestInitialFocus();
  }

  Future<void> _loadExtensions() async {
    setState(() {
      _loadingExtensions = true;
      _errorMessage = null;
      _showTorrentOptions = false;
    });

    try {
      final settings = SettingsService.instance;
      final disabledList = settings.read(SettingsService.disabledExtensions);

      // List all extensions loaded in backend
      final list = await PluginExtensionsService.listExtensions();
      
      // Filter out disabled extensions
      final enabledExtensions = list.where((ext) => !disabledList.contains(ext.id)).toList();

      // Group by category (online vs torrent)
      _onlineExtensions = enabledExtensions.where((ext) {
        return !(ext.id.contains('torrent') || ext.id.contains('tosho') || ext.id.contains('bt'));
      }).toList();

      _torrentExtensions = enabledExtensions.where((ext) {
        return ext.id.contains('torrent') || ext.id.contains('tosho') || ext.id.contains('bt');
      }).toList();

      if (mounted) {
        setState(() {
          _loadingExtensions = false;
        });
        _updateFocusNodes(_onlineExtensions.length + _torrentExtensions.length);
      }
    } catch (e) {
      appLogger.e('[SourceSelector] Failed to load extensions', error: e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar extensiones.';
          _loadingExtensions = false;
        });
      }
    }
  }

  void _requestInitialFocus() {
    final useKeyboardFocus = PlatformDetector.isTV() || InputModeTracker.isKeyboardMode(context);
    if (!useKeyboardFocus) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_listFocusNodes.isNotEmpty && _listFocusNodes[0].context != null) {
        _listFocusNodes[0].requestFocus();
      }
    });
  }

  // Handle clicking an extension card
  Future<void> _selectExtension(ExtensionPlugin ext, bool isTorrent) async {
    if (isTorrent) {
      _resolveTorrentOptions(ext.id);
    } else {
      _resolveOnlineStream(ext.id);
    }
  }

  // Resolve direct HLS stream from an online provider
  Future<void> _resolveOnlineStream(String providerId) async {
    setState(() {
      _isResolving = true;
      _resolvingStatus = 'Obteniendo enlace de reproducción directa...';
      _errorMessage = null;
    });

    try {
      final title = widget.metadata.grandparentTitle ?? widget.metadata.title ?? '';
      final epNum = widget.episodeNumber ?? 1;

      // Call online resolver via PluginExtensionsService
      final streamUrl = await PluginExtensionsService.getOnlineStreamUrl(
        title: title,
        episodeNumber: epNum,
      );

      if (streamUrl != null && streamUrl.isNotEmpty) {
        if (mounted) {
          Navigator.pop(context, streamUrl);
        }
      } else {
        setState(() {
          _isResolving = false;
          _errorMessage = 'No se encontró ningún enlace de streaming disponible para este episodio.';
        });
        _updateFocusNodes(0);
      }
    } catch (e) {
      setState(() {
        _isResolving = false;
        _errorMessage = 'Error al resolver el stream: $e';
      });
      _updateFocusNodes(0);
    }
  }

  // Resolve torrent list from torrent provider
  Future<void> _resolveTorrentOptions(String providerId) async {
    setState(() {
      _isResolving = true;
      _resolvingStatus = 'Buscando torrents disponibles...';
      _errorMessage = null;
    });

    try {
      final isMovie = widget.metadata.kind == MediaKind.movie;
      final title = widget.metadata.grandparentTitle ?? widget.metadata.title ?? '';
      final epNum = widget.episodeNumber ?? 1;
      List<dynamic>? results;

      int? anilistId;
      if (widget.metadata.grandparentId != null) {
        anilistId = int.tryParse(widget.metadata.grandparentId!);
      }
      if (anilistId == null && widget.metadata.id.startsWith('anime_ep_')) {
        final parts = widget.metadata.id.split('_');
        if (parts.length > 2) {
          anilistId = int.tryParse(parts[2]);
        }
      }

      int? anidbAid;
      int? anidbEid;
      if (anilistId != null) {
        anidbAid = AniZipService.getAnidbAid(anilistId);
        final eps = await AniZipService.getEpisodes(anilistId);
        final match = eps.firstWhere(
          (ep) => ep.episodeNumber == widget.episodeNumber || ep.absoluteEpisodeNumber == widget.episodeNumber,
          orElse: () => null as dynamic,
        );
        if (match != null) {
          anidbEid = match.anidbEid;
        }
        if (anidbAid == null) {
          anidbAid = AniZipService.getAnidbAid(anilistId);
        }
      }

      // 1. If anidbEid is available, call 'single'
      if (anidbEid != null && anidbEid > 0) {
        try {
          final args = [
            {"anidbEid": anidbEid},
            {"useTorrent": false}
          ];
          results = await PluginExtensionsService.callMethod(
            providerId: providerId,
            method: 'single',
            args: args,
          );
        } catch (_) {}
      }

      // 2. If results are empty and anidbAid is available, call 'movie' (if movie) or 'batch' (if series)
      if ((results == null || results.isEmpty) && anidbAid != null && anidbAid > 0) {
        try {
          if (isMovie) {
            final args = [
              {"anidbAid": anidbAid},
              {"useTorrent": false}
            ];
            results = await PluginExtensionsService.callMethod(
              providerId: providerId,
              method: 'movie',
              args: args,
            );
          } else {
            final args = [
              {"anidbAid": anidbAid, "episode": epNum},
              {"useTorrent": false}
            ];
            results = await PluginExtensionsService.callMethod(
              providerId: providerId,
              method: 'batch',
              args: args,
            );
          }
        } catch (_) {}
      }

      // 3. Fallback: text search based on titles
      if (results == null || results.isEmpty) {
        final searchTitles = [widget.metadata.title, title].whereType<String>().where((t) => t.trim().isNotEmpty).toList();
        for (final t in searchTitles) {
          try {
            final sanitized = _sanitizeTitle(t);
            final q = isMovie ? sanitized : '$sanitized ${epNum.toString().padLeft(2, '0')}';
            
            final engineUrl = TorrentEngineService.instance.baseUrl;
            final backendBase = engineUrl.isNotEmpty ? engineUrl : 'http://127.0.0.1:9876';
            final searchUrl = Uri.parse(
              '$backendBase/extensions/search?provider=$providerId&query=${Uri.encodeComponent(q)}',
            );
            
            final response = await http.get(searchUrl).timeout(const Duration(seconds: 15));
            if (response.statusCode == 200) {
              final list = jsonDecode(response.body) as List;
              results = list.where((entry) {
                if (isMovie) return true;
                if (entry is Map<String, dynamic>) {
                  final tTitle = entry['title']?.toString() ?? '';
                  final extracted = _extractEpisodeNumber(tTitle);
                  return extracted == epNum;
                }
                return false;
              }).toList();
              if (results!.isNotEmpty) break;
            }
          } catch (_) {}
        }
      }

      final mappedOptions = <TorrentStreamOption>[];
      if (results != null) {
        for (final item in results) {
          if (item is Map<String, dynamic>) {
            mappedOptions.add(TorrentStreamOption(
              title: item['title']?.toString() ?? '',
              magnet: item['link']?.toString() ?? '',
              infoHash: item['hash']?.toString() ?? '',
              source: providerId.toUpperCase(),
              quality: item['accuracy']?.toString() ?? 'Auto',
              size: _formatSizeBytes((item['size'] as num?)?.toInt() ?? 0),
              seeders: (item['seeders'] as num?)?.toInt() ?? 0,
              leechers: (item['leechers'] as num?)?.toInt() ?? 0,
            ));
          }
        }
      }

      // Sort by seeders descending
      mappedOptions.sort((a, b) => b.seeders.compareTo(a.seeders));

      if (mounted) {
        setState(() {
          _torrentOptions = mappedOptions;
          _activeTorrentProvider = providerId;
          _isResolving = false;
          _showTorrentOptions = true;
        });
        _updateFocusNodes(_torrentOptions.length);
      }
    } catch (e) {
      setState(() {
        _isResolving = false;
        _errorMessage = 'Error al buscar torrents: $e';
      });
      _updateFocusNodes(0);
    }
  }

  Future<void> _playTorrentStream(TorrentStreamOption option) async {
    setState(() {
      _preparingPlayback = true;
      _preparingStatus = 'Iniciando motor de torrents...';
    });

    try {
      final streamUrl = await TorrentPlaybackService.instance.resolveAndStream(
        option.magnet,
        seasonIndex: widget.seasonNumber,
        episodeIndex: widget.episodeNumber,
        onProgressUpdate: (status) {
          if (mounted) {
            setState(() {
              _preparingStatus = status;
            });
          }
        },
      );

      if (streamUrl == null) {
        throw Exception('No se pudo obtener la URL de streaming local.');
      }

      if (mounted) {
        Navigator.pop(context, streamUrl);
      }
    } catch (e) {
      appLogger.e('[SourceSelector] Playback resolution failed', error: e);
      if (mounted) {
        setState(() {
          _preparingPlayback = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al reproducir torrent: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useKeyboardFocus = PlatformDetector.isTV() || InputModeTracker.isKeyboardMode(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
      child: Container(
        width: 620,
        height: 480,
        padding: const EdgeInsets.all(24),
        child: _preparingPlayback
            ? _buildPreparingView(theme, useKeyboardFocus)
            : _isResolving
                ? _buildResolvingView(theme, useKeyboardFocus)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _loadingExtensions
                            ? const Center(child: CircularProgressIndicator())
                            : _errorMessage != null
                                ? _buildErrorView(theme, useKeyboardFocus)
                                : _showTorrentOptions
                                    ? _buildTorrentOptionsList(theme, useKeyboardFocus)
                                    : _buildSourceSelectionList(theme, useKeyboardFocus),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final sNum = widget.seasonNumber ?? widget.metadata.parentIndex ?? 1;
    final epNum = widget.episodeNumber ?? widget.metadata.index ?? 1;
    final title = widget.metadata.grandparentTitle != null
        ? '${widget.metadata.grandparentTitle} • T$sNum E$epNum'
        : (widget.metadata.title ?? 'Contenido');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _showTorrentOptions ? 'Seleccionar Torrent' : 'Seleccionar Origen',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (_showTorrentOptions)
          IconButton(
            icon: const Icon(Symbols.arrow_back_rounded),
            onPressed: () {
              setState(() {
                _showTorrentOptions = false;
                _torrentOptions.clear();
              });
              _updateFocusNodes(_onlineExtensions.length + _torrentExtensions.length);
            },
          )
        else if (!_loadingExtensions)
          IconButton(
            icon: const Icon(Symbols.refresh_rounded),
            onPressed: _loadExtensions,
          ),
      ],
    );
  }

  Widget _buildSourceSelectionList(ThemeData theme, bool useKeyboardFocus) {
    if (_onlineExtensions.isEmpty && _torrentExtensions.isEmpty) {
      return Center(
        child: Text(
          'No hay extensiones habilitadas. Configúralas en Ajustes > Extensiones.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
          textAlign: TextAlign.center,
        ),
      );
    }

    final children = <Widget>[];
    int focusIndex = 0;

    if (_onlineExtensions.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            'Streaming Directo (Online)',
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
      );

      for (final ext in _onlineExtensions) {
        final fIndex = focusIndex++;
        final node = _listFocusNodes[fIndex];
        children.add(
          _buildSourceCard(ext, false, node, fIndex, theme, useKeyboardFocus),
        );
      }
    }

    if (_torrentExtensions.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 12),
          child: Text(
            'Streaming Torrent (P2P)',
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
          ),
        ),
      );

      for (final ext in _torrentExtensions) {
        final fIndex = focusIndex++;
        final node = _listFocusNodes[fIndex];
        children.add(
          _buildSourceCard(ext, true, node, fIndex, theme, useKeyboardFocus),
        );
      }
    }

    return ListView(
      children: children,
    );
  }

  Widget _buildSourceCard(
    ExtensionPlugin ext,
    bool isTorrent,
    FocusNode focusNode,
    int index,
    ThemeData theme,
    bool useKeyboardFocus,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectExtension(ext, isTorrent),
        focusNode: focusNode,
        autofocus: index == 0 && useKeyboardFocus,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                isTorrent ? Symbols.bolt_rounded : Symbols.play_circle_rounded,
                color: isTorrent ? theme.colorScheme.secondary : theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ext.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTorrent ? 'Resolución de torrents desde ${ext.name}' : 'Streaming directo desde ${ext.name}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              const Icon(Symbols.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTorrentOptionsList(ThemeData theme, bool useKeyboardFocus) {
    if (_torrentOptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.sentiment_dissatisfied_rounded, size: 48, color: theme.colorScheme.onSurface.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No se encontraron torrents para este episodio.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _torrentOptions.length,
      itemBuilder: (context, index) {
        final opt = _torrentOptions[index];
        final node = _listFocusNodes[index];
        
        final tags = _parseTorrentTags(opt.title);
        if (tags.isEmpty) {
          tags.add(opt.quality);
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _playTorrentStream(opt),
            focusNode: node,
            autofocus: index == 0 && useKeyboardFocus,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ...tags.map((tag) {
                              Color badgeColor = theme.colorScheme.primary;
                              final lowerTag = tag.toLowerCase();

                              if (lowerTag.contains('1080p') || lowerTag.contains('4k') || lowerTag.contains('2160p')) {
                                badgeColor = Colors.teal;
                              } else if (lowerTag.contains('720p')) {
                                badgeColor = Colors.blue;
                              } else if (lowerTag.contains('dual') || lowerTag.contains('multi')) {
                                badgeColor = Colors.deepOrange;
                              } else if (lowerTag.contains('x265') || lowerTag.contains('hevc')) {
                                badgeColor = Colors.purple;
                              } else {
                                badgeColor = theme.colorScheme.secondary;
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: badgeColor.withOpacity(0.25), width: 1),
                                ),
                                child: Text(
                                  tag,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: badgeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(width: 4),
                            Text(
                              opt.size,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Symbols.arrow_upward_rounded, size: 14, color: Colors.green),
                      const SizedBox(width: 2),
                      Text(
                        '${opt.seeders}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResolvingView(ThemeData theme, bool useKeyboardFocus) {
    return Focus(
      autofocus: useKeyboardFocus,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Buscando enlaces',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _resolvingStatus,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPreparingView(ThemeData theme, bool useKeyboardFocus) {
    return Focus(
      autofocus: useKeyboardFocus,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Preparando Reproducción',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _preparingStatus,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme, bool useKeyboardFocus) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.error_outline_rounded, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadExtensions,
            icon: const Icon(Symbols.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // Helper title parser utilities for text query lookup
  int _extractEpisodeNumber(String title) {
    final patterns = [
      RegExp(r'[Ss]\d{1,2}[\s\-_.]?[Ee](\d{1,4})'),
      RegExp(r'\b\d{1,2}x(\d{1,4})\b'),
      RegExp(r'[Ee][Pp]?[\s\-]?(\d+)'),
      RegExp(r'[\s\[\(-](\d+)[\s\]\)-]'),
      RegExp(r'[\s\-]+(\d+)[\s]+'),
      RegExp(r'[\s\[\(-](\d+)v[\s\[\]-]'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(title);
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '');
        if (num != null && num > 0 && !_isResolutionOrYear(num)) {
          return num;
        }
      }
    }
    return -1;
  }

  bool _isResolutionOrYear(int v) {
    const resolutions = {240, 360, 480, 540, 720, 1080, 1440, 2160, 264, 265};
    return resolutions.contains(v) || (v >= 1900 && v <= 2100) || v > 9999;
  }

  String _sanitizeTitle(String t) {
    return t
        .replaceAll(RegExp(r'[-]+'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatSizeBytes(int bytes) {
    if (bytes == 0) return '0 Bytes';
    const sizes = ['Bytes', 'KiB', 'MiB', 'GiB', 'TiB'];
    double val = bytes.toDouble();
    int unit = 0;
    while (val >= 1024 && unit < sizes.length - 1) {
      val /= 1024;
      unit++;
    }
    return '${val.toStringAsFixed(2)} ${sizes[unit]}';
  }
}

class TorrentStreamSelectorDialog extends StatelessWidget {
  final MediaItem metadata;
  final int? seasonNumber;
  final int? episodeNumber;
  final String imdbId;

  const TorrentStreamSelectorDialog({
    super.key,
    required this.metadata,
    this.seasonNumber,
    this.episodeNumber,
    required this.imdbId,
    required BuildContext callerContext,
  });

  static Future<String?> show({
    required BuildContext context,
    required MediaItem metadata,
    int? seasonNumber,
    int? episodeNumber,
    required String imdbId,
  }) {
    return ExtensionSourceSelectorDialog.show(
      context: context,
      metadata: metadata,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      imdbId: imdbId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExtensionSourceSelectorDialog(
      metadata: metadata,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      imdbId: imdbId,
      callerContext: context,
    );
  }
}
