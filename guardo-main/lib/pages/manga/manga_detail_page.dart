import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:convert';
import '../../../models/app_models.dart';
import '../anime/anime_detail_page.dart';
import 'reader/manga_reader_page.dart';
import './logic/manga_detail_controller.dart';
import './widgets/manga_header.dart';
import './widgets/chapter_section.dart';
import './widgets/manga_widgets.dart';
import './widgets/manga_details_widgets.dart';

class MangaDetailPage extends StatefulWidget {
  const MangaDetailPage({
    super.key,
    required this.mangaId,
    this.resume,
    this.posterHeroTag,
    this.titleHeroTag,
  });

  final int mangaId;
  final ReadEntry? resume;
  final String? posterHeroTag;
  final String? titleHeroTag;

  @override
  State<MangaDetailPage> createState() => _MangaDetailPageState();
}

class _MangaDetailPageState extends State<MangaDetailPage> {
  late MangaDetailController _controller;
  late ScrollController _scrollController;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = MangaDetailController(
      mangaId: widget.mangaId,
      resume: widget.resume,
    )..init();

    _scrollController = ScrollController()
      ..addListener(() {
        if (_scrollController.hasClients) {
          setState(() {
            _scrollOffset = _scrollController.offset;
          });
        }
      });

    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _openReader({int? chapterNumber}) async {
    if (_controller.manga == null ||
        _controller.mwDetails == null ||
        _controller.mwDetails!.chapters.isEmpty)
      return;

    final chapters = _controller.mwDetails!.chapters;
    var index = 0;
    if (chapterNumber != null) {
      final idx = chapters.indexWhere(
        (item) => (item['number'] as num).floor() == chapterNumber,
      );
      if (idx >= 0) index = idx;
    } else if (widget.resume != null) {
      final idx = chapters.indexWhere(
        (item) =>
            (item['number'] as num).floor() ==
            widget.resume!.lastChapterNumber.floor() + 1,
      );
      if (idx >= 0) index = idx;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MangaReaderPage(
          anilistManga: _controller.manga!,
          mwDetails: _controller.mwDetails!,
          chapters: List<Map<String, dynamic>>.from(chapters),
          currentIndex: index,
        ),
      ),
    );

    if (result == true) {
      _controller.refreshReadEntry();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final manga = _controller.manga!;
    final description = (manga['description']?.toString() ?? '')
            .replaceAll(RegExp(r'<br\s*/?>'), '\n')
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll(RegExp(r'\n\s*\n+'), '\n')
            .trim();

    final staff = ((manga['staff']?['edges'] as List?) ?? [])
        .whereType<Map>()
        .toList();
    final characters = ((manga['characters']?['edges'] as List?) ?? [])
        .whereType<Map>()
        .toList();
    final relationEdges = (manga['relations']?['edges'] as List? ?? []);
    final recommendations = (manga['recommendations']?['nodes'] as List? ?? [])
        .map((node) => node['mediaRecommendation'])
        .whereType<Map>()
        .toList();

    final banner =
        manga['bannerImage'] as String? ??
        manga['coverImage']?['extraLarge'] as String? ??
        '';
    final maxScrollDistance = 500.0;
    final scrollProgress = (_scrollOffset / maxScrollDistance).clamp(0.0, 1.0);
    final breathingScale =
        1.0 +
        (scrollProgress * 0.1) +
        (_scrollOffset < 0 ? (-_scrollOffset / 500) : 0);
    final backgroundOpacity = (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // FIXED BACKGROUND WITH BREATHING EFFECT
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 600,
            child: Opacity(
              opacity: backgroundOpacity,
              child: Transform.scale(
                scale: breathingScale,
                child: Image.network(
                  banner,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),

          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: MangaHeader(
                  controller: _controller,
                  scrollOffset: _scrollOffset,
                  onOpenReader: _openReader,
                  posterHeroTag: widget.posterHeroTag,
                  titleHeroTag: widget.titleHeroTag,
                ),
              ),

              // Synopsis & Description
              SliverToBoxAdapter(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: MangaSynopsis(
                    description: description.isEmpty ? 'Sin descripción disponible.' : description,
                    textAlign: TextAlign.start,
                  ),
                ),
              ),

              // Chapter Section
              SliverToBoxAdapter(
                child: ChapterSection(
                  controller: _controller,
                  onChapterTap: (num) => _openReader(chapterNumber: num),
                ),
              ),

              // Characters
              SliverToBoxAdapter(
                child: CharacterSectionWidget(characters: characters),
              ),

              // Staff
              SliverToBoxAdapter(child: StaffSectionWidget(staff: staff)),

              // Relations
              SliverToBoxAdapter(
                child: RelationSectionWidget(
                  relations: relationEdges,
                  onMediaTap: _openRelatedMedia,
                ),
              ),

              // Recommendations
              if (recommendations.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 48, 16, 16),
                    child: Text(
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
                  child: SizedBox(
                    height: 230,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: recommendations.length,
                      itemBuilder: (context, index) {
                        final rec = recommendations[index];
                        final title =
                            rec['title']?['english'] ??
                            rec['title']?['romaji'] ??
                            'Sin título';
                        final cover = rec['coverImage']?['large'] ?? '';
                        return GestureDetector(
                          onTap: () =>
                              _openRelatedMedia(
                                rec['id'],
                                rec['type'],
                                posterHeroTag: 'recommendation-${rec['id']}',
                                titleHeroTag: 'recommendation-title-${rec['id']}',
                              ),
                          child: Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Hero(
                                    tag: 'recommendation-${rec['id']}',
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: DecorationImage(
                                          image: NetworkImage(cover),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Hero(
                                  tag: 'recommendation-title-${rec['id']}',
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  rec['format']?.toString().replaceAll(
                                        '_',
                                        ' ',
                                      ) ??
                                      '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),

          // Back Button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
