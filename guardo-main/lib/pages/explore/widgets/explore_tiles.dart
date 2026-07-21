import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/media_widgets.dart';

class ExploreMediaListTile extends StatelessWidget {
  const ExploreMediaListTile({
    super.key,
    required this.title,
    required this.image,
    required this.genres,
    this.score,
    required this.format,
    this.year,
    required this.status,
    required this.onTap,
  });

  final String title;
  final String image;
  final List<String> genres;
  final double? score;
  final String format;
  final int? year;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final panelBg = scheme.onSurface.withValues(alpha: 0.06);
    final panelBorder = scheme.onSurface.withValues(alpha: 0.10);
    final subtleText = scheme.onSurface.withValues(alpha: 0.62);
    final mutedText = scheme.onSurface.withValues(alpha: 0.48);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Container(
          height: 124,
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: panelBorder),
          ),
          child: RepaintBoundary(
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  height: double.infinity,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(10),
                    ),
                    child: AppCachedImage(
                      image,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          genres.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: subtleText,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            if (score != null) ...[
                              Icon(Icons.star, size: 12, color: scheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                score!.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            const Spacer(),
                            Flexible(
                              child: Text(
                                '$format · ${year ?? '—'} · $status',
                                style: TextStyle(
                                  color: mutedText,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class ExploreMediaCompactTile extends StatelessWidget {
  const ExploreMediaCompactTile({
    super.key,
    required this.title,
    required this.image,
    this.score,
    required this.leftMeta,
    required this.rightMeta,
    required this.onTap,
  });

  final String title;
  final String image;
  final double? score;
  final String leftMeta;
  final String rightMeta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final panelBg = scheme.onSurface.withValues(alpha: 0.06);
    final panelBorder = scheme.onSurface.withValues(alpha: 0.10);
    final mutedText = scheme.onSurface.withValues(alpha: 0.48);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(child: Container()),
            Container(
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: panelBorder,
                ),
              ),
              child: RepaintBoundary(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AppCachedImage(
                          image,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (score != null) ...[
                                Icon(Icons.star, size: 10, color: scheme.primary),
                                const SizedBox(width: 2),
                                Text(
                                  score!.toStringAsFixed(1),
                                  style: TextStyle(fontSize: 10, color: mutedText, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  leftMeta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10, color: mutedText),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
