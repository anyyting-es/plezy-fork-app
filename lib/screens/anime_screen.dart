import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:plezy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';

import '../focus/focusable_action_bar.dart';
import '../focus/input_mode_tracker.dart';
import '../focus/key_event_utils.dart';
import '../services/apple_tv_remote_touch_service.dart';
import '../media/media_item.dart';
import '../media/media_hub.dart';
import '../widgets/optimized_media_image.dart' show blurArtwork;
import '../widgets/rasterized_gradient.dart';
import 'libraries/content_state_builder.dart';
import '../anime/providers/anime_provider.dart';
import '../widgets/hub_section.dart';
import '../widgets/app_menu.dart';
import '../widgets/clickable_cursor.dart';
import '../widgets/loading_indicator_box.dart';
import '../widgets/profile_switching_overlay.dart';
import 'profile/profile_switch_screen.dart';
import 'profile/profile_teardown.dart';
import 'settings/settings_screen.dart';
import '../profiles/active_profile_provider.dart';
import '../profiles/profile.dart';
import '../profiles/profile_activation.dart';
import '../profiles/profile_avatar.dart';
import '../watch_together/watch_together.dart';
import '../providers/companion_remote_provider.dart';
import '../widgets/companion_remote/remote_session_dialog.dart';
import 'companion_remote/mobile_remote_screen.dart';
import '../services/settings_service.dart';
import '../widgets/settings_builder.dart';
import '../widgets/tv_browse_rail.dart';
import '../widgets/tv_spotlight_background.dart';
import '../mixins/refreshable.dart';
import '../mixins/tab_visibility_aware.dart';
import '../i18n/strings.g.dart';
import '../utils/debouncer.dart';
import '../utils/dialogs.dart';
import '../utils/media_navigation_helper.dart';
import '../utils/layout_constants.dart';
import '../utils/platform_detector.dart';
import '../theme/mono_tokens.dart';
import 'main_screen.dart';

class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key});

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen>
    with Refreshable, FullRefreshable, TabVisibilityAware, FocusableTab, WidgetsBindingObserver {
  static const Duration _heroAutoScrollDuration = Duration(seconds: 8);
  static const Duration _indicatorUpdateInterval = Duration(milliseconds: 200);

  late final AnimeProvider _anime;
  int _seenLoadGeneration = 0;

  List<MediaItem> get _trending => _anime.trending;
  List<MediaHub> get _hubs => _anime.hubs;
  bool get _isLoading => _anime.isLoading;
  String? get _errorMessage {
    final raw = _anime.errorMessage;
    return raw == null ? null : t.errors.failedToLoad(context: 'Anime', error: raw);
  }

  bool _switchingProfile = false;
  final PageController _heroController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentHeroIndex = 0;
  Timer? _autoScrollTimer;
  Timer? _indicatorTimer;
  final ValueNotifier<double> _indicatorProgress = ValueNotifier(0.0);
  bool _isAutoScrollPaused = false;
  bool _heroFocusPausedAutoScroll = false;
  
  final ValueNotifier<MediaItem?> _spotlightItem = ValueNotifier(null);
  final Debouncer _spotlightDebouncer = Debouncer(const Duration(milliseconds: 150));
  bool _isTabVisible = true;

  bool _initialLoadComplete = false;
  bool _pendingTvBrowseRailFocus = false;

  final Map<String, GlobalKey<HubSectionState>> _hubKeysByIdentity = {};
  List<GlobalKey<HubSectionState>> _orderedHubKeys = const [];
  final _tvBrowseRailKey = GlobalKey<TvBrowseRailState>();

  late FocusNode _heroFocusNode;
  final _actionBarKey = GlobalKey<FocusableActionBarState>();
  final _userMenuKey = GlobalKey<AppMenuButtonState<String>>();

  String _hubIdentity(MediaHub hub) => hub.id;

  void _updateHubKeys() {
    final occurrences = <String, int>{};
    final liveIdentities = <String>{};
    final ordered = <GlobalKey<HubSectionState>>[];
    for (final hub in _hubs) {
      var identity = _hubIdentity(hub);
      final occurrence = occurrences.update(identity, (n) => n + 1, ifAbsent: () => 0);
      if (occurrence > 0) identity = '$identity#$occurrence';
      liveIdentities.add(identity);
      ordered.add(_hubKeysByIdentity.putIfAbsent(identity, GlobalKey<HubSectionState>.new));
    }
    _hubKeysByIdentity.removeWhere((identity, _) => !liveIdentities.contains(identity));
    _orderedHubKeys = ordered;
  }

  List<GlobalKey<HubSectionState>> get _allHubKeys => _orderedHubKeys;

  bool get _isHeroSectionVisible => _trending.isNotEmpty && context.settingsRead(SettingsService.showHeroSection);

  MediaItem? get _defaultSpotlightItem {
    if (_trending.isNotEmpty) return _trending.first;
    for (final hub in _hubs) {
      if (hub.items.isNotEmpty) return hub.items.first;
    }
    return null;
  }

  MediaItem? get _effectiveSpotlightItem => _spotlightItem.value ?? _defaultSpotlightItem;

  void _setSpotlightItem(MediaItem? item) {
    _spotlightDebouncer.run(() {
      if (mounted) _spotlightItem.value = item;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _heroFocusNode = FocusNode(debugLabel: 'anime_hero');
    _heroFocusNode.addListener(_onHeroFocusChanged);
    _anime = context.read<AnimeProvider>();
    _seenLoadGeneration = _anime.loadGeneration;
    _anime.addListener(_onAnimeChanged);
    _updateHubKeys();
    _startAutoScroll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anime.removeListener(_onAnimeChanged);
    _autoScrollTimer?.cancel();
    _indicatorTimer?.cancel();
    _spotlightDebouncer.dispose();
    _spotlightItem.dispose();
    _indicatorProgress.dispose();
    _heroController.dispose();
    _scrollController.dispose();
    _heroFocusNode.removeListener(_onHeroFocusChanged);
    _heroFocusNode.dispose();
    super.dispose();
  }

  void _onAnimeChanged() {
    if (!mounted) return;
    final generation = _anime.loadGeneration;
    final isNewLoad = generation != _seenLoadGeneration;
    _seenLoadGeneration = generation;
    final heroOutOfBounds = _currentHeroIndex >= _trending.length;

    if (isNewLoad || heroOutOfBounds || _anime.isLoading != _isLoading) {
      setState(() {
        if (isNewLoad || heroOutOfBounds) _currentHeroIndex = 0;
        _updateHubKeys();
      });
    }

    _applyPendingTvBrowseRailFocus();

    if ((isNewLoad || heroOutOfBounds) && _heroController.hasClients && _trending.isNotEmpty) {
      _heroController.jumpToPage(0);
    }

    if (!_initialLoadComplete) {
      if (_trending.isNotEmpty || _hubs.isNotEmpty) {
        _initialLoadComplete = true;
        if (PlatformDetector.isTV()) {
          _focusTvBrowseRailWhenReady();
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
            if (_heroFocusNode.canRequestFocus && _isHeroSectionVisible) {
              _heroFocusNode.requestFocus();
            }
          });
        }
      }
    }
  }

  void _onHeroFocusChanged() {
    if (!PlatformDetector.isTV()) return;
    if (_heroFocusNode.hasFocus) {
      _heroFocusPausedAutoScroll = true;
      _autoScrollTimer?.cancel();
      _stopIndicatorProgress();
      return;
    }
    if (_heroFocusPausedAutoScroll) {
      _heroFocusPausedAutoScroll = false;
      if (_isTabVisible && !_isAutoScrollPaused) _startAutoScroll();
    }
  }

  void _focusTopBoundary() {
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    if (PlatformDetector.isTV()) {
      _focusTopActions();
    } else if (_isHeroSectionVisible) {
      _heroFocusNode.requestFocus();
    } else {
      _focusTopActions();
    }
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _focusTopActions() {
    if (PlatformDetector.isTV()) {
      _navigateToSidebar();
    } else {
      _actionBarKey.currentState?.requestFocusOnFirst();
    }
  }

  void _focusTvBrowseRailWhenReady({bool immediate = false}) {
    if (!PlatformDetector.isTV()) return;
    final suppressSelect = _isSelectKeyPressed;
    if (!_isTabVisible || !(ModalRoute.of(context)?.isCurrent ?? false)) {
      _pendingTvBrowseRailFocus = false;
      return;
    }

    _pendingTvBrowseRailFocus = true;
    if (immediate && _tvBrowseRailKey.currentState != null) {
      _pendingTvBrowseRailFocus = false;
      _tvBrowseRailKey.currentState!.requestFocus();
      if (suppressSelect) _tvBrowseRailKey.currentState!.suppressSelectUntilKeyUp();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isTabVisible || !(ModalRoute.of(context)?.isCurrent ?? false)) {
        _pendingTvBrowseRailFocus = false;
        return;
      }
      final railState = _tvBrowseRailKey.currentState;
      if (railState == null) return;
      _pendingTvBrowseRailFocus = false;
      railState.requestFocus();
      if (suppressSelect) railState.suppressSelectUntilKeyUp();
    });
  }

  bool get _isSelectKeyPressed {
    return HardwareKeyboard.instance.logicalKeysPressed.any(
      (key) =>
          key == LogicalKeyboardKey.enter ||
          key.keyId == 0x0d ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.gameButtonA,
    );
  }

  void _applyPendingTvBrowseRailFocus() {
    if (_pendingTvBrowseRailFocus) _focusTvBrowseRailWhenReady();
  }

  void _navigateToSidebar() {
    MainScreenFocusScope.of(context, listen: false)?.focusSidebar();
  }

  @override
  void onTabHidden() {
    _isTabVisible = false;
    _pendingTvBrowseRailFocus = false;
    _autoScrollTimer?.cancel();
    _stopIndicatorProgress();
  }

  @override
  void onTabShown() {
    _isTabVisible = true;
    if (!_isAutoScrollPaused) _startAutoScroll();
  }

  @override
  void focusActiveTabIfReady() {
    if (PlatformDetector.isTV()) {
      _focusTvBrowseRailWhenReady();
      return;
    }
    _focusTopBoundary();
  }

  @override
  void refresh() {
    unawaited(_anime.refresh());
  }

  @override
  void fullRefresh() {
    unawaited(_anime.forceRefresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isTabVisible && !_isAutoScrollPaused) _startAutoScroll();
      if (Platform.isIOS || Platform.isAndroid) {
        unawaited(_anime.refresh());
      }
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      _autoScrollTimer?.cancel();
      _stopIndicatorProgress();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (PlatformDetector.isTV()) return;
    if (_isAutoScrollPaused) return;
    _startIndicatorProgress();
    _autoScrollTimer = Timer.periodic(_heroAutoScrollDuration, (_) {
      if (_trending.isEmpty || !_heroController.hasClients || _isAutoScrollPaused) return;
      if (_currentHeroIndex >= _trending.length) _currentHeroIndex = 0;
      final nextPage = (_currentHeroIndex + 1) % _trending.length;
      _heroController.animateToPage(nextPage, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isAutoScrollPaused) _startIndicatorProgress();
      });
    });
  }

  void _startIndicatorProgress() {
    if (!mounted) return;
    _indicatorTimer?.cancel();
    _indicatorProgress.value = 0.0;
    final totalSteps = _heroAutoScrollDuration.inMilliseconds ~/ _indicatorUpdateInterval.inMilliseconds;
    int step = 0;
    _indicatorTimer = Timer.periodic(_indicatorUpdateInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      step++;
      _indicatorProgress.value = (step / totalSteps).clamp(0.0, 1.0);
      if (step >= totalSteps) timer.cancel();
    });
  }

  void _stopIndicatorProgress() => _indicatorTimer?.cancel();

  void _pauseAutoScroll() {
    if (_isAutoScrollPaused) return;
    setState(() {
      _isAutoScrollPaused = true;
    });
    _autoScrollTimer?.cancel();
    _stopIndicatorProgress();
  }

  void _resumeAutoScroll() {
    if (!_isAutoScrollPaused) return;
    setState(() {
      _isAutoScrollPaused = false;
    });
    _startAutoScroll();
  }

  void _resetAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _startAutoScroll();
  }

  bool _handleVerticalNavigation(int hubIndex, bool isUp) {
    final keys = _allHubKeys;
    if (keys.isEmpty) return false;

    if (isUp && hubIndex == 0) {
      _focusTopBoundary();
      return true;
    }

    final targetIndex = isUp ? hubIndex - 1 : hubIndex + 1;
    if (targetIndex < 0 || targetIndex >= keys.length) return true;

    final targetState = keys[targetIndex].currentState;
    if (targetState != null) {
      targetState.requestFocusFromMemory();
      return true;
    }

    return false;
  }

  KeyEventResult _handleHeroKeyEvent(FocusNode node, KeyEvent event) {
    final backResult = handleBackKeyAction(event, _navigateToSidebar);
    if (backResult != KeyEventResult.ignored) return backResult;

    return dpadKeyHandler(
      onDown: () {
        final keys = _allHubKeys;
        if (keys.isNotEmpty) keys.first.currentState?.requestFocusFromMemory();
      },
      onUp: _focusTopActions,
      onLeft: () {
        if (_currentHeroIndex > 0) {
          _heroController.previousPage(duration: tokens(context).slow, curve: Curves.easeInOut);
        } else {
          _navigateToSidebar();
        }
      },
      onRight: () {
        if (_currentHeroIndex < _trending.length - 1) {
          _heroController.nextPage(duration: tokens(context).slow, curve: Curves.easeInOut);
        }
      },
      onSelect: () {
        if (_trending.isNotEmpty && _currentHeroIndex < _trending.length) {
          unawaited(navigateToMediaItem(context, _trending[_currentHeroIndex]));
        }
      },
    )(node, event);
  }

  List<double> _getVisibleDotRange() {
    final total = _trending.length;
    final current = _currentHeroIndex;
    if (total <= 5) return [for (int i = 0; i < total; i++) i.toDouble()];
    if (current <= 2) return [0, 1, 2, 3, 4];
    if (current >= total - 3) return [for (int i = total - 5; i < total; i++) i.toDouble()];
    return [for (int i = current - 2; i <= current + 2; i++) i.toDouble()];
  }

  double _getDotSize(int index, int start, int end) {
    if (index == _currentHeroIndex) return 8.0;
    if (index == start && start > 0) return 4.0;
    if (index == end && end < _trending.length - 1) return 4.0;
    if (index == start + 1 && start > 0) return 6.0;
    if (index == end - 1 && end < _trending.length - 1) return 6.0;
    return 8.0;
  }

  List<MediaHub> get _tvBrowseHubs => _hubs;

  @override
  Widget build(BuildContext context) {
    return SettingsBuilder(
      prefs: const [
        SettingsService.showServerNameOnHubs,
        SettingsService.showHeroSection,
        SettingsService.hideSpoilers,
        SettingsService.libraryDensity,
        SettingsService.episodePosterMode,
        SettingsService.tvFullCardLayout,
      ],
      builder: (context) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final svc = SettingsService.instance;
    final showHeroSection = svc.read(SettingsService.showHeroSection);

    if (PlatformDetector.isTV()) {
      return _buildTvContent(context);
    }

    final showServerNameOnHubs = svc.read(SettingsService.showServerNameOnHubs);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              Builder(
                builder: (context) {
                  if (_trending.isNotEmpty && showHeroSection) {
                    return _buildHeroSection();
                  }
                  return SliverToBoxAdapter(
                    child: SizedBox(height: kToolbarHeight + MediaQuery.paddingOf(context).top + 16),
                  );
                },
              ),
              if (_isLoading) LoadingIndicatorBox.sliver,
              if (_errorMessage != null) SliverErrorState(message: _errorMessage!, onRetry: _anime.forceRefresh),
              if (!_isLoading && _errorMessage == null) ...[
                for (int i = 0; i < _hubs.length; i++)
                  SliverToBoxAdapter(
                    child: HubSection(
                      key: i < _orderedHubKeys.length ? _orderedHubKeys[i] : null,
                      hub: _hubs[i],
                      icon: Symbols.animation_rounded,
                      showServerName: showServerNameOnHubs,
                      onRefresh: (id) => _anime.refresh(),
                      onRemoveFromContinueWatching: null,
                      onVerticalNavigation: (isUp) => _handleVerticalNavigation(i, isUp),
                      onNavigateUp: i == 0 ? _focusTopBoundary : null,
                      onNavigateToSidebar: _navigateToSidebar,
                    ),
                  ),

                if (_trending.isEmpty && _hubs.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const AppIcon(Symbols.animation_rounded, fill: 1, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(t.discover.noContentAvailable),
                        ],
                      ),
                    ),
                  ),

                SliverToBoxAdapter(child: SizedBox(height: 24 + bottomPadding)),
              ],
            ],
          ),
          Positioned(top: 0, left: 0, right: 0, child: ExcludeFocusTraversal(child: _buildOverlaidAppBar())),
          if (_switchingProfile) const ProfileSwitchingOverlay(),
        ],
      ),
    );
  }

  TvBrowseRail? _tvBrowseRailWidget;
  (List<MediaHub>, bool)? _tvBrowseRailWidgetKey;

  Widget _cachedTvBrowseRail(List<MediaHub> browseHubs, {required bool showServerName}) {
    final key = (browseHubs, showServerName);
    if (_tvBrowseRailWidget != null && key == _tvBrowseRailWidgetKey) return _tvBrowseRailWidget!;
    _tvBrowseRailWidgetKey = key;
    return _tvBrowseRailWidget = TvBrowseRail(
      key: _tvBrowseRailKey,
      hubs: browseHubs,
      showServerName: showServerName,
      iconForHub: (hub, _) => Symbols.animation_rounded,
      onFocusedItemChanged: _setSpotlightItem,
      onRefresh: (id) => _anime.refresh(),
      onRemoveFromContinueWatching: null,
      isContinueWatchingHub: (hub) => false,
      usesContinueWatchingAction: (hub) => false,
      loadMoreItems: (hub) => Future.value(hub.items),
      onNavigateUp: _focusTopActions,
      onNavigateToSidebar: _navigateToSidebar,
      tallPosterScale: TvBrowseRailLayout.compactTallPosterScale,
      selectSuppressionGestureSignal: PlatformDetector.isAppleTV()
          ? AppleTvRemoteTouchService.instance.touchActiveListenable
          : null,
    );
  }

  Widget _buildTvContent(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final svc = SettingsService.instance;
    final hideSpoilers = svc.read(SettingsService.hideSpoilers);
    final showServerNameOnHubs = svc.read(SettingsService.showServerNameOnHubs);
    final browseHubs = _tvBrowseHubs;
    final scale = TvLayoutConstants.scaleForSize(size);
    final railSize = MainScreenFocusScope.foregroundSizeOf(context);
    final fullBleedWidth = MainScreenFocusScope.fullBleedWidthOf(context);
    
    final railHeight = browseHubs.isEmpty
        ? 0.0
        : TvBrowseRailLayout.estimateHeight(
            size: railSize,
            hubs: browseHubs,
            density: svc.read(SettingsService.libraryDensity),
            episodePosterMode: svc.read(SettingsService.episodePosterMode),
            fullCardLayout: svc.read(SettingsService.tvFullCardLayout),
            tallPosterScale: TvBrowseRailLayout.compactTallPosterScale,
          );
    final spotlightTop = (size.height * 0.075).clamp(64.0 * scale, 120.0 * scale).toDouble();
    final minimumSpotlightBottom = railHeight + (8 * scale);
    final baseSpotlightBottom = (size.height * 0.48).clamp(160.0, 820.0).toDouble();
    final desiredSpotlightBottom = minimumSpotlightBottom > baseSpotlightBottom
        ? minimumSpotlightBottom
        : baseSpotlightBottom;
    final maxSpotlightBottom = (size.height - spotlightTop - (96 * scale)).clamp(0.0, double.infinity).toDouble();
    final spotlightBottom = desiredSpotlightBottom > maxSpotlightBottom ? maxSpotlightBottom : desiredSpotlightBottom;
    final spotlightLeft = (24 * scale).clamp(18.0, 40.0).toDouble();

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Builder(
            builder: (context) {
              final foregroundLeft = MainScreenFocusScope.foregroundLeftOf(context);
              return SideNavigationBleedBuilder(
                targetBleed: foregroundLeft,
                child: ValueListenableBuilder<MediaItem?>(
                  valueListenable: _spotlightItem,
                  builder: (context, _, _) {
                    final spotlight = _effectiveSpotlightItem;
                    return TvSpotlightBackground(
                      item: spotlight,
                      client: null,
                      hideSpoilers: hideSpoilers,
                      contentTop: spotlightTop,
                      contentBottom: spotlightBottom,
                      contentLeft: spotlightLeft + foregroundLeft,
                      compact: true,
                      showPrimaryAction: false,
                    );
                  },
                ),
                builder: (context, animatedBleed, child) =>
                    Positioned(top: 0, bottom: 0, left: -animatedBleed, width: fullBleedWidth, child: child!),
              );
            },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(Symbols.error_outline_rounded, fill: 1, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _anime.forceRefresh, child: Text(t.common.retry)),
                ],
              ),
            ),
          if (!_isLoading && _errorMessage == null && browseHubs.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppIcon(Symbols.animation_rounded, fill: 1, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(t.discover.noContentAvailable),
                ],
              ),
            ),
          if (browseHubs.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _cachedTvBrowseRail(browseHubs, showServerName: showServerNameOnHubs),
            ),
          Builder(
            builder: (context) => SideNavigationBleedBuilder(
              targetBleed: MainScreenFocusScope.sideNavigationBleedOf(context),
              child: ExcludeFocusTraversal(child: _buildOverlaidAppBar()),
              builder: (context, animatedBleed, child) =>
                  Positioned(top: 0, left: -animatedBleed, width: fullBleedWidth, child: child!),
            ),
          ),
          if (_switchingProfile) const ProfileSwitchingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final useSideNav = PlatformDetector.shouldUseSideNavigation(context);
    final isTv = PlatformDetector.isTV();
    final heroHeight = isTv
        ? MediaQuery.sizeOf(context).height * 0.82
        : useSideNav
        ? MediaQuery.sizeOf(context).height * 0.75
        : 500 + statusBarHeight;
    return SliverToBoxAdapter(
      child: Focus(
        focusNode: _heroFocusNode,
        onKeyEvent: _handleHeroKeyEvent,
        child: SizedBox(
          height: heroHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PageView.builder(
                controller: _heroController,
                itemCount: _trending.length,
                onPageChanged: (index) {
                  if (index >= 0 && index < _trending.length) {
                    setState(() {
                      _currentHeroIndex = index;
                    });
                    _resetAutoScrollTimer();
                  }
                },
                itemBuilder: (context, index) {
                  return _buildHeroItem(_trending[index], heroHeight);
                },
              ),
              if (!InputModeTracker.isKeyboardMode(context))
                Positioned(
                  bottom: 16,
                  left: -26,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClickableCursor(
                        child: GestureDetector(
                          onTap: () {
                            if (_isAutoScrollPaused) {
                              _resumeAutoScroll();
                            } else {
                              _pauseAutoScroll();
                            }
                          },
                          child: AppIcon(
                            _isAutoScrollPaused ? Symbols.play_arrow_rounded : Symbols.pause_rounded,
                            fill: 1,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 18,
                            semanticLabel: '${_isAutoScrollPaused ? t.common.play : t.common.pause} auto-scroll',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...() {
                        final range = _getVisibleDotRange();
                        final start = range.isNotEmpty ? range.first.toInt() : 0;
                        final end = range.isNotEmpty ? range.last.toInt() : 0;
                        return List.generate(range.length, (i) {
                          final index = start + i;
                          final isActive = _currentHeroIndex == index;
                          final dotSize = _getDotSize(index, start, end);

                          return isActive
                              ? ValueListenableBuilder<double>(
                                  valueListenable: _indicatorProgress,
                                  builder: (context, progress, child) {
                                    final maxWidth = dotSize * 3;
                                    final fillWidth = dotSize + ((maxWidth - dotSize) * progress);
                                    final onSurface = Theme.of(context).colorScheme.onSurface;
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      width: maxWidth,
                                      height: dotSize,
                                      decoration: BoxDecoration(
                                        color: onSurface.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(dotSize / 2),
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          width: fillWidth,
                                          height: dotSize,
                                          decoration: BoxDecoration(
                                            color: onSurface,
                                            borderRadius: BorderRadius.circular(dotSize / 2),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : AnimatedContainer(
                                  duration: tokens(context).slow,
                                  curve: Curves.easeInOut,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: dotSize,
                                  height: dotSize,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(dotSize / 2),
                                  ),
                                );
                        });
                      }(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroItem(MediaItem heroItem, double heroHeight) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLargeScreen = ScreenBreakpoints.isWideTabletOrLarger(screenWidth);
    final isTv = PlatformDetector.isTV();
    final alignLeft = isTv || isLargeScreen;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final heroTitleStyle = theme.textTheme.displaySmall?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.bold,
      fontSize: isTv ? 52 : null,
      shadows: [Shadow(color: colorScheme.surface.withValues(alpha: 0.8), blurRadius: 8)],
    );

    final contentTypeLabel = 'Anime';
    final heroLabel = heroItem.title ?? 'Anime';

    return Semantics(
      label: heroLabel,
      button: true,
      hint: t.accessibility.tapToPlay,
      child: ClickableCursor(
        child: GestureDetector(
          onTap: () {
            unawaited(navigateToMediaItem(context, heroItem));
          },
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              if (heroItem.artPath != null)
                ClipRect(
                  child: AnimatedBuilder(
                    animation: _scrollController,
                    builder: (context, child) {
                      final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
                      return Transform.translate(offset: Offset(0, scrollOffset * 0.3), child: child);
                    },
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 1.0 + (0.1 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: blurArtwork(
                        CachedNetworkImage(
                          imageUrl: heroItem.artPath!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                          errorBuilder: (context, error, stackTrace) =>
                              ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                        ),
                      ),
                    ),
                  ),
                )
              else
                ColoredBox(color: colorScheme.surfaceContainerHighest),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: -4,
                child: IgnorePointer(
                  child: Builder(
                    builder: (context) {
                      final bgColor = Theme.of(context).scaffoldBackgroundColor;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, bgColor.withValues(alpha: 0.9), bgColor],
                            stops: isTv ? const [0.25, 0.78, 1.0] : const [0.5, 0.85, 1.0],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                bottom: isTv ? 88 : isLargeScreen ? 80 : 50,
                left: 0,
                right: isTv ? screenWidth * 0.36 : isLargeScreen ? 200 : 0,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTv ? TvLayoutConstants.horizontalInset : isLargeScreen ? 40 : 24,
                  ),
                  child: Align(
                    alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTv ? TvLayoutConstants.heroContentMaxWidth : double.infinity,
                      ),
                      child: Column(
                        crossAxisAlignment: alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            heroItem.title ?? '',
                            style: heroTitleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: alignLeft ? TextAlign.left : TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: alignLeft ? WrapAlignment.start : WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: colorScheme.outlineVariant),
                                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                                ),
                                child: Text(
                                  contentTypeLabel,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (heroItem.year != null)
                                Text(
                                  heroItem.year!.toString(),
                                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                          if (heroItem.summary != null && heroItem.summary!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              heroItem.summary!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                shadows: [Shadow(color: colorScheme.surface.withValues(alpha: 0.8), blurRadius: 4)],
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: alignLeft ? TextAlign.left : TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlaidAppBar() {
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final colorScheme = Theme.of(context).colorScheme;
    final overlayColor = colorScheme.brightness == Brightness.dark ? Colors.black : colorScheme.surface;
    final foregroundColor = colorScheme.onSurface;

    return RasterizedGradient(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          overlayColor.withValues(alpha: 0.7),
          overlayColor.withValues(alpha: 0.5),
          overlayColor.withValues(alpha: 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ),
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight, left: 16, right: 16, bottom: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              if (!PlatformDetector.isTV())
                Text(
                  'Anime',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: foregroundColor, fontWeight: FontWeight.bold),
                ),
              const Spacer(),
              Consumer2<WatchTogetherProvider, CompanionRemoteProvider>(
                builder: (context, watchTogether, companionRemote, _) {
                  final isDesktop = PlatformDetector.shouldActAsRemoteHost(context);

                  return FocusableActionBar(
                    key: _actionBarKey,
                    onNavigateLeft: _navigateToSidebar,
                    onNavigateDown: _focusContentFromAppBar,
                    actions: [
                      FocusableAction(
                        icon: Symbols.refresh_rounded,
                        iconColor: foregroundColor,
                        onPressed: _anime.forceRefresh,
                      ),
                      FocusableAction(
                        onPressed: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchTogetherScreen())),
                        child: Stack(
                          children: [
                            IconButton(
                              icon: AppIcon(
                                Symbols.group_rounded,
                                fill: watchTogether.isInSession ? 1 : 0,
                                color: watchTogether.isInSession ? colorScheme.primary : foregroundColor,
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const WatchTogetherScreen()),
                              ),
                              tooltip: t.watchTogether.title,
                            ),
                            if (watchTogether.isInSession && watchTogether.participantCount > 1)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                                  ),
                                  child: Text(
                                    '${watchTogether.participantCount}',
                                    style: TextStyle(color: colorScheme.onPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      FocusableAction(
                        onPressed: () {
                          if (isDesktop) {
                            RemoteSessionDialog.show(context);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MobileRemoteScreen()),
                            );
                          }
                        },
                        child: Stack(
                          children: [
                            IconButton(
                              icon: AppIcon(
                                Symbols.phone_android_rounded,
                                fill: companionRemote.isConnected ? 1 : 0,
                                color: companionRemote.isConnected ? colorScheme.primary : foregroundColor,
                              ),
                              onPressed: () {
                                if (isDesktop) {
                                  RemoteSessionDialog.show(context);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const MobileRemoteScreen()),
                                  );
                                }
                              },
                              tooltip: t.companionRemote.title,
                            ),
                            if (companionRemote.isConnected)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.fromBorderSide(BorderSide(color: foregroundColor, width: 1)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _buildUserMenuAction(context),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _focusContentFromAppBar() {
    if (_trending.isNotEmpty) {
      _heroFocusNode.requestFocus();
    } else if (_orderedHubKeys.isNotEmpty) {
      _orderedHubKeys.first.currentState?.requestFocusFromMemory();
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showConfirmDialog(
      context,
      title: t.common.logout,
      message: t.messages.logoutConfirm,
      confirmText: t.common.logout,
      isDestructive: true,
    );

    if (confirm && mounted) {
      await logoutAllProfiles(context);
    }
  }

  void _handleSwitchProfile(BuildContext context) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (context) => const ProfileSwitchScreen()));
  }

  void _handleOpenSettings(BuildContext context) {
    final mainScope = MainScreenFocusScope.of(context, listen: false);
    if (mainScope != null) {
      mainScope.openSettings?.call();
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  FocusableAction _buildUserMenuAction(BuildContext context) {
    final activeProvider = context.watch<ActiveProfileProvider>();
    final active = activeProvider.active;
    final profiles = activeProvider.profiles;

    return FocusableAction(
      onPressed: _switchingProfile ? null : () => _userMenuKey.currentState?.showButtonMenu(focusFirstItem: true),
      child: AppMenuButton<String>(
        key: _userMenuKey,
        enabled: !_switchingProfile,
        icon: active != null
            ? ProfileAvatar(profile: active, size: 32)
            : const AppIcon(Symbols.account_circle_rounded, fill: 1, size: 32, color: Colors.white),
        tooltip: t.profiles.sectionTitle,
        anchorAlignment: AppMenuAnchorAlignment.end,
        onSelected: (value) => unawaited(_handleUserMenuAction(context, value)),
        entriesBuilder: (context) => _userMenuItems(context, activeProfile: active, profiles: profiles),
      ),
    );
  }

  List<AppMenuEntry<String>> _userMenuItems(
    BuildContext context, {
    required Profile? activeProfile,
    required List<Profile> profiles,
  }) {
    final theme = Theme.of(context);
    final switchable = profiles.where((p) => p.id != activeProfile?.id).toList();

    return [
      for (final p in switchable)
        AppMenuItem<String>(
          value: 'profile:${p.id}',
          leading: ProfileAvatar(profile: p, size: 24),
          label: p.displayName,
          trailing: p.isPinProtected
              ? AppIcon(Symbols.lock_rounded, fill: 1, size: 14, color: theme.colorScheme.onSurfaceVariant)
              : null,
        ),
      if (switchable.isNotEmpty) const AppMenuDivider(),
      AppMenuItem<String>(value: 'manage_profiles', icon: Symbols.group_rounded, label: t.profiles.sectionTitle),
      AppMenuItem<String>(value: 'settings', icon: Symbols.settings_rounded, label: t.common.settings),
      AppMenuItem<String>(value: 'logout', icon: Symbols.logout_rounded, label: t.common.logout),
    ];
  }

  Future<void> _handleUserMenuAction(BuildContext context, String value) async {
    if (_switchingProfile) return;
    if (value == 'logout') {
      unawaited(_handleLogout());
      return;
    }
    if (value == 'manage_profiles') {
      _handleSwitchProfile(context);
      return;
    }
    if (value == 'settings') {
      _handleOpenSettings(context);
      return;
    }
    if (value.startsWith('profile:')) {
      final id = value.substring('profile:'.length);
      final active = context.read<ActiveProfileProvider>();
      final target = active.profiles.where((p) => p.id == id).firstOrNull;
      if (target == null) return;
      await _switchProfileFromMenu(target);
    }
  }

  Future<void> _switchProfileFromMenu(Profile profile) async {
    if (_switchingProfile) return;
    setState(() => _switchingProfile = true);
    try {
      await switchProfileFromUi(context, profile);
    } finally {
      if (mounted) {
        setState(() => _switchingProfile = false);
      }
    }
  }
}
