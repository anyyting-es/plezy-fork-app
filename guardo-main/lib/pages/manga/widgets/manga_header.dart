import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../widgets/media_widgets.dart';
import '../../../widgets/list_edit.dart';
import '../logic/manga_detail_controller.dart';
import '../logic/manga_formatter.dart';

class MangaHeader extends StatelessWidget {
  final MangaDetailController controller;
  final double scrollOffset;
  final VoidCallback onOpenReader;
  final String? posterHeroTag;
  final String? titleHeroTag;

  const MangaHeader({
    super.key,
    required this.controller,
    required this.scrollOffset,
    required this.onOpenReader,
    this.posterHeroTag,
    this.titleHeroTag,
  });

  @override
  Widget build(BuildContext context) {
    final manga = controller.manga!;
    final mainTitle =
        (manga['title']?['english'] ??
                manga['title']?['romaji'] ??
                'Sin título')
            .toString();
    final cover = manga['coverImage']?['large'] ?? '';
    final bg = manga['bannerImage'] ?? cover;
    final genres = (manga['genres'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final score = MangaFormatter.displayScore(manga['averageScore']);

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
                  tag: posterHeroTag ?? 'manga-poster-${controller.mangaId}',
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
              // Title
              Text(
                mainTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.1,
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
                  Text(
                    MangaFormatter.displayStatus(manga['status']),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                    ),
                  ),
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
                    onPressed: controller.loadingChapters ? null : onOpenReader,
                    icon: const Icon(LucideIcons.bookOpen, size: 18),
                    label: Text(
                      controller.resume != null ? 'REANUDAR' : 'LEER',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ListEdit(
                    title: mainTitle,
                    posterUrl: cover,
                    totalEpisodes: manga['chapters'] as int? ?? 0,
                    initialStatus: manga['mediaListEntry']?['status']
                        ?.toString()
                        .replaceAll('_', ' '),
                    initialScore: (manga['mediaListEntry']?['score'] as num?)
                        ?.toDouble(),
                    initialProgress:
                        manga['mediaListEntry']?['progress'] as int?,
                    minimal: true,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      controller.isFavorite
                          ? LucideIcons.heart
                          : LucideIcons.heart,
                      color: controller.isFavorite
                          ? Colors.redAccent
                          : Colors.white,
                    ),
                    onPressed: controller.toggleFavorite,
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
}
