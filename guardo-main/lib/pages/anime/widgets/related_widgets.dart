import 'package:flutter/material.dart';
import '../../../widgets/media_widgets.dart';
import '../../../services/api_service.dart';

class RelatedCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const RelatedCard({super.key, required this.item, required this.onTap});

  @override
  State<RelatedCard> createState() => _RelatedCardState();
}

class _RelatedCardState extends State<RelatedCard> {
  @override
  Widget build(BuildContext context) {
    final id = (widget.item['id'] as num?)?.toInt();
    if (id != null) {
      ApiService.instance.cacheMedia(id, widget.item);
    }
    final title = (widget.item['title']?['romaji'] as String?) ??
                  (widget.item['title']?['english'] as String?) ??
                  'Sin título';
    final image = (widget.item['coverImage']?['large'] as String?) ??
                  (widget.item['coverImage']?['extraLarge'] as String?) ??
                  '';
    final label = widget.item['relationLabel'] as String? ?? '';
    final format = widget.item['format'] as String? ?? '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'related-poster-${widget.item['id']}',
                        child: AppCachedImage(
                          image,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                        ),
                      ),
                      if (label.isNotEmpty)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      if (format.isNotEmpty)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              format,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
