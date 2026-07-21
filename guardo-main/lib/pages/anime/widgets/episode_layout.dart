import 'package:flutter/material.dart';
import '../../../models/app_models.dart';
import 'episode_widgets.dart';

class EpisodeLayout extends StatelessWidget {
  final List<EpisodeInfo> episodes;
  final Map<int, TvdbEpisode> tvdbEpisodes;
  final WatchEntry? watchEntry;
  final String fallbackImageUrl;
  final Function(int episodeNumber) onEpisodeTap;

  const EpisodeLayout({
    super.key,
    required this.episodes,
    required this.tvdbEpisodes,
    this.watchEntry,
    required this.fallbackImageUrl,
    required this.onEpisodeTap,
  });

  String? _getEpisodeImage(EpisodeInfo episode) {
    final tvdb = tvdbEpisodes[episode.number];
    final String? tvdbStill = tvdb?.stillPath;
    
    if (tvdbStill != null && tvdbStill.isNotEmpty) return tvdbStill;
    final image = episode.image;
    if (image != null && image.isNotEmpty) return image;
    if (fallbackImageUrl.isNotEmpty) return fallbackImageUrl;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Text(
            'No hay episodios disponibles para esta temporada.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return _buildEpisodesGrid(context, episodes: episodes, isLarge: false);
  }

  Widget _buildEpisodesGrid(BuildContext context,
      {required List<EpisodeInfo> episodes, required bool isLarge}) {
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount;

    if (isLarge) {
      crossAxisCount = width > 1600 ? 3 : (width > 1000 ? 2 : 1);
    } else {
      crossAxisCount = width > 1600 ? 3 : (width > 1100 ? 2 : 1);
    }

    final double aspectRatio =
        isLarge ? 1.35 : (width / (crossAxisCount * 130)).clamp(2.5, 5.0);

    final aired = <EpisodeInfo>[];
    final upcoming = <EpisodeInfo>[];

    for (final ep in episodes) {
      bool isUpcoming = false;
      if (ep.airDate != null) {
        try {
          final date = DateTime.parse(ep.airDate!);
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          isUpcoming = date.isAfter(today);
        } catch (_) {}
      }
      if (isUpcoming) upcoming.add(ep); else aired.add(ep);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (aired.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: aspectRatio,
              crossAxisSpacing: 32,
              mainAxisSpacing: isLarge ? 24 : 8,
            ),
            itemCount: aired.length,
            itemBuilder: (context, index) {
              final ep = aired[index];
              final tvdb = tvdbEpisodes[ep.number];
              final isWatched = (watchEntry?.watchedEpisodes ?? []).contains(ep.number);
              final imageUrl = _getEpisodeImage(ep);

              if (isLarge) {
                return EpisodeGridCard(
                  episode: ep,
                  tvdbEpisode: tvdb,
                  isWatched: isWatched,
                  imageUrl: imageUrl,
                  isLarge: true,
                  onTap: () => onEpisodeTap(ep.number),
                );
              } else {
                return EpisodeListCard(
                  episode: ep,
                  tvdbEpisode: tvdb,
                  isWatched: isWatched,
                  imageUrl: imageUrl,
                  onTap: () => onEpisodeTap(ep.number),
                );
              }
            },
          ),
        if (aired.isNotEmpty && upcoming.isNotEmpty)
          const SizedBox(height: 24),
        if (upcoming.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: upcoming.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ep = upcoming[index];
              return UpcomingEpisodeCard(
                episode: ep,
                onTap: () => onEpisodeTap(ep.number),
              );
            },
          ),
      ],
    );
  }
}
