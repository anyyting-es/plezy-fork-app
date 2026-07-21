import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../widgets/media_widgets.dart';
import '../../../models/app_models.dart';

class EpisodeGridCard extends StatefulWidget {
  final EpisodeInfo episode;
  final TvdbEpisode? tvdbEpisode;
  final bool isWatched;
  final String? imageUrl;
  final VoidCallback onTap;
  final bool isLarge;

  const EpisodeGridCard({
    super.key,
    required this.episode,
    required this.tvdbEpisode,
    required this.isWatched,
    this.imageUrl,
    required this.onTap,
    this.isLarge = false,
  });

  @override
  State<EpisodeGridCard> createState() => _EpisodeGridCardState();
}

class _EpisodeGridCardState extends State<EpisodeGridCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tvdb = widget.tvdbEpisode;
    final image = widget.imageUrl;
    final isWatched = widget.isWatched;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isWatched ? 0.4 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: image != null
                          ? AppCachedImage(image, fit: BoxFit.cover)
                          : Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(LucideIcons.film,
                                  size: 32,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5)),
                            ),
                    ),
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              _isHovered
                                  ? Colors.black.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isWatched)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                )
                              ]),
                          child: const Icon(LucideIcons.check,
                              size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                (widget.episode.title.trim().isNotEmpty && !widget.episode.title.startsWith('Episodio'))
                    ? widget.episode.title.trim()
                    : (tvdb?.name ?? 'Episodio ${widget.episode.number}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Episodio ${widget.episode.number}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (tvdb?.runtime != null)
                    Text(
                      '${tvdb!.runtime}m',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  if (widget.episode.airDate != null) ...[
                    if (tvdb?.runtime != null) const SizedBox(width: 8),
                    _AirDateBadge(airDate: widget.episode.airDate!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AirDateBadge extends StatelessWidget {
  final String airDate;
  const _AirDateBadge({required this.airDate});

  String _format(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = date.difference(today).inDays;

      if (diff < 0) return ''; // No mostrar para el pasado
      if (diff == 0) return 'HOY';
      if (diff == 1) return 'MAÑANA';
      
      final months = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
      return '${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _format(airDate);
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class EpisodeListCard extends StatefulWidget {
  final EpisodeInfo episode;
  final TvdbEpisode? tvdbEpisode;
  final bool isWatched;
  final String? imageUrl;
  final VoidCallback onTap;

  const EpisodeListCard({
    super.key,
    required this.episode,
    required this.tvdbEpisode,
    required this.isWatched,
    this.imageUrl,
    required this.onTap,
  });

  @override
  State<EpisodeListCard> createState() => _EpisodeListCardState();
}

class _EpisodeListCardState extends State<EpisodeListCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tvdb = widget.tvdbEpisode;
    final image = widget.imageUrl;
    final isWatched = widget.isWatched;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isWatched ? 0.4 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Imagen que sobresale por arriba y abajo
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: SizedBox(
                    width: 170,
                    height: 122,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 170,
                            height: 100,
                            child: image != null
                                ? AppCachedImage(image, fit: BoxFit.cover)
                                : Container(
                                    color: colorScheme.surfaceContainerHighest,
                                    child: Icon(LucideIcons.film,
                                        size: 32,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.5)),
                                  ),
                          ),
                        ),
                        if (isWatched)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    )
                                  ]),
                              child: const Icon(LucideIcons.check,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Ep ${widget.episode.number}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (tvdb?.runtime != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${tvdb!.runtime}m',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (widget.episode.airDate != null) ...[
                            const SizedBox(width: 8),
                            _AirDateBadge(airDate: widget.episode.airDate!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (widget.episode.title.trim().isNotEmpty && !widget.episode.title.startsWith('Episodio'))
                            ? widget.episode.title.trim()
                            : (tvdb?.name ?? 'Episodio ${widget.episode.number}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.episode.description?.isNotEmpty == true || (tvdb?.overview != null && tvdb!.overview.isNotEmpty))
                        const SizedBox(height: 3),
                      if (widget.episode.description?.isNotEmpty == true || (tvdb?.overview != null && tvdb!.overview.isNotEmpty))
                        Text(
                          widget.episode.description ?? tvdb!.overview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class UpcomingEpisodeCard extends StatelessWidget {
  final EpisodeInfo episode;
  final VoidCallback onTap;

  const UpcomingEpisodeCard({
    super.key,
    required this.episode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Episodio ${episode.number}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            if (episode.airDate != null)
              _AirDateBadge(airDate: episode.airDate!),
          ],
        ),
      ),
    );
  }
}
