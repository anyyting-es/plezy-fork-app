import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/app_shell_controller.dart';
import '../widgets/media_widgets.dart';
import '../widgets/home_widgets.dart';


class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onAnimeTap,
    required this.onMangaTap,
    this.onProfileTap,
    this.onOpenSettings,
    required this.refreshSeed,
  });

  final void Function(int animeId, {WatchEntry? resume, String? posterHeroTag, String? titleHeroTag}) onAnimeTap;
  final void Function(int mangaId, {ReadEntry? resume, String? posterHeroTag, String? titleHeroTag}) onMangaTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onOpenSettings;
  final int refreshSeed;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = ApiService.instance;
  final _storage = StorageService.instance;

  final _scrollOffsetNotifier = ValueNotifier<double>(0.0);

  static const _animeSectionConfigs = <(String, String, List<String>, String?)>[
    ('trending', 'Tendencias', ['TRENDING_DESC'], null),
    ('popular', 'Más Populares', ['POPULARITY_DESC'], null),
    ('all_time', 'Mejor Valorados', ['SCORE_DESC'], null),
    ('romance', 'Romance', ['TRENDING_DESC'], 'Romance'),
    ('action', 'Acción', ['TRENDING_DESC'], 'Action'),
    ('comedy', 'Comedia', ['TRENDING_DESC'], 'Comedy'),
    ('fantasy', 'Fantasía', ['TRENDING_DESC'], 'Fantasy'),
    ('upcoming', 'Próximos', ['POPULARITY_DESC'], 'NOT_YET_RELEASED'),
  ];

  static const _mangaSectionConfigs = <(String, String, List<String>, String?)>[
    ('trending', 'Mangas en Tendencia', ['TRENDING_DESC'], null),
    ('popular', 'Más Populares', ['POPULARITY_DESC'], null),
    ('all_time', 'Mejor Valorados', ['SCORE_DESC'], null),
    ('romance', 'Manga de Romance', ['TRENDING_DESC'], 'Romance'),
    ('action', 'Manga de Acción', ['TRENDING_DESC'], 'Action'),
    ('fantasy', 'Manga de Fantasía', ['TRENDING_DESC'], 'Fantasy'),
  ];



  bool _initialLoading = true;
  bool _isRefreshing = false;
  AppSettings _settings = AppSettings.defaults();
  
  List<WatchEntry> _continueWatchingAnime = [];
  List<ReadEntry> _continueReadingManga = [];

  static List<dynamic> _cachedCarouselAnime = [];
  static List<dynamic> _cachedCarouselManga = [];
  static final Map<String, List<dynamic>> _cachedSectionsAnime = {};
  static final Map<String, List<dynamic>> _cachedSectionsManga = {};


  static bool _hasRefreshedAnimeThisSession = false;
  static bool _hasRefreshedMangaThisSession = false;
  bool _isPerformingFetch = false;
  
  int? _currentCarouselId;
  List<Map<String, dynamic>> _featuredItems = [];


  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }


  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _loadContinue();
    }
  }

  Future<void> _load() async {
    _settings = await _storage.getAppSettings();

    // Cargar cache si existe
    final cacheAnime = await _storage.loadHomeCache(isManga: false);
    final cacheManga = await _storage.loadHomeCache(isManga: true);

    if (mounted) {
      setState(() {
        if (cacheAnime != null) {
          _cachedCarouselAnime = cacheAnime.carousel;
          _cachedSectionsAnime.addAll(cacheAnime.sections);
        }
        if (cacheManga != null) {
          _cachedCarouselManga = cacheManga.carousel;
          _cachedSectionsManga.addAll(cacheManga.sections);
        }
        _initialLoading = false;
      });
    }

    await _loadContinue();

    // Refrescar solo si el cache está expirado o no se ha hecho en esta sesión
    final isFresh = await _storage.isHomeCacheFresh(isManga: AppShellController.isMangaMode.value);
    final hasRefreshed = AppShellController.isMangaMode.value ? _hasRefreshedMangaThisSession : _hasRefreshedAnimeThisSession;

    if (!isFresh || !hasRefreshed) {
      await _fetchAllSections(silent: true);
    }
  }

  Future<void> _loadContinue() async {
    _continueWatchingAnime = await _storage.getContinueWatching();
    _continueReadingManga = await _storage.getContinueReading();
    if (mounted) setState(() {});
  }

  Future<List<dynamic>> _fetchSectionData(
    (String, String, List<String>, String?) section,
  ) async {
    final genreStr = section.$4;
    final List<String>? genreList =
        genreStr != null && genreStr != 'NOT_YET_RELEASED' ? [genreStr] : null;
    final String? status = genreStr == 'NOT_YET_RELEASED'
        ? 'NOT_YET_RELEASED'
        : null;
    final page = await _api.fetchPage(
      isManga: AppShellController.isMangaMode.value,
      sort: section.$3,
      genres: genreList,
      status: status,
      perPage: 18,
    );
    return page.media;
  }



  Future<void> _fetchAllSections({bool silent = false}) async {
    if (_isPerformingFetch) return;
    
    if (!silent && mounted) setState(() => _isRefreshing = true);
    _isPerformingFetch = true;

    try {
      // Carousel primero
      {
        final trending = await _api.fetchPage(
          isManga: AppShellController.isMangaMode.value,
          sort: ['TRENDING_DESC'],
          perPage: 10,
        );
        if (mounted) {
          setState(() {
            if (AppShellController.isMangaMode.value) {
              _cachedCarouselManga = trending.media;
            } else {
              _cachedCarouselAnime = trending.media;
            }
            _initialLoading = false;
          });
        }

        final configs = AppShellController.isMangaMode.value ? _mangaSectionConfigs : _animeSectionConfigs;
        final enabled = configs
            .where((item) => _settings.homeAnimeSections[item.$1] != false)
            .toList();

        final pending = <Future<void>>[];
        for (final section in enabled) {
          final future = _fetchSectionData(section)
              .then((items) {
                if (!mounted) return;
                setState(() {
                  if (AppShellController.isMangaMode.value) {
                    _cachedSectionsManga[section.$1] = items;
                  } else {
                    _cachedSectionsAnime[section.$1] = items;
                  }
                });
                
                _storage.saveHomeCache(
                  carousel: AppShellController.isMangaMode.value ? _cachedCarouselManga : _cachedCarouselAnime,
                  sections: AppShellController.isMangaMode.value ? _cachedSectionsManga : _cachedSectionsAnime,
                  isManga: AppShellController.isMangaMode.value,
                );
              })
              .catchError((e) {
                debugPrint('Section ${section.$1} error: $e');
              });
          pending.add(future);
        }

        await Future.wait(pending);
      }

      // Marcar como refrescado en esta sesión
      if (AppShellController.isMangaMode.value) {
        _hasRefreshedMangaThisSession = true;
      } else {
        _hasRefreshedAnimeThisSession = true;
      }
    } catch (e) {
      debugPrint('Home fetch error: $e');
    } finally {
      _isPerformingFetch = false;
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _checkAndRefresh() async {
    final hasRefreshed = AppShellController.isMangaMode.value ? _hasRefreshedMangaThisSession : _hasRefreshedAnimeThisSession;
    final isFresh = await _storage.isHomeCacheFresh(isManga: AppShellController.isMangaMode.value);
    
    if (!hasRefreshed || !isFresh) {
      _fetchAllSections(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppShellController.isMangaMode,
      builder: (context, isMangaMode, _) {
        final currentCarousel = isMangaMode ? _cachedCarouselManga : _cachedCarouselAnime;
        final currentSections = isMangaMode ? _cachedSectionsManga : _cachedSectionsAnime;
        final currentConfigs = isMangaMode ? _mangaSectionConfigs : _animeSectionConfigs;

        final isWide = MediaQuery.of(context).size.width > 900;
        final bannerHeight = isWide
            ? MediaQuery.of(context).size.height * 0.82
            : MediaQuery.of(context).size.height * 0.78;
        final showSkeleton = _initialLoading && currentCarousel.isEmpty;

        final enabledSections = currentConfigs
                .where((item) => _settings.homeAnimeSections[item.$1] != false)
                .map((e) => (e.$1, e.$2))
                .toList();

        final currentItem = currentCarousel.firstWhere(
          (item) => ((item as Map?)?['id'] as num?)?.toInt() == _currentCarouselId,
          orElse: () => null,
        );
        final bannerUrl = currentItem != null
            ? (currentItem['bannerImage'] ?? currentItem['coverImage']?['extraLarge']) as String?
            : null;
        final hasLocalAsset = _currentCarouselId != null &&
            [147105, 169580, 180745, 189046, 199029, 199221, 21].contains(_currentCarouselId);
        final showBackground = hasLocalAsset || (bannerUrl != null && bannerUrl.isNotEmpty);

        return PopScope(
          canPop: true,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Stack(
              children: [
                // ── FONDO FIJO CON EFECTO DE RESPIRACIÓN ──
                if (showBackground)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: bannerHeight,
                    child: Stack(
                      children: [
                        // Static Image Area
                        Positioned.fill(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 600),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                            child: _BackgroundBanner(
                              key: ValueKey(_currentCarouselId),
                              id: _currentCarouselId!,
                              bannerUrl: bannerUrl,
                              hasLocalAsset: hasLocalAsset,
                              scrollOffsetNotifier: _scrollOffsetNotifier,
                              bannerHeight: bannerHeight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                RefreshIndicator(
                  onRefresh: () => _fetchAllSections(silent: false),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // Only track vertical primary-axis scroll (not horizontal list scrolls)
                      if (notification is ScrollUpdateNotification &&
                          notification.depth == 0 &&
                          notification.metrics.axis == Axis.vertical) {
                        _scrollOffsetNotifier.value = notification.metrics.pixels;
                      }
                      return false;
                    },
                    child: Builder(
                      builder: (context) {
                        final isDesktop = defaultTargetPlatform == TargetPlatform.linux ||
                            defaultTargetPlatform == TargetPlatform.macOS ||
                            defaultTargetPlatform == TargetPlatform.windows;

                        Widget buildScrollView(ScrollController? controller, ScrollPhysics? physics) {
                          return CustomScrollView(
                            controller: controller,
                            physics: physics,
                            cacheExtent: 80,
                            slivers: [
                            // ── CAROUSEL ──
                            if (showSkeleton)
                              const SliverToBoxAdapter(child: _CarouselSkeleton())
                            else if (currentCarousel.isNotEmpty)
                              SliverToBoxAdapter(
                                child: HomeFeaturedCarousel(
                                  items: currentCarousel
                                      .map((e) => Map<String, dynamic>.from(e as Map))
                                      .toList(),
                                  mainScrollController: controller,
                                  onPageChanged: (id, index) {
                                    if (_currentCarouselId != id) {
                                      setState(() => _currentCarouselId = id);
                                    }
                                  },
                                  onItemsLoaded: (items) {
                                    if (_featuredItems.length != items.length) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted) {
                                          setState(() {
                                            _featuredItems = items;
                                            if (_currentCarouselId == null && items.isNotEmpty) {
                                              _currentCarouselId = (items.first['id'] as num).toInt();
                                            }
                                          });
                                        }
                                      });
                                    }
                                  },
                                  onItemTap: (item) {
                                    final id = (item['id'] as num?)?.toInt();
                                    if (id != null) {
                                      if (isMangaMode) {
                                        widget.onMangaTap(id);
                                      } else {
                                        widget.onAnimeTap(id);
                                      }
                                    }
                                  },
                                ),
                              )
                            else
                              const SliverToBoxAdapter(child: SizedBox.shrink()),
                            
                            // ── CONTENIDO SCROLLABLE (Sin fondo, flotando sobre el background) ──
                            SliverToBoxAdapter(
                              child: Builder(
                                builder: (context) {
                                  final isWide = MediaQuery.of(context).size.width > 900;
                                  return Padding(
                                    padding: EdgeInsets.only(left: isWide ? 60.0 : 0.0),
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 12),
                                        
                                        // Continuar
                                        if (isMangaMode)
                                          ContinueReadingSection(
                                            entries: _continueReadingManga,
                                            onTap: (entry) => widget.onMangaTap(
                                              entry.mangaId,
                                              resume: entry,
                                              posterHeroTag: 'continue-reading-${entry.mangaId}',
                                              titleHeroTag: 'continue-reading-title-${entry.mangaId}',
                                            ),
                                          )
                                        else
                                          ContinueWatchingSection(
                                            entries: _continueWatchingAnime,
                                            onTap: (entry) => widget.onAnimeTap(
                                              entry.animeId,
                                              resume: entry,
                                              posterHeroTag: 'continue-watching-${entry.animeId}',
                                              titleHeroTag: 'continue-watching-title-${entry.animeId}',
                                            ),
                                          ),
                                        
                                        const SizedBox(height: 32),

                                        // Secciones
                                        ...enabledSections.map((sectionConfig) {
                                          final sectionId = sectionConfig.$1;
                                          final sectionTitle = sectionConfig.$2;
                                          final items = currentSections[sectionId];
                                          final hasData = items != null && items.isNotEmpty;

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 40),
                                            child: hasData
                                                ? MediaSection(
                                                    title: sectionTitle,
                                                    items: items,
                                                    onItemTap: (item, posterTag, titleTag) {
                                                      final id = (item['id'] as num).toInt();
                                                      if (isMangaMode) {
                                                        widget.onMangaTap(id, posterHeroTag: posterTag, titleHeroTag: titleTag);
                                                      } else {
                                                        widget.onAnimeTap(id, posterHeroTag: posterTag, titleHeroTag: titleTag);
                                                      }
                                                    },
                                                  )
                                                : _SectionSkeleton(title: sectionTitle),
                                          );
                                        }),

                                        const SizedBox(height: 80),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                        }

                        if (isDesktop) {
                          return DynMouseScroll(
                            builder: (context, controller, physics) {
                              return buildScrollView(controller, physics);
                            },
                          );
                        }
                        return buildScrollView(null, null);
                      },
                    ),
                  ),
                ),

                // Indicador de refresco
                if (_isRefreshing)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 16,
                    right: 16,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),

                // ── NOTIFICACIÓN FLOTANTE DE CONEXIÓN (Abajo del header) ──
                ValueListenableBuilder(
                  valueListenable: AppShellController.showOfflineToast,
                  builder: (context, showOfflineToast, _) {
                    return ValueListenableBuilder(
                      valueListenable: AppShellController.showBackOnline,
                      builder: (context, showBackOnline, _) {
                        final show = showOfflineToast || showBackOnline;
                        final isOffline = AppShellController.isOffline.value;
                        
                        return AnimatedPositioned(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutBack,
                          top: show ? MediaQuery.paddingOf(context).top + 16 : -100,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: show ? 1.0 : 0.0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isOffline 
                                    ? Colors.redAccent.withValues(alpha: 0.9) 
                                    : Colors.greenAccent.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isOffline ? LucideIcons.wifiOff : LucideIcons.wifi,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isOffline ? 'Sin conexión' : 'Conexión recuperada',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final height = isMobile ? MediaQuery.of(context).size.height * 0.75 : 550.0;

    return SizedBox(
      height: height,
      child: Container(
        color: Colors.white.withValues(alpha: 0.03),
        child: const Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white24,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  final String title;

  const _SectionSkeleton({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) =>
                const ShimmerSkeleton(width: 150, height: 225, borderRadius: 8),
          ),
        ),
      ],
    );
  }
}

class _BackgroundBanner extends StatelessWidget {
  final int id;
  final String? bannerUrl;
  final bool hasLocalAsset;
  final ValueNotifier<double> scrollOffsetNotifier;
  final double bannerHeight;

  const _BackgroundBanner({
    super.key,
    required this.id,
    required this.bannerUrl,
    required this.hasLocalAsset,
    required this.scrollOffsetNotifier,
    required this.bannerHeight,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final isWide = MediaQuery.of(context).size.width > 900;

    return ValueListenableBuilder<double>(
      valueListenable: scrollOffsetNotifier,
      builder: (context, scrollOffset, child) {
        final scrollProgress = (scrollOffset / bannerHeight).clamp(0.0, 1.0);
        final opacity = (1.0 - scrollProgress * 1.2).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasLocalAsset)
            Image.asset(
              'assets/carrousel/${id}_b.${id == 189046 ? 'png' : 'jpg'}',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            )
          else if (bannerUrl != null && bannerUrl!.isNotEmpty)
            AppCachedImage(
              bannerUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            )
          else
            const SizedBox.shrink(),
          
          // Bottom shadow (to fade into scaffold background at the bottom of the banner)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  bgColor,
                  bgColor.withValues(alpha: 0.85),
                  bgColor.withValues(alpha: 0.45),
                  bgColor.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.20, 0.50, 1.0],
              ),
            ),
          ),
          // Left shadow (only on desktop/wide screens)
          if (isWide)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    bgColor.withValues(alpha: 0.90),
                    bgColor.withValues(alpha: 0.65),
                    bgColor.withValues(alpha: 0.35),
                    bgColor.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.12, 0.28, 0.45],
                ),
              ),
            ),
          // Right shadow (only on desktop/wide screens)
          if (isWide)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    bgColor.withValues(alpha: 0.45),
                    bgColor.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.1],
                ),
              ),
            ),
          // Top shadow (for title bar/header readability)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bgColor.withValues(alpha: 0.55),
                  bgColor.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.12],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
