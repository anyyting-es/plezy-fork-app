import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import 'media_widgets.dart';
import 'tv_widgets.dart';

class HomeFeaturedCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item) onItemTap;

  final void Function(int id, int index)? onPageChanged;
  final void Function(List<Map<String, dynamic>> items)? onItemsLoaded;

  final ScrollController? mainScrollController;

  const HomeFeaturedCarousel({
    super.key,
    required this.items,
    required this.onItemTap,
    this.onPageChanged,
    this.onItemsLoaded,
    this.mainScrollController,
  });

  @override
  State<HomeFeaturedCarousel> createState() => _HomeFeaturedCarouselState();
}

class _HomeFeaturedCarouselState extends State<HomeFeaturedCarousel> {
  late PageController _pageController;
  final ValueNotifier<double> _pageNotifier = ValueNotifier<double>(0.0);
  final List<int> _featuredIds = [147105, 169580, 180745, 189046, 199029, 199221, 21];
  List<Map<String, dynamic>> _featuredItems = [];
  bool _itemsNotified = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _pageController.addListener(_onScroll);
    _featuredItems = _filterFeatured(widget.items);
  }

  @override
  void didUpdateWidget(HomeFeaturedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newItems = _filterFeatured(widget.items);
    if (newItems.length != _featuredItems.length) {
      _featuredItems = newItems;
      _itemsNotified = false;
    }
    if (!_itemsNotified && _featuredItems.isNotEmpty) {
      _itemsNotified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onItemsLoaded?.call(_featuredItems);
      });
    }
  }

  List<Map<String, dynamic>> _filterFeatured(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final id = (item['id'] as num?)?.toInt();
      return id != null && _featuredIds.contains(id);
    }).toList();
  }

  void _onScroll() {
    if (mounted && _pageController.page != null) {
      _pageNotifier.value = _pageController.page!;

      final index = _pageNotifier.value.round();
      if (index >= 0 && index < _featuredItems.length) {
        final id = (_featuredItems[index]['id'] as num?)?.toInt();
        if (id != null) {
          widget.onPageChanged?.call(id, index);
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    _pageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final featuredItems = _featuredItems;

    if (featuredItems.isEmpty) return const SizedBox.shrink();

    // Notify parent about loaded items on first build
    if (!_itemsNotified) {
      _itemsNotified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onItemsLoaded?.call(featuredItems);
      });
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWide = screenWidth > 900;
    final carouselHeight = isWide
        ? (screenHeight * 0.58).clamp(380.0, 520.0)
        : (screenHeight * 0.44).clamp(260.0, 340.0);

    return SizedBox(
      height: carouselHeight,
      width: screenWidth,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: featuredItems.length,
            physics: const ClampingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = featuredItems[index];

              return GestureDetector(
                onTap: () => widget.onItemTap(item),
                child: const Stack(
                  fit: StackFit.expand,
                  children: [],
                ),
              );
            },
          ),

          
          // Fixed Metadata Overlay - left-aligned, responsive constraints
          Positioned(
            left: isWide ? 72 : 16,
            right: isWide ? null : 16,
            bottom: isWide ? 24 : 16,
            child: ValueListenableBuilder<double>(
              valueListenable: _pageNotifier,
              builder: (context, page, _) {
                return Stack(
                  children: List.generate(featuredItems.length, (index) {
                    final double pageOffset = page - index;
                    // Fade out completely by 50% swipe progress to prevent overlay overlaps
                    final double opacity = (1.0 - pageOffset.abs() * 2.0).clamp(0.0, 1.0);

                    if (opacity <= 0.0) return const SizedBox.shrink();

                    final item = featuredItems[index];
                    final id = (item['id'] as num).toInt();
                    final logoAsset = 'assets/carrousel/${id}_l.png';

                    return Opacity(
                      opacity: opacity,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          key: ValueKey(id),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo
                            Image.asset(
                              logoAsset,
                              height: isWide ? 90 : 60,
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomLeft,
                            ),
                            const SizedBox(height: 16),
                            
                            // Badges / Tags / Genres (Wrap dynamic space)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (item['status'] != null)
                                  _buildGlassTag(
                                    item['status'] == 'RELEASING' ? 'EN EMISIÓN' : 'FINALIZADO',
                                    color: item['status'] == 'RELEASING' ? Colors.greenAccent : Colors.white70,
                                  ),
                                if (item['averageScore'] != null)
                                  _buildGlassTag(
                                    '★ ${(item['averageScore'] / 10).toStringAsFixed(1)}',
                                    color: Colors.amberAccent,
                                  ),
                                if (item['format'] != null)
                                  _buildGlassTag(item['format'].toString().replaceAll('_', ' ')),
                                if (item['genres'] != null)
                                  ...(item['genres'] as List).take(3).map((genre) => _buildGlassTag(
                                    genre.toString().toUpperCase(),
                                    color: Colors.white60,
                                  )),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // ACTION BUTTON (VER AHORA)
                            TVFocusWrapper(
                              onTap: () => widget.onItemTap(item),
                              borderRadius: 20,
                              child: Focus(
                                onFocusChange: (focused) {
                                  if (focused && widget.mainScrollController != null) {
                                    widget.mainScrollController!.animateTo(
                                      0,
                                      duration: const Duration(milliseconds: 500),
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        'VER AHORA',
                                        style: GoogleFonts.outfit(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          
          // Page Indicators
          Positioned(
            bottom: 20,
            right: 24,
            child: ValueListenableBuilder<double>(
              valueListenable: _pageNotifier,
              builder: (context, page, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(featuredItems.length, (index) {
                    final double pageOffset = page - index;
                    final double activeWidth = (1.0 - pageOffset.abs()).clamp(0.0, 1.0) * 20 + 8;
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      height: 4,
                      width: activeWidth,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: (1.0 - pageOffset.abs()).clamp(0.2, 1.0)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildGlassTag(String text, {Color color = Colors.white70}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class ContinueWatchingSection extends StatelessWidget {
  final List<WatchEntry> entries;
  final void Function(WatchEntry entry) onTap;

  const ContinueWatchingSection({
    super.key,
    required this.entries,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Text(
            'CONTINUAR VIENDO',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            clipBehavior: Clip.hardEdge,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 32),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return TVFocusWrapper(
                showGlow: false,
                onTap: () => onTap(entry),
                borderRadius: 12,
                child: SizedBox(
                  width: 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Hero(
                                tag: 'continue-watching-${entry.animeId}',
                                child: AppCachedImage(
                                  entry.animeBanner ?? entry.animeCover,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 3,
                                  color: Colors.black26,
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: (entry.progress / 100).clamp(
                                      0,
                                      1,
                                    ),
                                    child: Container(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white70,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Hero(
                        tag: 'continue-watching-title-${entry.animeId}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            entry.animeTitleRomaji,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Episodio ${entry.lastEpisodeNumber}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class BannerCarousel extends StatelessWidget {
  final List<dynamic> items;
  final void Function(Map<String, dynamic> item) onItemTap;

  const BannerCarousel({
    super.key,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return HomeFeaturedCarousel(
      items: items.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      onItemTap: onItemTap,
    );
  }
}

class ContinueReadingSection extends StatelessWidget {
  final List<ReadEntry> entries;
  final void Function(ReadEntry entry) onTap;

  const ContinueReadingSection({
    super.key,
    required this.entries,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'CONTINUAR LEYENDO',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            clipBehavior: Clip.hardEdge,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 32),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return TVFocusWrapper(
                showGlow: false,
                onTap: () => onTap(entry),
                borderRadius: 12,
                child: SizedBox(
                  width: 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Hero(
                                tag: 'continue-reading-${entry.mangaId}',
                                child: AppCachedImage(
                                  entry.mangaBanner ?? entry.mangaCover,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const Center(
                                child: Icon(
                                  Icons.book_rounded,
                                  color: Colors.white70,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Hero(
                        tag: 'continue-reading-title-${entry.mangaId}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            entry.mangaTitleRomaji,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Capítulo ${entry.lastChapterNumber}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
