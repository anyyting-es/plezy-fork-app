import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/app_models.dart';
import '../services/anilist_service.dart';
import '../services/storage_service.dart';
import '../widgets/media_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.onAnimeTap,
    required this.refreshSeed,
    required this.onOpenSettings,
  });

  final void Function(int id, {String? posterHeroTag, String? titleHeroTag}) onAnimeTap;
  final int refreshSeed;
  final VoidCallback onOpenSettings;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = StorageService.instance;
  final _anilist = AnilistService.instance;

  List<ListEntry> _animeLists = _cachedAnimeLists;
  bool _loading = true;

  static List<Map<String, dynamic>> _cachedAnimeFavs = [];
  static List<ListEntry> _cachedAnimeLists = [];
  static bool _hasLoadedOnce = false;

  List<Map<String, dynamic>> get _animeFavs => _cachedAnimeFavs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!_hasLoadedOnce) {
      setState(() => _loading = true);
    }
    final animeFavs = await _storage.getFavorites();
    final animeLists = await _storage.getAnimeLists();
    if (!mounted) return;
    setState(() {
      _cachedAnimeFavs = animeFavs;
      _cachedAnimeLists = animeLists;
      _animeLists = animeLists;
      _loading = false;
      _hasLoadedOnce = true;
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

    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isWide ? 88.0 : null,
        title: const Text(
          'Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: widget.onOpenSettings,
          ),
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _anilist.userNotifier,
            builder: (context, user, _) {
              if (user == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(LucideIcons.logOut),
                onPressed: () => _anilist.logout(),
              );
            },
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: _anilist.userNotifier,
        builder: (context, user, _) {
          return ListView(
            padding: EdgeInsets.only(left: isWide ? 68.0 : 0.0),
            children: [
              if (user == null) _buildLoginPrompt(),
              if (user != null) _buildUserProfile(user),
              _buildFavoritesSection(),
              _buildListsSection(),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoginPrompt() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(LucideIcons.user, size: 64, color: colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Sincroniza con AniList',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Conecta tu cuenta para sincronizar tus listas de anime y manga automáticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _anilist.login(),
              icon: const Icon(LucideIcons.logIn),
              label: const Text('Conectarse con AniList'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfile(Map<String, dynamic> user) {
    final avatar = user['avatar']?['large'] as String?;
    final banner = user['bannerImage'] as String?;
    final name = user['name'] as String? ?? 'Usuario';
    final stats = user['statistics'];
    final animeCount = stats?['anime']?['count'] ?? 0;
    final mangaCount = stats?['manga']?['count'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                image: banner != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(banner),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
            Positioned(
              bottom: -40,
              left: 24,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundImage: avatar != null
                      ? CachedNetworkImageProvider(avatar)
                      : null,
                  child: avatar == null
                      ? const Icon(LucideIcons.user, size: 45)
                      : null,
                ),
              ),
            ),

          ],
        ),
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatChip(LucideIcons.circlePlay, '$animeCount Anime'),
                  const SizedBox(width: 12),
                  _buildStatChip(LucideIcons.book, '$mangaCount Manga'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFavoritesSection() {
    final favsAsMedia = _animeFavs.map(_toMediaFromFavorite).toList();
    if (favsAsMedia.isEmpty) return const SizedBox.shrink();
    return MediaSection(
      title: 'Favoritos',
      items: favsAsMedia,
      onItemTap: (item, posterTag, titleTag) {
        final id = (item['id'] as num).toInt();
        widget.onAnimeTap(id, posterHeroTag: posterTag, titleHeroTag: titleTag);
      },
    );
  }

  Widget _buildListsSection() {
    if (_animeLists.isEmpty) return const SizedBox.shrink();
    final grouped = <String, List<ListEntry>>{};
    for (final entry in _animeLists) {
      final key = listTypeToString(entry.list);
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    return Column(
      children: grouped.entries.map((group) {
        final items = group.value
            .map(
              (e) => {
                'id': e.id,
                'title': {'romaji': e.title, 'english': e.titleEnglish},
                'coverImage': {'extraLarge': e.cover, 'large': e.cover},
                'averageScore': e.averageScore,
              },
            )
            .toList();

        final label = switch (group.key) {
          'watching' => 'Viendo',
          'planning' => 'Por Ver',
          'completed' => 'Completado',
          'dropped' => 'Abandonado',
          'paused' => 'Pausado',
          _ => group.key,
        };

        return MediaSection(
          title: label,
          items: items,
          onItemTap: (item, posterTag, titleTag) {
            final id = (item['id'] as num).toInt();
            widget.onAnimeTap(id, posterHeroTag: posterTag, titleHeroTag: titleTag);
          },
        );
      }).toList(),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
