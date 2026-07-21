import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../widgets/media_widgets.dart';
import '../../../widgets/list_edit.dart';
import '../../../models/app_models.dart';
import '../logic/anime_detail_controller.dart';
import '../logic/anime_formatter.dart';
import '../../manga/logic/manga_formatter.dart';

class AnimeHeader extends StatelessWidget {
  final Map<String, dynamic> anime;
  final String title;
  final String cover;
  final VoidCallback? onPlayTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;
  final WatchEntry? watchEntry;
  final String? posterHeroTag;
  final String? titleHeroTag;

  const AnimeHeader({
    super.key,
    required this.anime,
    required this.title,
    required this.cover,
    this.onPlayTap,
    this.onFavoriteTap,
    this.isFavorite = false,
    this.watchEntry,
    this.posterHeroTag,
    this.titleHeroTag,
  });

  @override
  Widget build(BuildContext context) {
    final genres = (anime['genres'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final scoreRaw = (anime['averageScore'] as num?)?.toDouble();
    final score = scoreRaw != null ? (scoreRaw / 10).toStringAsFixed(1) : '-';

    return Stack(
      children: [
        // Banner Background (Transparent container with gradient only)
        Positioned.fill(
          child: Column(
            children: [
              Container(
                height: 600,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.8),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
            ],
          ),
        ),

        // Main Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 120),
              // Poster/Logo area
              Center(
                child: Hero(
                  tag: posterHeroTag ?? 'anime-poster-${anime['id']}',
                  child: Container(
                    width: 180,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: cover.isNotEmpty
                          ? AppCachedImage(
                              cover,
                              fit: BoxFit.cover,
                            )
                          : Container(color: Colors.white10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Logo or Title
              if (anime['customLogo'] != null)
                Hero(
                  tag: titleHeroTag ?? 'anime-title-${anime['id']}',
                  child: AppCachedImage(
                    anime['customLogo'],
                    height: 80,
                    fit: BoxFit.contain,
                    showPlaceholderBg: false,
                  ),
                )
              else
                Hero(
                  tag: titleHeroTag ?? 'anime-title-${anime['id']}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              // Score & Genres
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    score,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStatus(anime),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: genres
                    .take(5)
                    .map(
                      (g) => Text(
                        g,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),

              // Main Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(130, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: onPlayTap,
                    icon: const Icon(LucideIcons.play, size: 18),
                    label: Text(
                      watchEntry != null ? 'CONTINUAR' : 'VER',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ListEdit(
                    title: title,
                    posterUrl: cover,
                    totalEpisodes: anime['episodes'] as int? ?? 0,
                    initialStatus: anime['mediaListEntry']?['status']
                        ?.toString()
                        .replaceAll('_', ' '),
                    initialScore: (anime['mediaListEntry']?['score'] as num?)
                        ?.toDouble(),
                    initialProgress:
                        watchEntry?.watchedEpisodes.length ??
                        anime['mediaListEntry']?['progress'] as int?,
                    minimal: true,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      isFavorite ? LucideIcons.heart : LucideIcons.heart,
                      color: isFavorite ? Colors.redAccent : Colors.white,
                    ),
                    onPressed: onFavoriteTap,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatus(Map<String, dynamic> anime) {
    final status = anime['status']?.toString().toUpperCase() ?? '';
    final isReleasing = status == 'RELEASING';
    final nextAiring = anime['nextAiringEpisode'];

    String statusText = status.replaceAll('_', ' ');
    if (isReleasing && nextAiring != null) {
      final ep = nextAiring['episode'];
      final airingAt = nextAiring['airingAt'] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(airingAt * 1000);
      final now = DateTime.now();
      final diff = date.difference(now);

      if (!diff.isNegative) {
        String timeStr;
        if (diff.inDays > 0) {
          timeStr = '${diff.inDays}d ${diff.inHours % 24}h';
        } else if (diff.inHours > 0) {
          timeStr = '${diff.inHours}h ${diff.inMinutes % 60}m';
        } else {
          timeStr = '${diff.inMinutes}m';
        }
        statusText = 'EP $ep: $timeStr';
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isReleasing)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(LucideIcons.radio, size: 14, color: Colors.greenAccent),
          ),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isReleasing ? Colors.greenAccent : Colors.white54,
          ),
        ),
      ],
    );
  }
}
