import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/plugin_extensions_service.dart';
import '../../services/settings_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/platform_detector.dart';
import '../../widgets/focused_scroll_scaffold.dart';

class RepoExtension {
  final String id;
  final String name;
  final String version;
  final String type;
  final String icon;
  final String code;
  final String language;
  final bool dub;
  final bool sub;
  final String contentType;

  RepoExtension({
    required this.id,
    required this.name,
    required this.version,
    required this.type,
    required this.icon,
    required this.code,
    required this.language,
    required this.dub,
    required this.sub,
    required this.contentType,
  });

  factory RepoExtension.fromJson(Map<String, dynamic> json, Uri baseUri) {
    final rawCode = json['code']?.toString() ?? '';
    final resolvedCode = rawCode.isNotEmpty ? baseUri.resolve(rawCode).toString() : '';

    return RepoExtension(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      version: json['version']?.toString() ?? '0.0.1',
      type: json['type']?.toString() ?? 'online',
      icon: json['icon']?.toString() ?? '',
      code: resolvedCode,
      language: json['language']?.toString() ?? 'multi',
      dub: json['dub'] == true,
      sub: json['sub'] == true,
      contentType: json['contentType']?.toString() ?? _deduceContentType(json['id']?.toString() ?? ''),
    );
  }

  static String _deduceContentType(String id) {
    final idLower = id.toLowerCase();
    if (idLower.contains('anime') || idLower.contains('tosho') || idLower.contains('neko') || idLower.contains('bt')) {
      return 'anime';
    }
    if (idLower.contains('manga')) {
      return 'manga';
    }
    return 'general';
  }
}

class ExtensionsSettingsScreen extends StatefulWidget {
  const ExtensionsSettingsScreen({super.key});

  @override
  State<ExtensionsSettingsScreen> createState() => _ExtensionsSettingsScreenState();
}

class _ExtensionsSettingsScreenState extends State<ExtensionsSettingsScreen> {
  final TextEditingController _repoController = TextEditingController(
    text: 'https://raw.githubusercontent.com/anyyting-es/plezy-extensions/main/index.json',
  );

  bool _loading = true;
  List<ExtensionPlugin> _installedExtensions = [];
  List<String> _disabledExtensions = [];
  List<RepoExtension> _repoExtensions = [];
  bool _autoSelect = true;
  String? _errorMessage;

  String _selectedType = 'all'; // 'all', 'online', 'torrent'
  String _selectedLanguage = 'all'; // 'all', 'es', 'en', 'multi'
  Map<String, String> _localVersions = {};

  @override
  void initState() {
    super.initState();
    _loadExtensions();
  }

  @override
  void dispose() {
    _repoController.dispose();
    super.dispose();
  }

  Future<void> _loadExtensions() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final settings = SettingsService.instance;
      _disabledExtensions = settings.read(SettingsService.disabledExtensions);
      _autoSelect = settings.read(SettingsService.autoSelectExtensionStream);

      // Load installed extensions from backend
      _installedExtensions = await PluginExtensionsService.listExtensions();

      // Load saved local versions from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final localVersionsJson = prefs.getString('local_extension_versions') ?? '{}';
        final Map<String, dynamic> decoded = jsonDecode(localVersionsJson);
        _localVersions = decoded.map((key, value) => MapEntry(key, value.toString()));
      } catch (e) {
        debugPrint('Error loading local extension versions: $e');
        _localVersions = {};
      }

      // Load extensions list from repo URL
      final repoUrl = _repoController.text.trim();
      if (repoUrl.isNotEmpty) {
        final baseUri = Uri.parse(repoUrl);
        final resp = await http.get(baseUri).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final list = jsonDecode(resp.body) as List;
          _repoExtensions = list
              .whereType<Map<String, dynamic>>()
              .map((item) => RepoExtension.fromJson(item, baseUri))
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      appLogger.e('[ExtensionsSettings] Failed to load extensions', error: e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al conectar con el servidor o el repositorio.';
          _loading = false;
        });
      }
    }
  }

  bool _isInstalled(String id) {
    return _installedExtensions.any((ext) => ext.id == id);
  }

  bool _isEnabled(String id) {
    return !_disabledExtensions.contains(id);
  }

  Future<void> _toggleExtension(String id) async {
    final newList = List<String>.from(_disabledExtensions);
    if (newList.contains(id)) {
      newList.remove(id);
    } else {
      newList.add(id);
    }
    await SettingsService.instance.write(SettingsService.disabledExtensions, newList);
    setState(() {
      _disabledExtensions = newList;
    });
  }

  Future<void> _toggleAutoSelect(bool value) async {
    await SettingsService.instance.write(SettingsService.autoSelectExtensionStream, value);
    setState(() {
      _autoSelect = value;
    });
  }

  Future<void> _install(RepoExtension ext) async {
    setState(() {
      _loading = true;
    });

    final ok = await PluginExtensionsService.installExtension(id: ext.id, url: ext.code);
    if (ok) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final localVersionsJson = prefs.getString('local_extension_versions') ?? '{}';
        final Map<String, dynamic> localVersions = jsonDecode(localVersionsJson);
        localVersions[ext.id] = ext.version;
        await prefs.setString('local_extension_versions', jsonEncode(localVersions));
      } catch (e) {
        debugPrint('Error saving local extension version: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Extensión "${ext.name}" instalada con éxito.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al instalar la extensión.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    await _loadExtensions();
  }

  Future<void> _uninstall(String id, String name) async {
    setState(() {
      _loading = true;
    });

    final ok = await PluginExtensionsService.uninstallExtension(id: id);
    if (ok) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final localVersionsJson = prefs.getString('local_extension_versions') ?? '{}';
        final Map<String, dynamic> localVersions = jsonDecode(localVersionsJson);
        localVersions.remove(id);
        await prefs.setString('local_extension_versions', jsonEncode(localVersions));
      } catch (e) {
        debugPrint('Error removing local extension version: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Extensión "$name" desinstalada con éxito.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al desinstalar la extensión.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    await _loadExtensions();
  }

  Future<void> _showCustomInstallDialog() async {
    final idController = TextEditingController();
    final urlController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: const Text('Instalar Extensión Personalizada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'ID de Extensión (ej. mi-custom-plugin)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL del Archivo Javascript (.js)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final id = idController.text.trim();
                final url = urlController.text.trim();
                if (id.isNotEmpty && url.isNotEmpty) {
                  Navigator.pop(ctx);
                  setState(() {
                    _loading = true;
                  });
                  final ok = await PluginExtensionsService.installExtension(id: id, url: url);
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Extensión "$id" instalada con éxito.'), backgroundColor: Colors.green),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error al instalar la extensión.'), backgroundColor: Colors.redAccent),
                    );
                  }
                  await _loadExtensions();
                }
              },
              child: const Text('Instalar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Future<String> _loadExtensionCode(String id, String? repoCodeUrl) async {
    try {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) {
        final localFile = File('$home/.aniting/extensions/$id.js');
        if (await localFile.exists()) {
          return await localFile.readAsString();
        }
      }
    } catch (e) {
      debugPrint('Error reading local extension file: $e');
    }

    if (repoCodeUrl != null && repoCodeUrl.isNotEmpty) {
      final resp = await http.get(Uri.parse(repoCodeUrl)).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        return resp.body;
      }
      throw Exception('HTTP ${resp.statusCode} - ${resp.body}');
    }

    throw Exception('No se pudo encontrar el código de la extensión.');
  }

  void _showCodeViewerDialog(String name, String id, String? repoCodeUrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Row(
            children: [
              const Icon(Symbols.code_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Código: $name',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.8,
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: FutureBuilder<String>(
              future: _loadExtensionCode(id, repoCodeUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Symbols.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 16),
                        Text(
                          'No se pudo cargar el código.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  );
                }

                final code = snapshot.data ?? '';
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FocusedScrollScaffold(
      title: const Text('Extensiones'),
      actions: [
        IconButton(
          icon: const Icon(Symbols.add_box_rounded),
          tooltip: 'Instalación manual',
          onPressed: _showCustomInstallDialog,
        ),
        IconButton(
          icon: const Icon(Symbols.refresh_rounded),
          onPressed: _loadExtensions,
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _repoController,
                    decoration: const InputDecoration(
                      labelText: 'Repositorio de Extensiones',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _loadExtensions(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadExtensions,
                  icon: const Icon(Symbols.sync_rounded),
                  label: const Text('Cargar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tipo de Fuente',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildFilterChip(
                                label: 'Todos',
                                selected: _selectedType == 'all',
                                onSelected: (val) {
                                  if (val) setState(() => _selectedType = 'all');
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                label: 'Streaming',
                                selected: _selectedType == 'online',
                                onSelected: (val) {
                                  if (val) setState(() => _selectedType = 'online');
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                label: 'Torrents',
                                selected: _selectedType == 'torrent',
                                onSelected: (val) {
                                  if (val) setState(() => _selectedType = 'torrent');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Idioma',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(
                                  label: 'Todos',
                                  selected: _selectedLanguage == 'all',
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedLanguage = 'all');
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  label: 'Español (ES)',
                                  selected: _selectedLanguage == 'es',
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedLanguage = 'es');
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  label: 'Inglés (EN)',
                                  selected: _selectedLanguage == 'en',
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedLanguage = 'en');
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  label: 'Multi',
                                  selected: _selectedLanguage == 'multi',
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedLanguage = 'multi');
                                  },
                                ),
                              ],
                            ),
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                secondary: const Icon(Symbols.bolt_rounded),
                title: const Text('Reproducción Automática'),
                subtitle: const Text('Omitir el diálogo de origen y reproducir el primer stream online disponible'),
                value: _autoSelect,
                onChanged: (val) => _toggleAutoSelect(val),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),
        if (_loading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_errorMessage != null)
          SliverToBoxAdapter(child: _buildErrorView(theme))
        else
          _buildExtensionsListSliver(theme),
      ],
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Icon(Symbols.error_outline_rounded, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadExtensions,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionsListSliver(ThemeData theme) {
    final isMobile = PlatformDetector.isMobile(context) && !PlatformDetector.isTV();
    final allIds = <String>{};
    final items = <dynamic>[];

    final activeType = SettingsService.instance.read(SettingsService.discoverContentType);
    final String activeTypeStr = activeType == DiscoverContentType.anime ? 'anime' : 'general';

    for (final ext in _repoExtensions) {
      if (ext.contentType != activeTypeStr) continue;
      if (_selectedType != 'all' && ext.type != _selectedType) continue;
      if (_selectedLanguage != 'all' && 
          ext.language != _selectedLanguage && 
          ext.language != 'multi' && 
          ext.language.isNotEmpty) {
        continue;
      }

      allIds.add(ext.id);
      items.add(ext);
    }

    for (final ext in _installedExtensions) {
      if (!allIds.contains(ext.id)) {
        if (ext.contentType != activeTypeStr) continue;
        final localType = (ext.id.contains('torrent') || ext.id.contains('tosho') || ext.id.contains('bt')) ? 'torrent' : 'online';
        if (_selectedType != 'all' && localType != _selectedType) continue;
        if (_selectedLanguage != 'all') continue; // Local manually installed ones don't have language property

        items.add(ext);
      }
    }

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              'No se encontraron extensiones en el repositorio ni instaladas localmente.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];

            if (item is RepoExtension) {
              final installed = _isInstalled(item.id);
              final enabled = _isEnabled(item.id);
              
              final localVersion = _localVersions[item.id];
              final updateAvailable = installed && localVersion != null && localVersion != item.version;

              if (isMobile) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.icon.isNotEmpty && item.icon.startsWith('http')) ...[
                              Image.network(
                                item.icon,
                                width: 40,
                                height: 40,
                                errorBuilder: (_, __, ___) => const Icon(Symbols.extension_rounded, size: 40),
                              ),
                              const SizedBox(width: 12),
                            ] else ...[
                              const Icon(Symbols.extension_rounded, size: 40),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondary.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'v${item.version}',
                                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _buildBadge(
                                        text: item.type == 'torrent' ? 'Torrent' : 'Online',
                                        color: item.type == 'torrent' ? Colors.teal : Colors.blue,
                                      ),
                                      _buildBadge(
                                        text: item.language.toUpperCase(),
                                        color: item.language == 'es'
                                            ? Colors.deepOrange
                                            : item.language == 'en'
                                                ? Colors.indigo
                                                : Colors.purple,
                                      ),
                                      if (item.sub) _buildBadge(text: 'SUB', color: Colors.grey),
                                      if (item.dub) _buildBadge(text: 'DUB', color: Colors.green),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (installed) ...[
                              const SizedBox(width: 8),
                              Switch(
                                value: enabled,
                                onChanged: (_) => _toggleExtension(item.id),
                              ),
                            ],
                          ],
                        ),
                        if (updateAvailable || (installed && localVersion != null)) ...[
                          const SizedBox(height: 8),
                          if (updateAvailable) 
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.withOpacity(0.3)),
                              ),
                              child: Text(
                                'Actualización disponible (v$localVersion -> v${item.version})',
                                style: theme.textTheme.labelSmall?.copyWith(color: Colors.amber.shade800, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else if (installed && localVersion != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Instalada (v$localVersion)',
                                style: theme.textTheme.labelSmall?.copyWith(color: Colors.green),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Symbols.code_rounded),
                              tooltip: 'Ver código',
                              onPressed: () => _showCodeViewerDialog(item.name, item.id, item.code),
                            ),
                            if (installed) ...[
                              if (updateAvailable)
                                ElevatedButton.icon(
                                  onPressed: () => _install(item),
                                  icon: const Icon(Symbols.update_rounded, size: 18),
                                  label: const Text('Actualizar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                )
                              else
                                IconButton(
                                  icon: Icon(
                                    Symbols.cloud_download_rounded,
                                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                  tooltip: 'Reinstalar',
                                  onPressed: () => _install(item),
                                ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _uninstall(item.id, item.name),
                                icon: const Icon(Symbols.delete_rounded, size: 18),
                                label: const Text('Eliminar'),
                                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                              ),
                            ] else ...[
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () => _install(item),
                                icon: const Icon(Symbols.download_rounded, size: 18),
                                label: const Text('Instalar'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (item.icon.isNotEmpty && item.icon.startsWith('http')) ...[
                        Image.network(
                          item.icon,
                          width: 40,
                          height: 40,
                          errorBuilder: (_, __, ___) => const Icon(Symbols.extension_rounded, size: 40),
                        ),
                        const SizedBox(width: 16),
                      ] else ...[
                        const Icon(Symbols.extension_rounded, size: 40),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.name,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'v${item.version}',
                                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary),
                                  ),
                                ),
                                if (updateAvailable) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      'Actualización disponible (v$localVersion)',
                                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.amber.shade800, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ] else if (installed && localVersion != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Instalada (v$localVersion)',
                                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.green),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                // Type Badge
                                _buildBadge(
                                  text: item.type == 'torrent' ? 'Torrent' : 'Online',
                                  color: item.type == 'torrent' ? Colors.teal : Colors.blue,
                                ),
                                // Language Badge
                                _buildBadge(
                                  text: item.language.toUpperCase(),
                                  color: item.language == 'es'
                                      ? Colors.deepOrange
                                      : item.language == 'en'
                                          ? Colors.indigo
                                          : Colors.purple,
                                ),
                                // Sub/Dub Badges
                                if (item.sub) _buildBadge(text: 'SUB', color: Colors.grey),
                                if (item.dub) _buildBadge(text: 'DUB', color: Colors.green),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Symbols.code_rounded),
                        tooltip: 'Ver código',
                        onPressed: () => _showCodeViewerDialog(item.name, item.id, item.code),
                      ),
                      const SizedBox(width: 8),
                      if (installed) ...[
                        if (updateAvailable) ...[
                          ElevatedButton.icon(
                            onPressed: () => _install(item),
                            icon: const Icon(Symbols.update_rounded, size: 18),
                            label: const Text('Actualizar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else ...[
                          IconButton(
                            icon: Icon(
                              Symbols.cloud_download_rounded,
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                            ),
                            tooltip: 'Reinstalar extensión',
                            onPressed: () => _install(item),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Switch(
                          value: enabled,
                          onChanged: (_) => _toggleExtension(item.id),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _uninstall(item.id, item.name),
                          icon: const Icon(Symbols.delete_rounded, size: 18),
                          label: const Text('Eliminar'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => _install(item),
                          icon: const Icon(Symbols.download_rounded, size: 18),
                          label: const Text('Instalar'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            } else if (item is ExtensionPlugin) {
              final enabled = _isEnabled(item.id);

              if (isMobile) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Symbols.extension_rounded, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manual (Local)',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: enabled,
                              onChanged: (_) => _toggleExtension(item.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Symbols.code_rounded),
                              tooltip: 'Ver código',
                              onPressed: () => _showCodeViewerDialog(item.name, item.id, null),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _uninstall(item.id, item.name),
                              icon: const Icon(Symbols.delete_rounded, size: 18),
                              label: const Text('Eliminar'),
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Symbols.extension_rounded, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Archivo: ${item.filename} (Manual / Local)',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Symbols.code_rounded),
                        tooltip: 'Ver código',
                        onPressed: () => _showCodeViewerDialog(item.name, item.id, null),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: enabled,
                        onChanged: (_) => _toggleExtension(item.id),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _uninstall(item.id, item.name),
                        icon: const Icon(Symbols.delete_rounded, size: 18),
                        label: const Text('Eliminar'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox();
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildBadge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
