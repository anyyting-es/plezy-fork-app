import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../extensions/extension_service.dart';
import '../../extensions/models/extension_manifest.dart';
import '../../providers/torrent_provider.dart';

class ExtensionsPage extends StatefulWidget {
  const ExtensionsPage({super.key});

  @override
  State<ExtensionsPage> createState() => _ExtensionsPageState();
}

class _ExtensionsPageState extends State<ExtensionsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = ExtensionService();
  bool _isLoading = false;

  // Marketplace
  String _marketplaceUrl = '';
  List<ExtensionManifest> _marketplaceExtensions = [];
  String _marketplaceFilter = 'all';
  String _marketplaceSearch = '';

  // Updates: extensionId -> newVersion
  Map<String, String> _updatesAvailable = {};
  // Mapa de marketplace por id para acceso rapido
  final Map<String, ExtensionManifest> _marketplaceById = {};

  // Invalid extensions: failed to load (loaded on first refresh)
  final List<_InvalidExt> _invalidExtensions = [];

  static const _defaultMarketplaceUrl = 'file:///home/anthony/Documents/ANITING-FLUTTER/extensions_repo/marketplace.json';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _hasDefaultUrl => _marketplaceUrl.isEmpty || _marketplaceUrl == _defaultMarketplaceUrl;

  int get _totalUpdateCount => _updatesAvailable.length;

  Future<void> _loadMarketplace() async {
    final url = _marketplaceUrl.isEmpty ? _defaultMarketplaceUrl : _marketplaceUrl;
    setState(() => _isLoading = true);
    try {
      String body;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
        body = response.body;
      } else {
        final filePath = url.replaceFirst('file://', '');
        final file = File(filePath);
        if (!await file.exists()) throw Exception('Archivo no encontrado: $url');
        body = await file.readAsString();
      }

      final decoded = jsonDecode(body);

      List<dynamic> rawList;
      if (decoded is List) {
        rawList = decoded;
      } else if (decoded is Map<String, dynamic> && decoded.containsKey('extensions')) {
        rawList = decoded['extensions'] as List? ?? [];
      } else {
        throw Exception('Formato de marketplace no reconocido');
      }

      final baseDir = _getBaseDir(url);
      final list = rawList.map((e) {
        final m = Map<String, dynamic>.from(e as Map<String, dynamic>);
        final scriptUrl = m['scriptUrl']?.toString() ?? '';
        if (scriptUrl.isNotEmpty &&
            !scriptUrl.startsWith('http://') &&
            !scriptUrl.startsWith('https://') &&
            !scriptUrl.startsWith('file://') &&
            !scriptUrl.startsWith('/')) {
          m['scriptUrl'] = baseDir + scriptUrl;
        }
        return m;
      }).toList();

      _marketplaceExtensions = list
          .map((e) => ExtensionManifest.fromJson(e as Map<String, dynamic>))
          .where((e) => e.id.isNotEmpty)
          .toList();

      _marketplaceById.clear();
      for (final ext in _marketplaceExtensions) {
        _marketplaceById[ext.id] = ext;
      }

      _checkForUpdates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar marketplace: $e')));
      }
      _marketplaceExtensions = [];
    }
    setState(() => _isLoading = false);
  }

  String _getBaseDir(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.parse(url);
      final segments = List<String>.from(uri.pathSegments);
      segments.removeLast();
      var base = uri.replace(pathSegments: segments).toString();
      if (!base.endsWith('/')) base += '/';
      return base;
    } else {
      final filePath = url.replaceFirst('file://', '');
      final file = File(filePath);
      var base = file.parent.path;
      if (!base.endsWith(Platform.pathSeparator)) base += Platform.pathSeparator;
      return base;
    }
  }

  void _checkForUpdates() {
    _updatesAvailable.clear();
    for (final installed in _service.extensions) {
      final id = installed.manifest.id;
      final currentVersion = installed.manifest.version;
      final market = _marketplaceById[id];
      if (market != null && market.version.isNotEmpty && currentVersion.isNotEmpty) {
        if (_isNewerVersion(market.version, currentVersion)) {
          _updatesAvailable[id] = market.version;
        }
      }
    }
  }

  bool _isNewerVersion(String a, String b) {
    try {
      final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      while (pa.length < 3) pa.add(0);
      while (pb.length < 3) pb.add(0);
      for (int i = 0; i < 3; i++) {
        if (pa[i] > pb[i]) return true;
        if (pa[i] < pb[i]) return false;
      }
      return false;
    } catch (_) {
      return a != b;
    }
  }

  Future<void> _installFromMarketplace(ExtensionManifest ext) async {
    setState(() => _isLoading = true);
    try {
      await _service.installFromMarketplace(ext);
      _updatesAvailable.remove(ext.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ext.name} instalada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateAll() async {
    setState(() => _isLoading = true);
    int done = 0;
    int failed = 0;
    final ids = _updatesAvailable.keys.toList();
    for (final id in ids) {
      final market = _marketplaceById[id];
      if (market == null) continue;
      try {
        await _service.installFromMarketplace(market);
        _updatesAvailable.remove(id);
        done++;
      } catch (_) {
        failed++;
      }
    }
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$done actualizadas${failed > 0 ? ", $failed fallaron" : ""}')),
      );
    }
  }

  Future<void> _updateSingle(String id) async {
    final market = _marketplaceById[id];
    if (market == null) return;
    await _installFromMarketplace(market);
  }

  Future<void> _uninstallExtension(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desinstalar'),
        content: Text('Desinstalar "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desinstalar')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _service.uninstallExtension(id);
      _updatesAvailable.remove(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name desinstalada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _reloadExtension(String id, String name) async {
    setState(() => _isLoading = true);
    try {
      await _service.reloadExtension(id);
      _checkForUpdates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name recargada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _showMarketplaceUrlDialog() async {
    final controller = TextEditingController(text: _marketplaceUrl.isEmpty ? _defaultMarketplaceUrl : _marketplaceUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('URL del Marketplace'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://...',
            labelText: 'URL del marketplace JSON',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _defaultMarketplaceUrl),
            child: const Text('Default'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Usar'),
          ),
        ],
      ),
    );
    if (result != null) {
      _marketplaceUrl = result.isEmpty || result == _defaultMarketplaceUrl ? '' : result;
      await _loadMarketplace();
    }
  }

  List<ExtensionManifest> get _filteredMarketplace {
    var list = _marketplaceExtensions;
    if (_marketplaceFilter != 'all') {
      list = list.where((e) => e.type == _marketplaceFilter).toList();
    }
    if (_marketplaceSearch.isNotEmpty) {
      final q = _marketplaceSearch.toLowerCase();
      list = list.where((e) => e.name.toLowerCase().contains(q) || e.id.toLowerCase().contains(q) || e.description.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  String _typeLabel(String type) {
    const labels = {
      'anime': 'Anime',
      'manga': 'Manga',
      'torrent': 'Torrent',
      'plugin': 'Plugin',
    };
    return labels[type] ?? type;
  }

  Color _typeColor(String type, ColorScheme cs) {
    switch (type) {
      case 'anime':
        return cs.primary;
      case 'manga':
        return Colors.green;
      case 'torrent':
        return Colors.orange;
      case 'plugin':
        return Colors.purple;
      default:
        return cs.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Hero(
          tag: 'extensions_title',
          child: Material(
            type: MaterialType.transparency,
            child: const Text('Extensiones', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        backgroundColor: cs.surface,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download, size: 20),
            tooltip: 'Importar desde URL',
            onPressed: _isLoading ? null : _importExtension,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Instaladas'),
            Tab(text: 'Marketplace'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInstalledTab(cs),
                _buildMarketplaceTab(cs),
              ],
            ),
    );
  }

  // ─── Import ───────────────────────────────────────────────────

  Future<void> _importExtension() async {
    final textController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar Extension'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'URL de .json, .js o manifest',
            labelText: 'URL',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, textController.text), child: const Text('Importar')),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;

    if (!url.endsWith('.js') && !url.endsWith('.ts') && !url.endsWith('.json')) {
      if (mounted) await _importFromManifestUrl(url);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (url.endsWith('.json')) {
        await _handleRepoImport(url);
      } else {
        await _installSingleExtension(url);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _importFromManifestUrl(String url) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final manifest = ExtensionManifest.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      await _service.installFromMarketplace(manifest);
      _updatesAvailable.remove(manifest.id);
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${manifest.name} instalada')));
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleRepoImport(String repoUrl) async {
    String body;
    if (repoUrl.startsWith('http://') || repoUrl.startsWith('https://')) {
      final response = await http.get(Uri.parse(repoUrl));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      body = response.body;
    } else {
      final file = File(repoUrl.replaceFirst('file://', ''));
      if (!await file.exists()) throw Exception('Archivo no encontrado: $repoUrl');
      body = await file.readAsString();
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final repoName = data['name'] ?? 'Repositorio';
    final extensions = (data['extensions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final baseUrl = _getBaseDir(repoUrl);

    final cs = Theme.of(context).colorScheme;
    setState(() => _isLoading = false);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(repoName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: extensions.length,
                itemBuilder: (_, index) {
                  final ext = extensions[index];
                  String scriptUrl = ext['scriptUrl'] ?? '';
                  if (scriptUrl.isNotEmpty &&
                      !scriptUrl.startsWith('http://') &&
                      !scriptUrl.startsWith('https://') &&
                      !scriptUrl.startsWith('file://') &&
                      !scriptUrl.startsWith('/')) {
                    scriptUrl = baseUrl + scriptUrl;
                  }

                  return ListTile(
                    leading: Icon(LucideIcons.puzzle, color: cs.primary),
                    title: Text(ext['name'] ?? 'Unknown'),
                    subtitle: Text('${ext['type']} • v${ext['version']}'),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        setState(() => _isLoading = true);
                        try {
                          await _installSingleExtension(scriptUrl);
                        } catch (e) {
                          setState(() => _isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      child: const Text('Instalar'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _installSingleExtension(String url) async {
    final provider = TorrentProvider();
    final downloadDir = await provider.getDownloadDirectory();
    final extensionsDir = Directory('$downloadDir${Platform.pathSeparator}extensions');
    if (!await extensionsDir.exists()) await extensionsDir.create(recursive: true);

    String body;
    String fileName;

    if (url.startsWith('http://') || url.startsWith('https://')) {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode} - $url');
      body = response.body;
      fileName = Uri.parse(url).pathSegments.last;
    } else {
      final normalizedPath = url.replaceFirst('file://', '').replaceAll('/', Platform.pathSeparator);
      final file = File(normalizedPath);
      if (!await file.exists()) throw Exception('Archivo no encontrado: $url');
      body = await file.readAsString();
      fileName = normalizedPath.split(Platform.pathSeparator).last;
    }

    final destFile = File('${extensionsDir.path}${Platform.pathSeparator}$fileName');
    await destFile.writeAsString(body);

    final extensionId = fileName.replaceAll('.js', '').replaceAll('.ts', '');
    final backendUrl = await provider.getBackendUrl();
    await http.post(Uri.parse('$backendUrl/extension/reload/$extensionId'));

    await _service.loadAllBackendExtensions();

    setState(() => _isLoading = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Extension instalada')));
  }

  // ─── Installed Tab ────────────────────────────────────────────

  Widget _buildInstalledTab(ColorScheme cs) {
    final exts = _service.extensions;

    if (exts.isEmpty && _invalidExtensions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.puzzle, size: 48, color: cs.outline),
            const SizedBox(height: 16),
            Text('No hay extensiones instaladas', style: TextStyle(color: cs.outline)),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonal(
                  onPressed: () => _tabController.animateTo(1),
                  child: const Text('Marketplace'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _importExtension,
                  child: const Text('Importar'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final byType = <String, List<_ExtensionEntry>>{};
    for (final ext in exts) {
      final type = ext.manifest.type.isNotEmpty ? ext.manifest.type : 'anime';
      byType.putIfAbsent(type, () => []);
      byType[type]!.add(_ExtensionEntry(ext.manifest, null));
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Updates banner
        if (_totalUpdateCount > 0)
          Card(
            color: cs.primary.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cs.primary.withOpacity(0.3))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(LucideIcons.refreshCw, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text('$_totalUpdateCount actualizaciones disponibles', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600))),
                  FilledButton(onPressed: _updateAll, child: const Text('Actualizar todas')),
                ],
              ),
            ),
          ),
        // Invalid extensions
        if (_invalidExtensions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Errores', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
                ),
                const SizedBox(width: 8),
                Text('${_invalidExtensions.length}', style: TextStyle(fontSize: 12, color: cs.outline)),
              ],
            ),
          ),
          ..._invalidExtensions.map((inv) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.red.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.red.withOpacity(0.3))),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(LucideIcons.triangleAlert, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.id, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        if (inv.error.isNotEmpty)
                          Text(inv.error, style: TextStyle(fontSize: 11, color: cs.outline), maxLines: 2),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.trash, size: 16),
                    onPressed: () async {
                      setState(() => _invalidExtensions.removeWhere((e) => e.id == inv.id));
                      final provider = TorrentProvider();
                      final dl = await provider.getDownloadDirectory();
                      final f = File('$dl${Platform.pathSeparator}extensions${Platform.pathSeparator}${inv.id}.js');
                      if (await f.exists()) await f.delete();
                      final f2 = File('$dl${Platform.pathSeparator}extensions${Platform.pathSeparator}${inv.id}.ts');
                      if (await f2.exists()) await f2.delete();
                    },
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
            ),
          )),
        ],
        // Installed extensions by type
        for (final entry in byType.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _typeColor(entry.key, cs).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_typeLabel(entry.key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _typeColor(entry.key, cs))),
                ),
                const SizedBox(width: 8),
                Text('${entry.value.length}', style: TextStyle(fontSize: 12, color: cs.outline)),
              ],
            ),
          ),
          ...entry.value.map((e) => _buildExtensionCard(cs, e)),
        ],
      ],
    );
  }

  // ─── Marketplace Tab ──────────────────────────────────────────

  Widget _buildMarketplaceTab(ColorScheme cs) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _marketplaceSearch = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                onPressed: _loadMarketplace,
                tooltip: 'Refrescar / Buscar updates',
              ),
              IconButton(
                icon: const Icon(LucideIcons.settings, size: 18),
                onPressed: _showMarketplaceUrlDialog,
                tooltip: 'Cambiar URL',
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: ['all', 'anime', 'manga', 'torrent'].map((f) {
              final selected = _marketplaceFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f == 'all' ? 'Todos' : _typeLabel(f)),
                  selected: selected,
                  onSelected: (_) => setState(() => _marketplaceFilter = f),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _marketplaceExtensions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.store, size: 48, color: cs.outline),
                      const SizedBox(height: 16),
                      Text('Presiona refrescar para cargar', style: TextStyle(color: cs.outline)),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: _loadMarketplace,
                        child: const Text('Cargar Marketplace'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredMarketplace.length,
                  itemBuilder: (_, i) {
                    final ext = _filteredMarketplace[i];
                    final installed = _service.isInstalled(ext.id);
                    final hasUpdate = _updatesAvailable.containsKey(ext.id);
                    String? status;
                    if (installed && hasUpdate) {
                      status = 'update';
                    } else if (installed) {
                      status = 'installed';
                    }
                    return _buildExtensionCard(cs, _ExtensionEntry(ext, status, isMarketplace: true, onInstall: () => _installFromMarketplace(ext)));
                  },
                ),
        ),
      ],
    );
  }

  // ─── Extension Card ───────────────────────────────────────────

  Widget _buildExtensionCard(ColorScheme cs, _ExtensionEntry entry) {
    final m = entry.manifest;
    final isMarketplace = entry.isMarketplace;
    final isUpdate = entry.status == 'update';
    final isInstalled = entry.status == 'installed';
    final newVersion = _updatesAvailable[m.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isUpdate ? cs.primary.withOpacity(0.08) : cs.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUpdate ? BorderSide(color: cs.primary.withOpacity(0.4)) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 44,
                height: 44,
                color: _typeColor(m.type, cs).withOpacity(0.15),
                child: Icon(LucideIcons.puzzle, size: 22, color: _typeColor(m.type, cs)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                      if (isInstalled) Icon(LucideIcons.checkCheck, size: 16, color: cs.primary),
                      if (isUpdate) Icon(LucideIcons.refreshCw, size: 16, color: cs.primary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(m.id, style: TextStyle(fontSize: 11, color: cs.outline)),
                  if (m.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(m.description, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _badge(_typeLabel(m.type), _typeColor(m.type, cs)),
                      _badge('v${m.version}', cs.outline),
                      if (isUpdate && newVersion != null) _badge('actualizar a v$newVersion', cs.primary),
                      if (m.author.isNotEmpty) _badge(m.author, cs.outline),
                      if (m.lang.isNotEmpty) _badge(m.lang.toUpperCase(), cs.outline),
                    ],
                  ),
                ],
              ),
            ),
            if (isMarketplace && isUpdate)
              FilledButton.tonal(
                onPressed: () => _updateSingle(m.id),
                child: const Text('Actualizar'),
              )
            else if (isMarketplace && !isInstalled)
              FilledButton.tonal(
                onPressed: entry.onInstall,
                child: const Text('Instalar'),
              )
            else if (!isMarketplace)
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                onSelected: (action) {
                  switch (action) {
                    case 'reload':
                      _reloadExtension(m.id, m.name);
                    case 'uninstall':
                      _uninstallExtension(m.id, m.name);
                  }
                },
                itemBuilder: (_) => [
                  if (_updatesAvailable.containsKey(m.id))
                    PopupMenuItem(value: 'update', child: Row(children: [Icon(LucideIcons.refreshCw, size: 16, color: cs.primary), const SizedBox(width: 8), Text('Actualizar a v${_updatesAvailable[m.id]}')])),
                  const PopupMenuItem(value: 'reload', child: Row(children: [Icon(LucideIcons.refreshCw, size: 16), SizedBox(width: 8), Text('Recargar')])),
                  const PopupMenuItem(value: 'uninstall', child: Row(children: [Icon(LucideIcons.trash, size: 16), SizedBox(width: 8), Text('Desinstalar')])),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ExtensionEntry {
  final ExtensionManifest manifest;
  final String? status;
  final bool isMarketplace;
  final VoidCallback? onInstall;

  _ExtensionEntry(this.manifest, this.status, {this.isMarketplace = false, this.onInstall});
}

class _InvalidExt {
  final String id;
  final String error;
  final String filePath;

  _InvalidExt(this.id, {this.error = '', this.filePath = ''});
}
