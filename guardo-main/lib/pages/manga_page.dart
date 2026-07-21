import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/media_widgets.dart';
import '../widgets/home_widgets.dart';

class MangaPage extends StatefulWidget {
  const MangaPage({
    super.key,
    required this.onMangaTap,
    required this.refreshSeed,
  });

  final void Function(int mangaId, {ReadEntry? resume, String? posterHeroTag, String? titleHeroTag}) onMangaTap;
  final int refreshSeed;

  @override
  State<MangaPage> createState() => _MangaPageState();
}

class _MangaPageState extends State<MangaPage> {
  final _api = ApiService.instance;
  final _storage = StorageService.instance;

  final ScrollController _scrollController = ScrollController();

  static const _sectionConfigs = [
    ('trending', 'Tendencias Manga', ['TRENDING_DESC']),
    ('popular', 'Más Populares', ['POPULARITY_DESC']),
    ('manhwa', 'Manhwa', ['TRENDING_DESC']),
    ('action', 'Acción', ['TRENDING_DESC']),
    ('romance', 'Romance', ['TRENDING_DESC']),
    ('fantasy', 'Fantasía', ['TRENDING_DESC']),
  ];

  bool _initialLoading = true;
  bool _isRefreshing = false;
  AppSettings _settings = AppSettings.defaults();
  List<ReadEntry> _continueReading = [];

  static List<dynamic> _cachedBanner = [];
  static final Map<String, List<dynamic>> _cachedSections = {};

  @override
  void initState() {
    super.initState();
    _load();
  }


  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MangaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _loadContinue();
    }
  }

  Future<void> _load() async {
    _settings = await _storage.getAppSettings();

    // 1. Mostrar cache inmediatamente si existe
    final cache = await _storage.loadMangaCache();
    if (cache != null && mounted) {
      setState(() {
        _cachedBanner = cache.carousel;
        _cachedSections.addAll(cache.sections);
        _initialLoading = false;
      });
    }

    // 2. Cargar "continuar leyendo" (local, rápido)
    await _loadContinue();

    // 3. SIEMPRE refrescar en background
    final cacheIsFresh = await _storage.isMangaCacheFresh();
    await _fetchAllSections(silent: cacheIsFresh);
  }

  Future<List<dynamic>> _fetchSectionData(
    (String, String, List<String>) section,
  ) async {
    final key = section.$1;
    final genre = key == 'manhwa'
        ? null
        : (key == 'action'
            ? ['Action']
            : key == 'romance'
                ? ['Romance']
                : key == 'fantasy'
                    ? ['Fantasy']
                    : null);

    final page = await _api.fetchPage(
      isManga: true,
      sort: section.$3,
      genres: genre,
      perPage: 18,
    );
    return page.media;
  }

  Future<void> _fetchAllSections({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isRefreshing = true);

    try {
      final enabled = _sectionConfigs
          .where((item) => _settings.homeMangaSections[item.$1] != false)
          .toList();

      // Lanzar CADA sección de forma independiente
      final pending = <Future<void>>[];
      for (final section in enabled) {
        final future = _fetchSectionData(section).then((items) {
          if (!mounted) return;
          setState(() {
            _cachedSections[section.$1] = items;
            // Usar primera sección con datos como banner si está vacío
            if (_cachedBanner.isEmpty && items.isNotEmpty) {
              _cachedBanner = items.take(5).toList();
            }
          });
          // Guardar cache progresivamente
          _storage.saveMangaCache(
            banner: _cachedBanner,
            sections: _cachedSections,
          );
        }).catchError((e) {
          debugPrint('Manga section ${section.$1} error: $e');
        });
        pending.add(future);
      }

      await Future.wait(pending);
      await _storage.saveMangaCache(
        banner: _cachedBanner,
        sections: _cachedSections,
      );
    } catch (e) {
      debugPrint('Manga fetch error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadContinue() async {
    _continueReading = await _storage.getContinueReading();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showSkeleton = _initialLoading && _cachedBanner.isEmpty;

    final media = MediaQuery.of(context);
    final isWide = media.size.width > 900;
    final sidePadding = isWide ? 68.0 : 0.0;

    final allSections = _sectionConfigs
        .where((item) => _settings.homeMangaSections[item.$1] != false)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _fetchAllSections(silent: false),
            child: CustomScrollView(
              controller: _scrollController,
              cacheExtent: 80,
              slivers: [
                // ── BANNER CAROUSEL ──
                if (showSkeleton)
                  const SliverToBoxAdapter(child: _BannerSkeleton())
                else if (_cachedBanner.isNotEmpty)
                  SliverToBoxAdapter(
                    child: BannerCarousel(
                      items: _cachedBanner,
                      onItemTap: (item) =>
                          widget.onMangaTap((item['id'] as num).toInt()),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox.shrink()),

                // ── CONTINUE READING ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 16,
                      left: sidePadding,
                    ),
                    child: ContinueReadingSection(
                      entries: _continueReading,
                      onTap: (entry) =>
                          widget.onMangaTap(
                            entry.mangaId,
                            resume: entry,
                            posterHeroTag: 'continue-reading-${entry.mangaId}',
                            titleHeroTag: 'continue-reading-title-${entry.mangaId}',
                          ),
                    ),
                  ),
                ),

                // ── SECCIONES CON LAZY LOADING VERTICAL ──
                SliverPadding(
                  padding: EdgeInsets.only(left: sidePadding, bottom: 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final section = allSections[index];
                        final items = _cachedSections[section.$1];
                        final hasData = items != null && items.isNotEmpty;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: hasData
                              ? MediaSection(
                                  title: section.$2,
                                  items: items,
                                  onItemTap: (item, posterTag, titleTag) => widget.onMangaTap(
                                    (item['id'] as num).toInt(),
                                    posterHeroTag: posterTag,
                                    titleHeroTag: titleTag,
                                  ),
                                )
                              : _MangaSectionSkeleton(title: section.$2),
                        );
                      },
                      childCount: allSections.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),

          // Indicador sutil de refresco
          if (_isRefreshing)
            const Positioned(
              top: 16,
              right: 16,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final height = isMobile
        ? MediaQuery.of(context).size.height * 0.75
        : 550.0;

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

class _MangaSectionSkeleton extends StatelessWidget {
  final String title;

  const _MangaSectionSkeleton({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) => const ShimmerSkeleton(
              width: 150,
              height: 225,
              borderRadius: 8,
            ),
          ),
        ),
      ],
    );
  }
}
