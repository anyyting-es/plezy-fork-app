import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/app_models.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key, required this.settings, required this.onSaved});

  final AppSettings settings;
  final Function(AppSettings) onSaved;

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  late AppSettings _settings;

  static const _paletteOptions = <(String, String, Color)>[
    ('violet', 'Violeta', Colors.deepPurple),
    ('blue', 'Azul', Colors.blue),
    ('green', 'Verde', Colors.green),
    ('amber', 'Ámbar', Colors.amber),
    ('rose', 'Rosa', Colors.pink),
    ('indigo', 'Índigo', Colors.indigo),
    ('orange', 'Naranja', Colors.orange),
    ('teal', 'Teal', Colors.teal),
    ('purple', 'Púrpura', Colors.purple),
    ('red', 'Rojo', Colors.red),
    ('cyan', 'Cian', Colors.cyan),
    ('lime', 'Limón', Colors.lime),
    ('deepOrange', 'Naranja Oscuro', Colors.deepOrange),
  ];

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _updateSettings(AppSettings newSettings) {
    setState(() => _settings = newSettings);
    widget.onSaved(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Hero(
          tag: 'theme_title',
          child: Material(
            type: MaterialType.transparency,
            child: const Text('Tema', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ),
        ),
        backgroundColor: colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Smartphone Mockup Preview
          Center(
            child: Container(
              width: 200,
              height: 400,
              decoration: BoxDecoration(
                color: _settings.oledBlack && (_settings.themeMode == 'dark' || (_settings.themeMode == 'system' && Theme.of(context).brightness == Brightness.dark)) ? Colors.black : colorScheme.surface,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: colorScheme.outlineVariant, width: 6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  children: [
                    // Mock StatusBar
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('12:00', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                          Row(
                            children: [
                              Icon(Icons.wifi, size: 12, color: colorScheme.onSurface),
                              const SizedBox(width: 4),
                              Icon(Icons.battery_full, size: 12, color: colorScheme.onSurface),
                            ],
                          )
                        ],
                      ),
                    ),
                    // Mock AppBar
                    Container(
                      height: 40,
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Container(width: 80, height: 12, decoration: BoxDecoration(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(6))),
                    ),
                    // Mock Content
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          Container(
                            height: 100,
                            decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: Icon(LucideIcons.image, color: colorScheme.onPrimaryContainer, size: 32),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 80,
                                  decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  height: 80,
                                  decoration: BoxDecoration(color: colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    // Mock FAB
                    Container(
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.bottomRight,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.add, color: colorScheme.onPrimary, size: 20),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          _sectionHeader('COLORES', colorScheme),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _paletteOptions.length,
              itemBuilder: (context, index) {
                final option = _paletteOptions[index];
                final isSelected = _settings.themePalette == option.$1;
                return GestureDetector(
                  onTap: () => _updateSettings(_settings.copyWith(themePalette: option.$1)),
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected ? Border.all(color: colorScheme.primary, width: 2) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(backgroundColor: option.$3, radius: 16),
                        const SizedBox(height: 8),
                        Text(option.$2, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          _sectionHeader('MODO', colorScheme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'system', icon: Icon(LucideIcons.monitor), label: Text('Sistema')),
                ButtonSegment(value: 'light', icon: Icon(LucideIcons.sun), label: Text('Claro')),
                ButtonSegment(value: 'dark', icon: Icon(LucideIcons.moon), label: Text('Oscuro')),
              ],
              selected: {_settings.themeMode},
              onSelectionChanged: (v) => _updateSettings(_settings.copyWith(themeMode: v.first)),
            ),
          ),

          const SizedBox(height: 24),
          _sectionHeader('OLED', colorScheme),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              title: const Text('Negro absoluto (OLED)'),
              subtitle: const Text('Usa fondo negro puro para ahorrar batería en pantallas OLED.'),
              value: _settings.oledBlack,
              onChanged: (v) => _updateSettings(_settings.copyWith(oledBlack: v)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, ColorScheme colorScheme) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colorScheme.primary, letterSpacing: 1.2)),
  );
}
