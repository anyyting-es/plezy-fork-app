import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/app_models.dart';
import '../services/storage_service.dart';
import '../widgets/media_widgets.dart';

class ListsPage extends StatefulWidget {
  const ListsPage({
    super.key,
    required this.onAnimeTap,
    required this.refreshSeed,
  });

  final void Function(int id, {String? posterHeroTag, String? titleHeroTag}) onAnimeTap;
  final int refreshSeed;

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  final _storage = StorageService.instance;
  List<ListEntry> _animeLists = [];
  List<Map<String, dynamic>> _animeFavs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ListsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final animeFavs = await _storage.getFavorites();
    final animeLists = await _storage.getAnimeLists();
    if (!mounted) return;
    setState(() {
      _animeFavs = animeFavs;
      _animeLists = animeLists;
      _loading = false;
    });
  }

  Map<String, dynamic> _toMediaFromFavorite(Map<String, dynamic> fav) {
    return {
      'id': fav['animeId'] ?? 0,
      'title': {'romaji': fav['title'], 'english': fav['titleEnglish']},
      'coverImage': {'extraLarge': fav['cover'], 'large': fav['cover']},
      'averageScore': fav['averageScore'],
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final isWide = MediaQuery.of(context).size.width > 900;
            return ListView(
              padding: EdgeInsets.only(left: isWide ? 68.0 : 0.0, bottom: 24),
              children: [
                if (_animeFavs.isNotEmpty)
                  MediaSection(
                    title: 'Favoritos',
                    items: _animeFavs.map(_toMediaFromFavorite).toList(),
                    useBackdrop: false,
                    onItemTap: (item, posterTag, titleTag) {
                      final id = (item['id'] as num).toInt();
                      widget.onAnimeTap(id, posterHeroTag: posterTag, titleHeroTag: titleTag);
                    },
                  ),
                if (_animeLists.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mi lista de Anime',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._animeLists.map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.title),
                            subtitle: Text(
                              '${item.list.name} · progreso ${item.progress}',
                            ),
                            onTap: () => widget.onAnimeTap(item.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_animeFavs.isEmpty && _animeLists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no tienes favoritos ni elementos en tus listas.',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
}
}
