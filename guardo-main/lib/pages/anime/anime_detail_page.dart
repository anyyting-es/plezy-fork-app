import 'dart:convert';
import 'package:anityng/models/app_models.dart';
import 'package:anityng/pages/watch/watch_page.dart';
import 'package:anityng/services/api_service.dart';
import 'package:anityng/services/storage_service.dart';
import 'package:anityng/extensions/extension_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'widgets/episode_layout.dart';
import 'widgets/torrent_widgets.dart';
import 'widgets/anime_header.dart';
import 'widgets/anime_details_widgets.dart';
import 'logic/anime_detail_controller.dart';
import 'logic/anime_formatter.dart';
import '../manga/manga_detail_page.dart';
import '../manga/widgets/manga_details_widgets.dart';
import '../../widgets/media_widgets.dart';

class AnimeDetailPage extends StatefulWidget {
  const AnimeDetailPage({
    super.key,
    required this.animeId,
    this.resume,
    this.forceAniList = false,
    this.posterHeroTag,
    this.titleHeroTag,
  });

  final int animeId;
  final WatchEntry? resume;
  final bool forceAniList;
  final String? posterHeroTag;
  final String? titleHeroTag;

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  late final AnimeDetailController _controller;
  final ScrollController _scrollController = ScrollController();
  final _scrollOffsetNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimeDetailController(
      animeId: widget.animeId,
      resume: widget.resume,
    )..init();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollOffsetNotifier.value = _scrollController.offset;
  }

  void _openRelatedMedia(int id, String type, {String? posterHeroTag, String? titleHeroTag}) {
    if (type == 'ANIME') {
      Navigator.of(
        context,
      ).push(
        MaterialPageRoute(
          builder: (_) => AnimeDetailPage(
            animeId: id,
            posterHeroTag: posterHeroTag,
            titleHeroTag: titleHeroTag,
          ),
        ),
      );
    } else {
      Navigator.of(
        context,
      ).push(
        MaterialPageRoute(
          builder: (_) => MangaDetailPage(
            mangaId: id,
            posterHeroTag: posterHeroTag,
            titleHeroTag: titleHeroTag,
          ),
        ),
      );
    }
  }

  Future<void> _startWatch({required int episodeNumber}) async {
    final anime = _controller.anime;
    if (anime == null) return;

    final sources = <_SourceOption>[];
    final exts = ExtensionService().extensions;
    for (var i = 0; i < exts.length; i++) {
      final ext = exts[i];
      if (ext.manifest.type == 'anime') {
        sources.add(
          _SourceOption(
            id: 'ext_${ext.manifest.id}',
            label: ext.manifest.name,
            icon: Icons.cloud_queue,
            subtitle: 'Online Streaming',
          ),
        );
      } else if (ext.manifest.type == 'torrent') {
        sources.add(
          _SourceOption(
            id: 'torrent_ext_${ext.manifest.id}',
            label: ext.manifest.name,
            icon: Icons.download_rounded,
            subtitle: 'Torrent',
          ),
        );
      }
    }

    // Las opciones hardcodeadas de torrent han sido removidas
    // para cumplir con el sistema de repositorio vacío.

    final String? selectedProvider = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elegir Fuente'),
        content: SizedBox(
          width: double.maxFinite,
          child: sources.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No hay extensiones instaladas.\nVe a Ajustes > Extensiones para importar una.', textAlign: TextAlign.center),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: sources.length,
                  itemBuilder: (context, index) {
                    final src = sources[index];
                    final isTorrent = src.id.startsWith('torrent');
                    return ListTile(
                      leading: Icon(
                        src.icon,
                        color: isTorrent ? Colors.blue : Colors.green,
                      ),
                      title: Text(src.label),
                      subtitle: Text(src.subtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, src.id),
                    );
                  },
                ),
        ),
      ),
    );

    if (selectedProvider == null) return;
    StreamLink? finalStream;

    if (selectedProvider.startsWith('torrent')) {
      _controller.torrentProvider.setAnimeMetadata(
        id: _controller.animeId,
        title: anime['title']?['romaji'] ?? '',
        titleEnglish: anime['title']?['english'],
        coverImage: anime['coverImage']?['large'],
      );

      final streamsFuture = _controller.torrentProvider.getStreams(
        jsonEncode({
          'type': 'torrent',
          'anilistId': _controller.animeId,
          'episode': episodeNumber,
        }),
      );

      final selectedStream = await showModalBottomSheet<StreamLink>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => TorrentSelectorSheet(
          streamsFuture: streamsFuture,
          anime: anime,
          episodes: _controller.episodes,
          currentEpisodeNumber: episodeNumber,
          currentProviderId: selectedProvider,
          useRealDebrid: false,
          onEpisodeChanged: (_) {},
          onProviderChanged: (_) {},
          onRealDebridChanged: (_) {},
        ),
      );

      if (selectedStream == null) return;
      finalStream = selectedStream;

      final magnet = selectedStream.headers?['magnet'];
      if (magnet != null) {
        final info = await _controller.torrentProvider.addTorrent(magnet);
        if (info != null && mounted) {
          _controller.addActiveDownload(episodeNumber, info);
          final epInfo = _controller.episodes.firstWhere(
            (e) => e.number == episodeNumber,
          );
          _controller.torrentProvider.setEpisodeMetadata(
            episodeId: 'download-${_controller.animeId}-$episodeNumber',
            number: episodeNumber.toDouble(),
            title: epInfo.title,
            coverImage: epInfo.image ?? anime['coverImage']?['large'],
            synopsis: epInfo.description,
            infoHash: info.infoHash,
            torrentName: info.name,
          );
        }
      }
    }

    if (!mounted) return;

    // Si es una extension de streaming, los episodios ya están cargados desde AniList
    // Las extensiones Dart usan getDetails() en el WatchController directamente

    var episodes = _controller.episodes;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WatchPage(
          providerId: selectedProvider,
          anime: anime,
          episodes: episodes,
          tvdbEpisodes: const {},
          initialEpisodeNumber: episodeNumber,
          initialStream: finalStream,
        ),
      ),
    );
    _controller.refreshWatchEntry();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final surfaceColor = Theme.of(context).scaffoldBackgroundColor;
        final anime = _controller.anime;

        if (!_controller.loading && anime == null) {
          return Scaffold(
            backgroundColor: surfaceColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.circleX,
                    size: 64,
                    color: colorScheme.error.withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No se pudo cargar la información',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ID: ${widget.animeId}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => _controller.load(),
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    label: const Text('REINTENTAR'),
                  ),
                ],
              ),
            ),
          );
        }

        final title = anime != null
            ? ((anime['title']?['english'] as String?) ??
                  (anime['title']?['romaji'] as String?) ??
                  'Sin título')
            : 'Cargando...';
        final cover = anime != null
            ? (anime['coverImage']?['extraLarge'] as String? ?? '')
            : '';
        final description = anime?['description']?.toString()
                .replaceAll(RegExp(r'<br\s*/?>'), '\n')
                .replaceAll(RegExp(r'<[^>]*>'), '')
                .replaceAll(RegExp(r'\n\s*\n+'), '\n')
                .trim() ??
            '';
        final genres = anime != null
            ? (anime['genres'] as List? ?? []).cast<String>()
            : <String>[];
        final banner = anime?['bannerImage'] as String? ?? cover;

        final scoreRaw = (anime?['averageScore'] as num?)?.toDouble();
        final averageScore = scoreRaw != null
            ? (scoreRaw / 10).toStringAsFixed(1)
            : null;

        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth > 800;

        final staff = ((anime?['staff']?['edges'] as List?) ?? [])
            .whereType<Map>()
            .toList();
        final characters = ((anime?['characters']?['edges'] as List?) ?? [])
            .whereType<Map>()
            .toList();
        final relationEdges = (anime?['relations']?['edges'] as List? ?? []);
        final recommendations =
            (anime?['recommendations']?['nodes'] as List? ?? [])
                .map((node) => node['mediaRecommendation'])
                .whereType<Map>()
                .toList();

        return Scaffold(
          backgroundColor: surfaceColor,
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 600,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffsetNotifier,
                  builder: (context, scrollOffset, child) {
                    final maxScrollDistance = 500.0;
                    final scrollProgress = (scrollOffset / maxScrollDistance).clamp(0.0, 1.0);
                    final breathingScale =
                        1.0 +
                        (scrollProgress * 0.1) +
                        (scrollOffset < 0 ? (-scrollOffset / 500) : 0);
                    final backgroundOpacity = (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0);

                    return Opacity(
                      opacity: backgroundOpacity,
                      child: Transform.scale(
                        scale: breathingScale,
                        child: child,
                      ),
                    );
                  },
                  child: AppCachedImage(
                    banner,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: AnimeHeader(
                      anime: anime ?? {},
                      title: title,
                      cover: cover,
                      watchEntry: _controller.watchEntry,
                      isFavorite: _controller.isFavorite,
                      onFavoriteTap: () => _controller.toggleFavorite(),
                      onPlayTap: _controller.episodes.isNotEmpty
                          ? () => _startWatch(
                              episodeNumber: _controller.episodes.first.number,
                            )
                          : null,
                      posterHeroTag: widget.posterHeroTag,
                      titleHeroTag: widget.titleHeroTag,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      color: surfaceColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: AnimeSynopsis(description: description),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      color: surfaceColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EPISODIOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_controller.loadingEpisodes)
                            const Center(child: CircularProgressIndicator())
                          else
                            EpisodeLayout(
                              episodes: _controller.episodes,
                              tvdbEpisodes: const {},
                              watchEntry: _controller.watchEntry,
                              fallbackImageUrl: cover,
                              onEpisodeTap: (epNum) =>
                                  _startWatch(episodeNumber: epNum),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Characters
                  SliverToBoxAdapter(
                    child: Container(
                      color: surfaceColor,
                      child: CharacterSectionWidget(characters: characters),
                    ),
                  ),

                  // Staff
                  SliverToBoxAdapter(
                    child: Container(
                      color: surfaceColor,
                      child: StaffSectionWidget(staff: staff),
                    ),
                  ),

                  // Relations
                  SliverToBoxAdapter(
                    child: Container(
                      color: surfaceColor,
                      child: RelationSectionWidget(
                        relations: relationEdges,
                        onMediaTap: _openRelatedMedia,
                      ),
                    ),
                  ),

                  // Recommendations
                  if (recommendations.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Container(
                        color: surfaceColor,
                        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                        child: const Text(
                          'RECOMENDACIONES',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        color: surfaceColor,
                        height: 310,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: recommendations.length,
                          itemBuilder: (context, index) {
                            final rec = recommendations[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: MediaCard(
                                item: Map<String, dynamic>.from(rec),
                                onTap: () {
                                  final id = (rec['id'] as num).toInt();
                                  final type = rec['type']?.toString() ?? 'ANIME';
                                  _openRelatedMedia(
                                    id,
                                    type,
                                    posterHeroTag: 'recommendation-$id',
                                    titleHeroTag: 'recommendation-title-$id',
                                  );
                                },
                                heroTagPrefix: 'recommendation',
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: Container(color: surfaceColor, height: 60),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: MediaQuery.of(context).padding.top + 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                left: 20,
                child: SafeArea(
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      LucideIcons.arrowLeft,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SourceOption {
  final String id, label, subtitle;
  final IconData icon;
  _SourceOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.subtitle,
  });
}
