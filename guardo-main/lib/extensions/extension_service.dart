import 'package:flutter/foundation.dart';
import 'core/extension_base.dart';
import 'core/animeav1_dart_extension.dart';
import 'core/animetosho_extension.dart';

/// Tipos de extensión por categoría
enum ExtensionCategory { online, torrent, manga }

class ExtensionService {
  static final ExtensionService _instance = ExtensionService._internal();
  factory ExtensionService() => _instance;
  ExtensionService._internal();

  final List<ExtensionBase> _extensions = [];
  List<ExtensionBase> get extensions => List.unmodifiable(_extensions);

  /// Extensiones de streaming online
  List<ExtensionBase> get onlineExtensions =>
      _extensions.where((e) => e.manifest.type == 'anime').toList();

  /// Extensiones de torrent
  List<ExtensionBase> get torrentExtensions =>
      _extensions.where((e) => e.manifest.type == 'torrent').toList();

  /// Extensiones de manga
  List<ExtensionBase> get mangaExtensions =>
      _extensions.where((e) => e.manifest.type == 'manga').toList();

  bool isInstalled(String id) => _extensions.any((e) => e.manifest.id == id);

  ExtensionBase? getById(String id) {
    try {
      return _extensions.firstWhere((e) => e.manifest.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Compatibility stubs (extensions are now built-in Dart classes) ──

  /// No-op: built-in extensions cannot be installed from marketplace
  Future<void> installFromMarketplace(dynamic manifest) async {
    debugPrint('[ExtensionService] installFromMarketplace: built-in extensions only (no-op)');
  }

  /// No-op: built-in extensions cannot be uninstalled
  Future<void> uninstallExtension(String id) async {
    debugPrint('[ExtensionService] uninstallExtension: built-in extensions only (no-op)');
  }

  /// Reloads built-in extensions (equivalent to re-initializing)
  Future<void> reloadExtension(String id) async {
    final ext = getById(id);
    if (ext != null) {
      try {
        await ext.initialize();
        debugPrint('[ExtensionService] reloadExtension: re-initialized $id');
      } catch (e) {
        debugPrint('[ExtensionService] reloadExtension error: $e');
      }
    }
  }

  /// No-op: no backend extensions to load
  Future<void> loadAllBackendExtensions() async {
    debugPrint('[ExtensionService] loadAllBackendExtensions: built-in extensions only (no-op)');
  }



  /// Carga todas las extensiones integradas
  Future<void> loadBuiltInExtensions() async {
    _extensions.clear();

    // ─── Online (streaming) ───────────────────────────────────────
    final animeAv1 = AnimeAv1DartExtension();
    await animeAv1.initialize();
    _extensions.add(animeAv1);

    // ─── Torrent ──────────────────────────────────────────────────
    final animeTosho = AnimeToshoExtension();
    await animeTosho.initialize();
    _extensions.add(animeTosho);

    debugPrint(
      '[ExtensionService] Loaded extensions: '
      '${_extensions.map((e) => "${e.manifest.name} (${e.manifest.type})").toList()}',
    );
  }

  /// Acceso directo a la extensión AnimeTosho
  AnimeToshoExtension? get animeTosho =>
      getById('animetosho') as AnimeToshoExtension?;

  /// Acceso directo a AnimeAv1
  AnimeAv1DartExtension? get animeAv1 =>
      getById('animeav1_dart') as AnimeAv1DartExtension?;

  void dispose() {
    for (var ext in _extensions) {
      ext.dispose();
    }
    _extensions.clear();
  }
}
