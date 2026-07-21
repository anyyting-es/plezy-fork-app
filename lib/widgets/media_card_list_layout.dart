import '../services/settings_service.dart' show LibraryDensity;

/// Shared sizing math for media cards rendered in list mode.
class MediaCardListLayout {
  static const double padding = 8.0;

  static double basePosterWidth(int density) {
    return 70 + LibraryDensity.factor(density) * 50;
  }

  static double posterWidth({required int density, required bool usesWideAspectRatio}) {
    final base = basePosterWidth(density);
    return usesWideAspectRatio ? base * 1.6 : base;
  }

  static double posterHeight({required int density, required bool usesWideAspectRatio}) {
    final base = basePosterWidth(density);
    return usesWideAspectRatio ? base * 0.9 : base * 1.5;
  }

  static double estimatedRowHeight({required int density, required bool usesWideAspectRatio}) {
    final poster = posterHeight(density: density, usesWideAspectRatio: usesWideAspectRatio);
    return poster + padding * 2;
  }
}
