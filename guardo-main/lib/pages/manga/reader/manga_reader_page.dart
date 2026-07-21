import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../models/app_models.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import 'widgets/reader_widgets.dart';

enum ReadingMode { vertical, horizontal }
enum ReadingDirection { ltr, rtl }

class MangaReaderPage extends StatefulWidget {
  const MangaReaderPage({
    super.key,
    required this.anilistManga,
    required this.mwDetails,
    required this.chapters,
    required this.currentIndex,
  });

  final Map<String, dynamic> anilistManga;
  final ManhwaDetails mwDetails;
  final List<Map<String, dynamic>> chapters;
  final int currentIndex;

  @override
  State<MangaReaderPage> createState() => _MangaReaderPageState();
}

class _MangaReaderPageState extends State<MangaReaderPage> {
  final _api = ApiService.instance;
  final _storage = StorageService.instance;

  late int _index;
  bool _loading = true;
  bool _showUI = true;
  int _currentPage = 1;
  ReadingMode _mode = ReadingMode.vertical;
  ReadingDirection _direction = ReadingDirection.ltr;
  List<String> _pages = [];
  late PageController _pageController;
  late ScrollController _scrollController;

  final Map<int, GlobalKey> _pageKeys = {};

  @override
  void initState() {
    super.initState();
    _index = widget.currentIndex;
    _pageController = PageController(initialPage: 0);
    _scrollController = ScrollController();
    _scrollController.addListener(_onVerticalScroll);
    _loadChapter();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    _pageController.dispose();
    _scrollController.removeListener(_onVerticalScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onVerticalScroll() {
    if (_pages.isEmpty || _mode != ReadingMode.vertical) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final viewportMiddle = screenHeight * 0.35;

    int visiblePage = 1;
    for (int i = 0; i < _pages.length; i++) {
      final key = _pageKeys[i];
      if (key?.currentContext == null) continue;
      final box = key!.currentContext!.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final pos = box.localToGlobal(Offset.zero).dy;
      final height = box.size.height;
      if (pos <= viewportMiddle && pos + height > viewportMiddle) {
        visiblePage = i + 1;
        break;
      }
    }

    if (_currentPage != visiblePage) {
      setState(() => _currentPage = visiblePage);
    }
  }

  Future<void> _loadChapter() async {
    setState(() {
      _loading = true;
      _currentPage = 1;
      _pageKeys.clear();
      if (_mode == ReadingMode.horizontal && _pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
    final chapter = widget.chapters[_index];
    final pagesResult = await _api.manhwaGetChapterPages(widget.mwDetails.slug, chapter['id'].toString());
    final List<String> pages = (pagesResult as List).cast<String>();

    await _storage.markChapterRead(
      mangaId: (widget.anilistManga['id'] as num?)?.toInt() ?? 0,
      chapterNumber: (chapter['number'] as num).floor(),
      manga: widget.anilistManga,
      sourceSlug: widget.mwDetails.slug,
    );

    if (!mounted) return;

    for (int i = 0; i < pages.length; i++) {
      _pageKeys[i] = GlobalKey();
    }

    setState(() {
      _pages = pages;
      _loading = false;
    });

    if (_mode == ReadingMode.vertical && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    _precacheImages(pages);
  }

  Future<void> _precacheImages(List<String> urls) async {
    if (!mounted || urls.isEmpty) return;

    final immediate = urls.take(5).toList();
    for (final url in immediate) {
      if (!mounted) return;
      try {
        if (url.startsWith('http')) {
          await precacheImage(NetworkImage(url), context);
        }
      } catch (_) {}
    }
  }

  void _changeChapter(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= widget.chapters.length) return;
    setState(() => _index = nextIndex);
    _loadChapter();
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
      if (_showUI) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
  }

  void _setReadingMode(ReadingMode mode) {
    setState(() {
      _mode = mode;
      if (mode == ReadingMode.horizontal) {
        _pageController = PageController(initialPage: _currentPage - 1);
      }
    });
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) => Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollController,
              children: [
                const SizedBox(height: 12),
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('AJUSTES DE LECTURA', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('MODO', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                _buildSettingItem(
                  'Vertical', 
                  LucideIcons.scroll, 
                  _mode == ReadingMode.vertical,
                  () {
                    _setReadingMode(ReadingMode.vertical);
                    setSheetState(() {});
                  }
                ),
                _buildSettingItem(
                  'Paginado', 
                  LucideIcons.bookOpen, 
                  _mode == ReadingMode.horizontal,
                  () {
                    _setReadingMode(ReadingMode.horizontal);
                    setSheetState(() {});
                  }
                ),

                if (_mode == ReadingMode.horizontal) ...[
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('DIRECCIÓN', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  _buildSettingItem(
                    'Izquierda a Derecha', 
                    LucideIcons.arrowRight, 
                    _direction == ReadingDirection.ltr,
                    () {
                      setState(() => _direction = ReadingDirection.ltr);
                      setSheetState(() {});
                    }
                  ),
                  _buildSettingItem(
                    'Derecha a Izquierda', 
                    LucideIcons.arrowLeft, 
                    _direction == ReadingDirection.rtl,
                    () {
                      setState(() => _direction = ReadingDirection.rtl);
                      setSheetState(() {});
                    }
                  ),
                ],
                
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('SALTAR A CAPÍTULO', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: widget.chapters.length,
                  itemBuilder: (context, index) {
                    final ch = widget.chapters[index];
                    final isCurrent = index == _index;
                    return GestureDetector(
                      onTap: () {
                        _changeChapter(index);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent ? Colors.white.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isCurrent ? Colors.white : Colors.white10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          ch['number'].toString(),
                          style: TextStyle(
                            color: isCurrent ? Colors.white : Colors.white60,
                            fontWeight: isCurrent ? FontWeight.w900 : FontWeight.normal,
                            fontSize: 12
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(String label, IconData icon, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.white24, size: 18),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white38, fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            const Spacer(),
            if (selected) const Icon(LucideIcons.check, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapters[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleUI,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _pages.isEmpty
                      ? const Center(child: Text('No hay páginas para este capítulo', style: TextStyle(color: Colors.white70)))
                      : _mode == ReadingMode.vertical
                          ? ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.zero,
                              itemCount: _pages.length,
                              cacheExtent: 3000,
                              addAutomaticKeepAlives: true,
                              itemBuilder: (context, index) {
                                return ReaderPageItem(
                                  key: _pageKeys[index],
                                  url: _pages[index],
                                  index: index,
                                  mode: _mode,
                                );
                              },
                            )
                          : PageView.builder(
                              controller: _pageController,
                              reverse: _direction == ReadingDirection.rtl,
                              itemCount: _pages.length,
                              onPageChanged: (idx) => setState(() => _currentPage = idx + 1),
                              itemBuilder: (context, index) {
                                return ReaderPageItem(
                                  key: _pageKeys[index],
                                  url: _pages[index],
                                  index: index,
                                  mode: _mode,
                                );
                              },
                            ),
            ),
          ),

          AnimatedPosition(
            show: _showUI,
            top: true,
            child: Container(
              height: MediaQuery.of(context).padding.top + 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(
                  chapter['title'] ?? 'Capítulo ${chapter['number']}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          AnimatedPosition(
            show: _showUI,
            top: false,
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 40),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161616).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _index > 0 ? () => _changeChapter(_index - 1) : null,
                      icon: Icon(LucideIcons.chevronLeft, color: _index > 0 ? Colors.white : Colors.white24),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showSettingsSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Capítulo ${chapter['number']}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                            if (_pages.isNotEmpty)
                              Text(
                                'Página $_currentPage / ${_pages.length}',
                                style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _index < widget.chapters.length - 1 ? () => _changeChapter(_index + 1) : null,
                      icon: Icon(LucideIcons.chevronRight, color: _index < widget.chapters.length - 1 ? Colors.white : Colors.white24),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedPosition extends StatelessWidget {
  final bool show;
  final bool top;
  final Widget child;

  const AnimatedPosition({
    super.key,
    required this.show,
    required this.top,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: top ? (show ? 0 : -120) : null,
      bottom: top ? null : (show ? 0 : -120),
      left: 0,
      right: 0,
      child: child,
    );
  }
}
