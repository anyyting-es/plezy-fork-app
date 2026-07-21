import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) 'package:anityng/stubs/io_stub.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart'
    if (dart.library.html) 'package:anityng/stubs/bitsdojo_window_stub.dart';
import 'dart:ui' show PlatformDispatcher;

import 'models/app_models.dart';
import 'services/app_shell_controller.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'widgets/tv_widgets.dart';
import 'pages/anime/anime_detail_page.dart';
import 'pages/explore/explore_page.dart';
import 'pages/home_page.dart';
import 'pages/manga_page.dart';
import 'pages/manga/manga_detail_page.dart';
import 'pages/lists_page.dart';
import 'pages/profile_page.dart';
import 'pages/settings_page.dart';
import 'extensions/extension_service.dart';
import 'widgets/mini_player.dart';

bool _isKnownWindowsKeyAssertion(Object error, [StackTrace? stackTrace]) {
  if (kIsWeb || !Platform.isWindows) return false;
  final text = error.toString().toLowerCase();
  final stack = (stackTrace?.toString() ?? '').toLowerCase();

  final hasKeysPressedAssertion =
      text.contains(
        'attempted to send a key down event when no keys are in keyspressed',
      ) ||
      text.contains('event is! rawkeydownevent || _keyspressed.isnotempty');
  final isWindowsRawKeyboardIssue =
      text.contains('rawkeyeventdatawindows') ||
      stack.contains('raw_keyboard.dart:863');

  return hasKeysPressedAssertion && isWindowsRawKeyboardIssue;
}

void _installWindowsKeyboardAssertionFilter() {
  if (kIsWeb || !Platform.isWindows) return;

  final prevFlutterError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isKnownWindowsKeyAssertion(details.exception, details.stack)) return;
    prevFlutterError?.call(details);
  };

  final prevPlatformError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    if (_isKnownWindowsKeyAssertion(error, stackTrace)) return true;
    if (prevPlatformError != null) return prevPlatformError(error, stackTrace);
    return false;
  };
}

bool _debugPrintFilter(String message) {
  if (message.contains('accessibility_bridge') || message.contains('AXTree'))
    return false;
  if (message.contains('[MPV DEBUG]')) return false;
  return true;
}

void _installDebugPrintFilter() {
  final originalPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message == null) return;
    if (_debugPrintFilter(message))
      originalPrint(message, wrapWidth: wrapWidth);
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _installWindowsKeyboardAssertionFilter();
  _installDebugPrintFilter();
  
  await dotenv.load(fileName: ".env");

  // Cargar settings
  final settingsFuture = StorageService.instance.getAppSettings();
  final settings = await settingsFuture;

  AppShellController.updateUiTheme(
    UiThemeSettings(
      palette: settings.themePalette,
      themeMode: settings.themeMode,
      oledBlack: settings.oledBlack,
    ),
  );

  if (Platform.isWindows) {
    doWhenWindowReady(() {
      const initialSize = Size(1280, 720);
      appWindow.minSize = const Size(600, 480);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });
  }

  runApp(const AnityngApp());

  // Cargar extensiones DESPUÉS de que la app ya está corriendo.
  // Esto evita que el usuario espere viendo una pantalla negra.
  await ExtensionService().loadBuiltInExtensions();
}

Color _getSeedColor(String palette) {
  switch (palette) {
    case 'violet':
      return Colors.deepPurple;
    case 'blue':
      return Colors.blue;
    case 'green':
      return Colors.green;
    case 'amber':
      return Colors.amber;
    case 'rose':
      return Colors.pink;
    case 'indigo':
      return Colors.indigo;
    case 'orange':
      return Colors.orange;
    case 'teal':
      return Colors.teal;
    case 'purple':
      return Colors.purple;
    case 'red':
      return Colors.red;
    case 'cyan':
      return Colors.cyan;
    case 'lime':
      return Colors.lime;
    case 'deepOrange':
      return Colors.deepOrange;
    default:
      return Colors.deepPurple;
  }
}

class AnityngApp extends StatelessWidget {
  const AnityngApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UiThemeSettings>(
      valueListenable: AppShellController.uiThemeSettings,
      builder: (context, uiTheme, _) {
        final seedColor = _getSeedColor(uiTheme.palette);

        ThemeMode themeMode;
        switch (uiTheme.themeMode) {
          case 'light':
            themeMode = ThemeMode.light;
            break;
          case 'dark':
            themeMode = ThemeMode.dark;
            break;
          case 'system':
          default:
            themeMode = ThemeMode.system;
            break;
        }

        final lightColorScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        );

        var darkColorScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        );

        if (uiTheme.oledBlack) {
          darkColorScheme = darkColorScheme.copyWith(
            surface: Colors.black,
          );
        }

        return MaterialApp(
          title: 'Anityng',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: lightColorScheme,
            scaffoldBackgroundColor: lightColorScheme.surface,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor: uiTheme.oledBlack ? Colors.black : darkColorScheme.surface,
            useMaterial3: true,
          ),
          scrollBehavior: MyCustomScrollBehavior(),
          builder: (context, child) {
            if (child == null || !Platform.isWindows) {
              return child ?? const SizedBox.shrink();
            }
            return ValueListenableBuilder<bool>(
              valueListenable: AppShellController.isPlayerFullscreen,
              builder: (context, playerFullscreen, _) {
                const titleBarHeight = 36.0;
                return Stack(
                  children: [
                    Positioned.fill(child: RepaintBoundary(child: child)),
                    if (!playerFullscreen)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: RepaintBoundary(
                          child: SizedBox(
                            height: titleBarHeight,
                            child: Row(
                              children: [
                                Expanded(
                                  child: MoveWindow(
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                                const WindowButtons(),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
          home: const AppShell(),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  int _refreshSeed = 0;
  final GlobalKey _stackKey = GlobalKey();
  final FocusNode _sidebarFocusNode = FocusNode();
  bool _sidebarFocused = false;

  void _setTab(int nextTab) {
    if (_tab == nextTab) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = nextTab);
  }

  void _handleExternalTabRequest() {
    final tab = AppShellController.tabRequest.value;
    if (tab == null || !mounted) return;
    _setTab(tab);
    AppShellController.clearRequest();
  }

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    AppShellController.tabRequest.addListener(_handleExternalTabRequest);
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    
    // Check initial state
    final results = await connectivity.checkConnectivity();
    _updateConnectionStatus(results);

    // Listen for changes
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final bool isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
    
    if (mounted) {
      if (AppShellController.isOffline.value && !isOffline) {
        // Returned online
        AppShellController.isOffline.value = false;
        AppShellController.showBackOnline.value = true;
        AppShellController.showOfflineToast.value = false;
        
        // Hide "back online" after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          AppShellController.showBackOnline.value = false;
        });
      } else if (!AppShellController.isOffline.value && isOffline) {
        // Went offline
        AppShellController.isOffline.value = true;
        AppShellController.showOfflineToast.value = true;
        
        // Hide "offline toast" after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          AppShellController.showOfflineToast.value = false;
        });
      } else {
        AppShellController.isOffline.value = isOffline;
      }
    }
  }

  @override
  void dispose() {
    AppShellController.tabRequest.removeListener(_handleExternalTabRequest);
    _connectivitySubscription.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // --- GLOBAL SEARCH LOGIC ---
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _searchResults = [];
  bool _isSearchLoading = false;
  String _searchQuery = '';

  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchLoading = false;
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _isSearchLoading = true;
    });

    try {
      final page = await ApiService.instance.fetchPage(
        isManga: AppShellController.isMangaMode.value,
        search: query,
        perPage: 15,
      );
      if (mounted && _searchQuery == query) {
        setState(() {
          _searchResults = page.media;
          _isSearchLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Global Search error: $e');
      if (mounted) setState(() => _isSearchLoading = false);
    }
  }

  void _toggleSearch() {
    final next = !AppShellController.isSearching.value;
    AppShellController.isSearching.value = next;
    if (next) {
      _searchFocusNode.requestFocus();
    } else {
      _searchController.clear();
      _searchResults = [];
    }
  }


  Future<void> _openAnime(int animeId, {WatchEntry? resume, String? posterHeroTag, String? titleHeroTag}) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimeDetailPage(
          animeId: animeId,
          resume: resume,
          posterHeroTag: posterHeroTag,
          titleHeroTag: titleHeroTag,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _refreshSeed++);
  }

  Future<void> _openManga(int mangaId, {ReadEntry? resume, String? posterHeroTag, String? titleHeroTag}) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MangaDetailPage(
          mangaId: mangaId,
          resume: resume,
          posterHeroTag: posterHeroTag,
          titleHeroTag: titleHeroTag,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _refreshSeed++);
  }

  void _openSettings() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SettingsPage(onSettingsSaved: () => setState(() => _refreshSeed++)),
      ),
    );
  }

  void _openProfile() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          refreshSeed: _refreshSeed,
          onAnimeTap: (id, {posterHeroTag, titleHeroTag}) => _openAnime(id, posterHeroTag: posterHeroTag, titleHeroTag: titleHeroTag),
          onOpenSettings: _openSettings,
        ),
      ),
    );
  }

  // Lazy builders para no construir todas las pestañas al inicio.
  // Solo se crea el widget cuando la pestaña se visita por primera vez.
  final List<Widget?> _pageCache = List<Widget?>.filled(5, null);
  final List<int> _pageCacheSeed = List<int>.filled(5, -1);

  Widget _buildPage(int index) {
    // Invalidar cache si el refreshSeed cambió para páginas que lo usan
    final usesSeed = index == 0 || index == 1 || index == 3 || index == 4;
    if (_pageCache[index] != null &&
        usesSeed &&
        _pageCacheSeed[index] == _refreshSeed) {
      return _pageCache[index]!;
    }

    Widget page;
    switch (index) {
      case 0:
        page = HomePage(
          key: const ValueKey('home'),
          refreshSeed: _refreshSeed,
          onAnimeTap: (id, {resume, posterHeroTag, titleHeroTag}) => _openAnime(id, resume: resume, posterHeroTag: posterHeroTag, titleHeroTag: titleHeroTag),
          onMangaTap: (id, {resume, posterHeroTag, titleHeroTag}) => _openManga(id, resume: resume, posterHeroTag: posterHeroTag, titleHeroTag: titleHeroTag),
          onProfileTap: () => _setTab(4),
          onOpenSettings: _openSettings,
        );
        break;
      case 1:
        page = MangaPage(
          key: const ValueKey('manga'),
          refreshSeed: _refreshSeed,
          onMangaTap: (id, {resume, posterHeroTag, titleHeroTag}) => _openManga(id, resume: resume, posterHeroTag: posterHeroTag, titleHeroTag: titleHeroTag),
        );
        break;
      case 2:
        page = ExplorePage(
          key: const ValueKey('explore'),
          onAnimeTap: (id, {posterHeroTag, titleHeroTag}) => _openAnime(id, posterHeroTag: posterHeroTag, titleHeroTag: titleHeroTag),
        );
        break;
      case 3:
        page = ListsPage(
          key: const ValueKey('lists'),
          refreshSeed: _refreshSeed,
          onAnimeTap: (id, {posterHeroTag, titleHeroTag}) => _openAnime(id, posterHeroTag: posterHeroTag, titleHeroTag: titleHeroTag),
        );
        break;
      case 4:
        page = ProfilePage(
          key: const ValueKey('profile'),
          refreshSeed: _refreshSeed,
          onAnimeTap: (id, {posterHeroTag, titleHeroTag}) => _openAnime(id, posterHeroTag: posterHeroTag, titleHeroTag: titleHeroTag),
          onOpenSettings: _openSettings,
        );
        break;
      default:
        page = const SizedBox.shrink();
    }
    _pageCache[index] = page;
    _pageCacheSeed[index] = _refreshSeed;
    return page;
  }

  @override
  Widget build(BuildContext context) {
    final pages = List<Widget>.generate(_pageCache.length, (i) {
      if (i == _tab || _pageCache[i] != null) return _buildPage(i);
      return const SizedBox.shrink();
    });

    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      bottomNavigationBar: isWide ? null : TooltipVisibility(
        visible: false,
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _setTab,
          destinations: const [
            NavigationDestination(icon: Icon(LucideIcons.house), label: 'Inicio'),
            NavigationDestination(icon: Icon(LucideIcons.book), label: 'Manga'),
            NavigationDestination(icon: Icon(LucideIcons.compass), label: 'Explorar'),
            NavigationDestination(icon: Icon(LucideIcons.heart), label: 'Mis Listas'),
            NavigationDestination(icon: Icon(LucideIcons.user), label: 'Perfil'),
          ],
        ),
      ),
      body: isWide ? Stack(
        children: [
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                IndexedStack(index: _tab, children: pages),
                const MiniPlayer(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: Platform.isWindows ? 36 : 0,
            bottom: 0,
            width: 56,
            child: _FloatingSidebar(
              selectedIndex: _tab,
              onDestinationSelected: _setTab,
            ),
          ),
        ],
      ) : Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(index: _tab, children: pages),
          const MiniPlayer(),
        ],
      ),
    );
  }

  // Connectivity indicator removed from here, moved to header.
}

// ── CUSTOM FLOATING SIDEBAR ──
// A transparent sidebar with a pill indicator that slides from the left edge.
// The selected icon bounces on tap, and the indicator slides smoothly between items.
class _FloatingSidebar extends StatefulWidget {
  const _FloatingSidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<_FloatingSidebar> createState() => _FloatingSidebarState();
}

class _FloatingSidebarState extends State<_FloatingSidebar>
    with TickerProviderStateMixin {
  // Maps index -> bounce controller
  final Map<int, AnimationController> _bounceControllers = {};
  late int _previousIndex;

  static const _destinations = [
    (LucideIcons.house, 'Inicio'),
    (LucideIcons.book, 'Manga'),
    (LucideIcons.compass, 'Explorar'),
    (LucideIcons.heart, 'Mis Listas'),
    (LucideIcons.user, 'Perfil'),
  ];

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.selectedIndex;
    for (int i = 0; i < _destinations.length; i++) {
      _bounceControllers[i] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      );
    }
  }

  @override
  void didUpdateWidget(_FloatingSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previousIndex = oldWidget.selectedIndex;
      // Trigger bounce on newly selected icon
      final ctrl = _bounceControllers[widget.selectedIndex];
      if (ctrl != null) {
        ctrl.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _bounceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        const itemHeight = 56.0;
        final totalGroupHeight = _destinations.length * itemHeight;
        final startY = (totalHeight - totalGroupHeight) / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ── PILL INDICATOR (slides from left edge) ──
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              top: startY + widget.selectedIndex * itemHeight + (itemHeight - 44.0) / 2,
              left: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                height: 44,
                width: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(22),
                    bottomRight: Radius.circular(22),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                    right: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),

            // ── ICON BUTTONS ──
            Positioned(
              top: startY,
              left: 0,
              right: 0,
              height: totalGroupHeight,
              child: Column(
                children: List.generate(_destinations.length, (i) {
                  final (icon, label) = _destinations[i];
                  final isSelected = i == widget.selectedIndex;
                  final bounceCtrl = _bounceControllers[i]!;
                  final bounceAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(parent: bounceCtrl, curve: Curves.elasticOut),
                  );

                  return SizedBox(
                    height: itemHeight,
                    child: GestureDetector(
                      onTap: () {
                        widget.onDestinationSelected(i);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: bounceAnim,
                          builder: (context, child) {
                            // Bounce: scale from 1.0 → 1.35 → 1.0 using elastic
                            final scale = isSelected
                                ? 1.0 + (bounceAnim.value * 0.28 * (1.0 - bounceAnim.value) * 4.0).clamp(0.0, 0.28)
                                : 1.0;
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: Icon(
                            icon,
                            size: 22,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.55),
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.7),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: Colors.white70,
      mouseOver: const Color(0xFF2A2A2A),
      mouseDown: const Color(0xFF1E1E1E),
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );

    final closeButtonColors = WindowButtonColors(
      mouseOver: const Color(0xFFE81123),
      mouseDown: const Color(0xFFB90E1C),
      iconNormal: Colors.white70,
      iconMouseOver: Colors.white,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(colors: closeButtonColors),
      ],
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
