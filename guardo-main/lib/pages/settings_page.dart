import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/app_models.dart';
import '../services/app_shell_controller.dart';
import '../services/storage_service.dart';
import 'extensions/extensions_page.dart';
import 'player_test_page.dart';
import 'settings/theme_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.onSettingsSaved});

  final VoidCallback onSettingsSaved;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _storage = StorageService.instance;
  static const _paletteOptions = <(String, String)>[
    ('violet', 'Violeta'),
    ('blue', 'Azul'),
    ('green', 'Verde'),
    ('amber', 'Ámbar'),
    ('rose', 'Rosa'),
    ('indigo', 'Índigo'),
    ('orange', 'Naranja'),
    ('teal', 'Teal'),
    ('purple', 'Púrpura'),
    ('red', 'Rojo'),
    ('cyan', 'Cian'),
    ('lime', 'Limón'),
    ('deepOrange', 'Naranja Oscuro'),
  ];

  AppSettings? _settings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _storage.getAppSettings();
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _saveInternal(AppSettings next) async {
    _settings = next;
    setState(() => _saving = true);
    await _storage.saveAppSettings(next);
    if (!mounted) return;
    setState(() => _saving = false);
    AppShellController.updateUiTheme(UiThemeSettings(
      palette: next.themePalette,
      themeMode: next.themeMode,
      oledBlack: next.oledBlack,
    ));
    widget.onSettingsSaved();
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) return const Center(child: CircularProgressIndicator());
    final settings = _settings!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Ajustes', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: colorScheme.surface,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionHeader('DISEÑO'),
                _settingsGroup(children: [
                  _settingsItem(
                    icon: LucideIcons.palette,
                    title: 'Tema',
                    subtitle: 'Modo oscuro/claro, OLED, Paleta',
                    heroTag: 'theme_title',
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ThemeSettingsPage(settings: settings, onSaved: (s) => _saveInternal(s)),
                    )),
                  ),
                  _settingsItem(
                    icon: LucideIcons.layoutDashboard,
                    title: 'Secciones de Inicio',
                    heroTag: 'home_sections_title',
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _HomeSectionsSettings(settings: settings, onSaved: (s) => _saveInternal(s)),
                    )),
                  ),
                ]),
                _sectionHeader('REPRODUCCIÓN'),
                _settingsGroup(children: [
                  ListTile(
                    leading: const Icon(LucideIcons.play, size: 22),
                    title: const Text('Reproductor Predeterminado', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text(settings.preferredPlayer == 'mpv' ? 'MPV (Alto rendimiento)' : 'ExoPlayer (Nativo / Alternativo)', style: const TextStyle(fontSize: 13)),
                    trailing: DropdownButton<String>(
                      value: settings.preferredPlayer,
                      underline: const SizedBox(),
                      onChanged: (val) {
                        if (val != null) {
                          _saveInternal(settings.copyWith(preferredPlayer: val));
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'mpv',
                          child: Text('MPV'),
                        ),
                        DropdownMenuItem(
                          value: 'exoplayer',
                          child: Text('ExoPlayer'),
                        ),
                      ],
                    ),
                  ),
                ]),

                _sectionHeader('EXTENSIONES'),
                _settingsGroup(children: [
                  _settingsItem(
                    icon: LucideIcons.blocks,
                    title: 'Extensiones',
                    heroTag: 'extensions_title',
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ExtensionsPage(),
                    )),
                  ),
                ]),
                _sectionHeader('PRUEBAS'),
                _settingsGroup(children: [
                  _settingsItem(
                    icon: LucideIcons.play,
                    title: 'Probador de Reproductor',
                    subtitle: 'Probar magnet o stream directo',
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const PlayerTestPage(),
                    )),
                  ),
                ]),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.2)),
  );

  Widget _settingsGroup({required List<Widget> children}) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Column(children: children),
  );

  Widget _settingsItem({required IconData icon, required String title, String? subtitle, String? heroTag, required VoidCallback onTap}) {
    Widget titleWidget = Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15));
    if (heroTag != null) {
      titleWidget = Hero(
        tag: heroTag,
        flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final t = animation.value;
              return Material(
                type: MaterialType.transparency,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: TextStyle.lerp(
                      const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      t,
                    ),
                  ),
                ),
              );
            },
          );
        },
        child: Material(type: MaterialType.transparency, child: titleWidget),
      );
    }
    return ListTile(
      leading: Icon(icon, size: 22),
      title: titleWidget,
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 13)) : null,
      trailing: const Icon(LucideIcons.chevronRight, size: 18),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ─── Home Sections Config ───────────────────────────────────────

class _HomeSectionsSettings extends StatefulWidget {
  final AppSettings settings;
  final Function(AppSettings) onSaved;
  const _HomeSectionsSettings({required this.settings, required this.onSaved});

  @override
  State<_HomeSectionsSettings> createState() => _HomeSectionsSettingsState();
}

class _HomeSectionsSettingsState extends State<_HomeSectionsSettings> {
  late Map<String, bool> _anime = Map.from(widget.settings.homeAnimeSections);
  late Map<String, bool> _manga = Map.from(widget.settings.homeMangaSections);

  static const _animeLabels = {
    'trending': 'Tendencias',
    'popular': 'Más Populares',
    'all_time': 'Mejor Valorados',
    'romance': 'Romance',
    'action': 'Acción',
    'comedy': 'Comedia',
    'fantasy': 'Fantasía',
    'upcoming': 'Próximamente',
  };

  static const _mangaLabels = {
    'trending': 'Tendencias Manga',
    'popular': 'Más Populares',
    'manhwa': 'Manhwa',
    'action': 'Acción',
    'romance': 'Romance',
    'fantasy': 'Fantasía',
    'comedy': 'Comedia',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'home_sections_title',
          child: Material(
            type: MaterialType.transparency,
            child: const Text('Secciones de Inicio'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('ANIME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ..._animeLabels.entries.map((e) => SwitchListTile(
            title: Text(e.value),
            value: _anime[e.key] ?? true,
            onChanged: (v) {
              setState(() => _anime[e.key] = v);
              widget.onSaved(widget.settings.copyWith(homeAnimeSections: Map.from(_anime)));
            },
          )),
          const SizedBox(height: 16),
          const Text('MANGA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ..._mangaLabels.entries.map((e) => SwitchListTile(
            title: Text(e.value),
            value: _manga[e.key] ?? true,
            onChanged: (v) {
              setState(() => _manga[e.key] = v);
              widget.onSaved(widget.settings.copyWith(homeMangaSections: Map.from(_manga)));
            },
          )),
        ],
      ),
    );
  }
}
