import 'package:flutter/foundation.dart';

class UiThemeSettings {
  const UiThemeSettings({
    this.palette = 'violet',
    this.themeMode = 'dark',
    this.oledBlack = false,
  });

  final String palette;
  final String themeMode;
  final bool oledBlack;

  UiThemeSettings copyWith({
    String? palette,
    String? themeMode,
    bool? oledBlack,
  }) {
    return UiThemeSettings(
      palette: palette ?? this.palette,
      themeMode: themeMode ?? this.themeMode,
      oledBlack: oledBlack ?? this.oledBlack,
    );
  }
}

class AppShellController {
  AppShellController._();

  static final ValueNotifier<int?> _tabRequest = ValueNotifier<int?>(null);

  static ValueListenable<int?> get tabRequest => _tabRequest;

  static void requestTab(int tab) {
    _tabRequest.value = tab;
  }

  static void clearRequest() {
    _tabRequest.value = null;
  }

  /// Whether a video player is currently in fullscreen mode.
  /// When true, the window title-bar buttons (min/max/close) are hidden.
  static final ValueNotifier<bool> isPlayerFullscreen = ValueNotifier<bool>(false);

  /// App theme settings that can be changed from Settings page.
  static final ValueNotifier<UiThemeSettings> uiThemeSettings =
      ValueNotifier<UiThemeSettings>(const UiThemeSettings());

  static void updateUiTheme(UiThemeSettings settings) {
    uiThemeSettings.value = settings;
  }

  /// Connectivity state
  static final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> showOfflineToast = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> showBackOnline = ValueNotifier<bool>(false);

  /// Global App Mode (Anime/Manga)
  static final ValueNotifier<bool> isMangaMode = ValueNotifier<bool>(false);

  /// Global Search State
  static final ValueNotifier<bool> isSearching = ValueNotifier<bool>(false);
}
