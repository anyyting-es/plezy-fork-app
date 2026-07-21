import 'package:flutter/material.dart';

class GenresWrap extends StatelessWidget {
  final List<String> genres;
  final ColorScheme colorScheme;
  final bool centered;

  const GenresWrap({
    super.key,
    required this.genres,
    required this.colorScheme,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      children: genres.map((genre) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            genre.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class AnimeMetadata extends StatelessWidget {
  final String score;
  final String metadata;
  final bool isDesktop;
  final bool centered;

  const AnimeMetadata({
    super.key,
    required this.score,
    required this.metadata,
    required this.isDesktop,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
        const SizedBox(width: 4),
        Text(
          score,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '•  $metadata',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class AnimeSynopsis extends StatefulWidget {
  final String description;

  const AnimeSynopsis({super.key, required this.description});

  @override
  State<AnimeSynopsis> createState() => _AnimeSynopsisState();
}

class _AnimeSynopsisState extends State<AnimeSynopsis> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Text(
          widget.description.isNotEmpty ? widget.description : 'Sin sinopsis disponible.',
          textAlign: TextAlign.start,
          maxLines: _isExpanded ? null : 3, // Shorter initial view
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.5,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
