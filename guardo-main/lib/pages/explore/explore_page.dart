import 'package:flutter/material.dart';
import 'package:smooth_scroll_multiplatform/smooth_scroll_multiplatform.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../widgets/media_widgets.dart';
import '../../widgets/dropdown.dart';
import 'widgets/explore_tiles.dart';
import 'widgets/explore_filters.dart';

enum ExploreViewMode { poster, list, horizontal }

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, required this.onAnimeTap});

  final void Function(int id, {String? posterHeroTag, String? titleHeroTag}) onAnimeTap;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService.instance;
  final _queryController = TextEditingController();
  final _searchFocusNode = FocusNode();
  AnimationController? _switchAnim;
  Animation<double>? _switchOpacity;

  bool _loading = false;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasNext = false;

  String _sort = 'TRENDING_DESC';
  String _formatFilter = '';
  String _statusFilter = '';
  int _yearFilter = 0;
  final List<String> _genres = [];

  List<dynamic> _results = [];
  int _resultsVersion = 0;
  ExploreViewMode _viewMode = ExploreViewMode.poster;

  static const _sortOptions = [
    ('TITLE_ROMAJI', 'Título'),
    ('POPULARITY_DESC', 'Popularidad'),
    ('SCORE_DESC', 'Puntuación'),
    ('TRENDING_DESC', 'Tendencia'),
    ('FAVOURITES_DESC', 'Favoritos'),
    ('ID_DESC', 'Agregado Reciente'),
    ('START_DATE_DESC', 'Fecha de estreno'),
  ];

  static const _formatOptions = [
    ('', 'Todos'),
    ('TV', 'Serie TV'),
    ('MOVIE', 'Película'),
    ('OVA', 'OVA'),
    ('ONA', 'ONA'),
    ('SPECIAL', 'Especial'),
    ('TV_SHORT', 'Corto TV'),
  ];

  static const _statusOptions = [
    ('', 'Todos'),
    ('RELEASING', 'En emisión'),
    ('FINISHED', 'Finalizado'),
    ('NOT_YET_RELEASED', 'Próximamente'),
  ];

  static final List<(int, String)> _yearOptions = (() {
    final currentYear = DateTime.now().year + 1;
    final years = <(int, String)>[(0, 'Todos')];
    for (var i = 0; i < 40; i++) {
      final year = currentYear - i;
      years.add((year, '$year'));
    }
    return years;
  })();

  static const _genreOptions = [
    'Todos',
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Horror',
    'Mahou Shoujo',
    'Mecha',
    'Music',
    'Mystery',
    'Psychological',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Thriller',
  ];

  @override
  void initState() {
    super.initState();

    final anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _switchAnim = anim;
    _switchOpacity = Tween(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeInOut));
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _search();
  }

  @override
  void dispose() {
    _switchAnim?.dispose();
    _queryController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _setViewMode(ExploreViewMode value) {
    if (_viewMode == value) return;
    final anim = _switchAnim;
    if (anim == null) {
      setState(() => _viewMode = value);
      return;
    }
    anim.forward().then((_) {
      if (!mounted) return;
      setState(() => _viewMode = value);
      anim.reverse();
    });
  }

  void _onScrollMetrics(ScrollMetrics metrics) {
    if (_loading || _loadingMore || !_hasNext) return;
    final maxScroll = metrics.maxScrollExtent;
    final current = metrics.pixels;
    if (current >= maxScroll - 520) {
      _search(append: true);
    }
  }

  Future<void> _search({bool append = false}) async {
    if (append) {
      if (_loading || _loadingMore || !_hasNext) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _page = 1;
      });
    }

    final nextPage = append ? _page + 1 : 1;
    final query = _queryController.text.trim();

    try {
      final page = await _api.fetchPage(
        search: query.isNotEmpty ? query : null,
        isManga: false,
        sort: [_sort],
        genres: _genres.isNotEmpty ? _genres : null,
        format: _formatFilter.isNotEmpty ? _formatFilter : null,
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
        year: _yearFilter > 0 ? _yearFilter : null,
        page: nextPage,
        perPage: 24,
      );

      if (!mounted) return;

      setState(() {
        _results = append
            ? [..._results, ...page.media]
            : List<dynamic>.from(page.media);
        if (!append) _resultsVersion++;
        _page = nextPage;
        _hasNext = page.hasNextPage;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Widget _displayModeButton({
    required IconData icon,
    required ExploreViewMode value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _viewMode == value;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => _setViewMode(value),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _formatLabel(String value) {
    if (value.isEmpty) return 'TV';
    return value
        .toLowerCase()
        .split('_')
        .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  String _statusText(Map<String, dynamic> item) {
    final status = ((item['status'] as String?) ?? '').toUpperCase();
    if (status.isEmpty) return '—';
    switch (status) {
      case 'RELEASING':
        return 'EMISIÓN';
      case 'FINISHED':
        return 'FINALIZADO';
      case 'NOT_YET_RELEASED':
        return 'PRÓXIMO';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  void _showFiltersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FiltersModal(
        initialGenres: _genres,
        initialSort: _sort,
        initialFormat: _formatFilter,
        initialStatus: _statusFilter,
        initialYear: _yearFilter,
        sortOptions: _sortOptions,
        formatOptions: _formatOptions,
        statusOptions: _statusOptions,
        yearOptions: _yearOptions,
        onFiltersChanged: (genres, sort, format, status, year) {
          setState(() {
            _genres.clear();
            _genres.addAll(genres);
            _sort = sort;
            _formatFilter = format;
            _statusFilter = status;
            _yearFilter = year;
          });
          _search();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortLabel = _sortOptions
        .firstWhere((o) => o.$1 == _sort, orElse: () => _sortOptions.first)
        .$2;
    final baseTheme = Theme.of(context);
    final scheme = baseTheme.colorScheme;
    final exploreTextTheme = GoogleFonts.dmSansTextTheme(baseTheme.textTheme);
    final panelBg = scheme.onSurface.withValues(alpha: 0.06);
    final panelBorder = scheme.onSurface.withValues(alpha: 0.12);
    final subtleText = scheme.onSurface.withValues(alpha: 0.62);
    final mutedText = scheme.onSurface.withValues(alpha: 0.48);

    final activeChips = <String>[];
    if (_formatFilter.isNotEmpty) {
      activeChips.add(
        _formatOptions.firstWhere((o) => o.$1 == _formatFilter).$2,
      );
    }
    if (_statusFilter.isNotEmpty) {
      activeChips.add(
        _statusOptions.firstWhere((o) => o.$1 == _statusFilter).$2,
      );
    }
    if (_yearFilter > 0) activeChips.add('$_yearFilter');
    activeChips.addAll(_genres);

    return Theme(
      data: baseTheme.copyWith(textTheme: exploreTextTheme),
      child: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              _onScrollMetrics(notification.metrics);
            }
            return false;
          },
          child: DynMouseScroll(
            builder: (context, controller, physics) {
              return CustomScrollView(
                controller: controller,
                physics: physics,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(MediaQuery.of(context).size.width > 900 ? 88 : 18, 14, 18, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0A0A0A),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.15),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 12),
                                              Icon(
                                                LucideIcons.search,
                                                color: mutedText,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: TextField(
                                                  controller: _queryController,
                                                  focusNode: _searchFocusNode,
                                                  textInputAction: TextInputAction.search,
                                                  onChanged: (_) => setState(() {}),
                                                  onSubmitted: (_) => _search(),
                                                  decoration: InputDecoration(
                                                    hintText: 'Buscar anime...',
                                                    hintStyle: TextStyle(color: mutedText),
                                                    border: InputBorder.none,
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.zero,
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: scheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                              if (_queryController.text.isNotEmpty)
                                                IconButton(
                                                  icon: const Icon(LucideIcons.x, size: 18),
                                                  color: subtleText,
                                                  onPressed: () {
                                                    _queryController.clear();
                                                    setState(() {});
                                                    _search();
                                                  },
                                                ),
                                              const SizedBox(width: 4),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      PremiumDropdown(
                                        items: _yearOptions.map((e) => e.$2).toList(),
                                        width: 100,
                                        height: 36,
                                        defaultTitle: _yearFilter == 0 ? 'AÑO' : '$_yearFilter',
                                        initialIndex: _yearOptions.indexWhere((e) => e.$1 == _yearFilter),
                                        onSelected: (idx) {
                                          setState(() => _yearFilter = _yearOptions[idx].$1);
                                          _search();
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInlineFilters(),
                                ],
                              );
                            },
                          ),
                          if (activeChips.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 30,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: activeChips.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (context, index) => Container(
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: panelBg,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: panelBorder),
                                        ),
                                        child: Text(
                                          activeChips[index],
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: subtleText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _genres.clear();
                                      _yearFilter = 0;
                                      _statusFilter = '';
                                      _formatFilter = '';
                                      _sort = 'TRENDING_DESC';
                                    });
                                    _search();
                                  },
                                  child: Text(
                                    'Limpiar todo',
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Anime · $sortLabel',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 34,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: panelBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: panelBorder),
                                ),
                                child: Row(
                                  children: [
                                    _displayModeButton(
                                      icon: Icons.apps_rounded,
                                      value: ExploreViewMode.poster,
                                    ),
                                    _displayModeButton(
                                      icon: Icons.view_list_rounded,
                                      value: ExploreViewMode.list,
                                    ),
                                    _displayModeButton(
                                      icon: Icons.view_carousel_rounded,
                                      value: ExploreViewMode.horizontal,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (_loading && _results.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    if (_viewMode == ExploreViewMode.list)
                      _buildListMode()
                    else if (_viewMode == ExploreViewMode.horizontal ||
                        (_queryController.text.trim().isNotEmpty &&
                            _viewMode == ExploreViewMode.poster))
                      _buildHorizontalMode()
                    else
                      _buildCompactMode(),
                    if (_loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(strokeWidth: 2.6),
                            ),
                          ),
                        ),
                      ),
                    if (!_loading && _results.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Center(
                            child: Text(
                              'Sin resultados.',
                              style: TextStyle(color: subtleText, fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildListMode() {
    final isWide = MediaQuery.of(context).size.width > 900;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(isWide ? 88 : 16, 8, 16, 28),
      sliver: SliverList.separated(
        itemBuilder: (context, index) {
          final item = Map<String, dynamic>.from(_results[index] as Map);
          final id = (item['id'] as num?)?.toInt() ?? 0;
          final title =
              (item['title']?['romaji'] as String?) ??
              (item['title']?['english'] as String?) ??
              'Sin título';
          final image =
              (item['coverImage']?['large'] as String?) ??
              (item['coverImage']?['extraLarge'] as String?) ??
              '';
          final scoreRaw = (item['averageScore'] as num?)?.toDouble();
          final score = scoreRaw == null
              ? null
              : ((scoreRaw / 10).clamp(0, 10)).toDouble();
          final year = (item['seasonYear'] as num?)?.toInt();
          final genres = (item['genres'] as List<dynamic>? ?? const [])
              .cast<String>()
              .take(4)
              .toList();

          return _buildAnimatedResultItem(
            index: index,
            child: FadeTransition(
              opacity: _switchOpacity ?? const AlwaysStoppedAnimation(1.0),
              child: ExploreMediaListTile(
                title: title,
                image: image,
                genres: genres,
                score: score,
                format: _formatLabel((item['format'] as String?) ?? ''),
                year: year,
                status: _statusText(item),
                onTap: () => widget.onAnimeTap(id),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemCount: _results.length,
      ),
    );
  }

  Widget _buildInlineFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                label: 'GÉNERO',
                items: _genreOptions,
                selectedIndex: _genres.isEmpty
                    ? 0
                    : _genreOptions.indexOf(
                        _genres.first.isNotEmpty ? _genres.first : 'Todos',
                      ),
                onSelected: (idx) {
                  setState(() {
                    _genres.clear();
                    if (idx > 0) _genres.add(_genreOptions[idx]);
                  });
                  _search();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFilterDropdown(
                label: 'ESTADO',
                items: _statusOptions.map((e) => e.$2).toList(),
                selectedIndex: _statusOptions.indexWhere(
                  (e) => e.$1 == _statusFilter,
                ),
                onSelected: (idx) {
                  setState(() => _statusFilter = _statusOptions[idx].$1);
                  _search();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                label: 'FORMATO',
                items: _formatOptions.map((e) => e.$2).toList(),
                selectedIndex: _formatOptions.indexWhere(
                  (e) => e.$1 == _formatFilter,
                ),
                onSelected: (idx) {
                  setState(() => _formatFilter = _formatOptions[idx].$1);
                  _search();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFilterDropdown(
                label: 'ORDEN',
                items: _sortOptions.map((e) => e.$2).toList(),
                selectedIndex: _sortOptions.indexWhere((e) => e.$1 == _sort),
                onSelected: (idx) {
                  setState(() => _sort = _sortOptions[idx].$1);
                  _search();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required List<String> items,
    required int selectedIndex,
    required Function(int) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return PremiumDropdown(
              items: items,
              width: constraints.maxWidth,
              height: 36,
              defaultTitle: items[selectedIndex.clamp(0, items.length - 1)],
              initialIndex: selectedIndex.clamp(0, items.length - 1),
              onSelected: onSelected,
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedResultItem({required int index, required Widget child}) {
    final delayMs = (index * 24).clamp(0, 240);
    return EntranceFader(
      key: ValueKey('result-${_resultsVersion}_$index'),
      delay: delayMs,
      duration: const Duration(milliseconds: 360),
      offset: const Offset(0, 12),
      child: child,
    );
  }

  Widget _buildCompactMode() {
    final isWide = MediaQuery.of(context).size.width > 900;
    final width = MediaQuery.of(context).size.width - 32;
    final crossAxisCount = (width / 130.0).floor().clamp(2, 9);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(isWide ? 88 : 16, 8, 16, 28),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = Map<String, dynamic>.from(_results[index] as Map);
          final id = (item['id'] as num?)?.toInt() ?? 0;

          return _buildAnimatedResultItem(
            index: index,
            child: MediaCard(
              item: item,
              onTap: () => widget.onAnimeTap(
                id,
                posterHeroTag: 'explore-grid-$id',
                titleHeroTag: 'explore-grid-title-$id',
              ),
              heroTagPrefix: 'explore-grid',
            ),
          );
        }, childCount: _results.length),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 24,
          crossAxisSpacing: 20,
          childAspectRatio: 0.48,
        ),
      ),
    );
  }

  Widget _buildHorizontalMode() {
    if (_results.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    final hasSearch = _queryController.text.trim().isNotEmpty;

    if (hasSearch) {
      final series = _results.where((item) {
        final format = ((item as Map)['format'] as String?) ?? 'TV';
        return format.toUpperCase() != 'MOVIE';
      }).toList();
      final movies = _results.where((item) {
        final format = ((item as Map)['format'] as String?) ?? 'TV';
        return format.toUpperCase() == 'MOVIE';
      }).toList();

      final sections = <Widget>[];
      if (series.isNotEmpty) {
        sections.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: MediaSection(
              title: '📺 Series',
              items: series,
              useBackdrop: false,
              onItemTap: (item, posterTag, titleTag) =>
                  widget.onAnimeTap((item['id'] as num).toInt(), posterHeroTag: posterTag, titleHeroTag: titleTag),
            ),
          ),
        );
      }
      if (movies.isNotEmpty) {
        sections.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: MediaSection(
              title: '🎬 Películas',
              items: movies,
              useBackdrop: false,
              onItemTap: (item, posterTag, titleTag) =>
                  widget.onAnimeTap((item['id'] as num).toInt(), posterHeroTag: posterTag, titleHeroTag: titleTag),
            ),
          ),
        );
      }

      final isWide = MediaQuery.of(context).size.width > 900;
      return SliverPadding(
        padding: EdgeInsets.only(left: isWide ? 68 : 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => sections[index],
            childCount: sections.length,
          ),
        ),
      );
    }

    final chunks = <List<dynamic>>[];
    for (var i = 0; i < _results.length; i += 12) {
      chunks.add(_results.sublist(i, (i + 12).clamp(0, _results.length)));
    }

    final isWide = MediaQuery.of(context).size.width > 900;
    return SliverPadding(
      padding: EdgeInsets.only(left: isWide ? 68 : 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
        final items = chunks[index];
        final title = index == 0
            ? 'Resultados'
            : 'Más descubrimientos ${index + 1}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: MediaSection(
            title: title,
            items: items,
            useBackdrop: false,
            onItemTap: (item, posterTag, titleTag) {
              widget.onAnimeTap((item['id'] as num).toInt(), posterHeroTag: posterTag, titleHeroTag: titleTag);
            },
          ),
        );
      }, childCount: chunks.length),
      ),
    );
  }
}
