import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../../widgets/media_widgets.dart';

class AnimeBackground extends StatelessWidget {
  final String imageUrl;
  final double overlayOpacity;
  final Color surfaceColor;
  final bool blur;

  const AnimeBackground({
    super.key,
    required this.imageUrl,
    required this.overlayOpacity,
    required this.surfaceColor,
    this.blur = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Stack(
      children: [
        Positioned.fill(
          child: imageUrl.isNotEmpty
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    AppCachedImage(
                      imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                    if (blur)
                      ClipRect(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                  ],
                )
              : Container(color: colorScheme.surfaceContainerHighest),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: overlayOpacity),
                    Colors.black.withValues(alpha: (overlayOpacity + 0.05).clamp(0.0, 1.0)),
                    surfaceColor.withValues(alpha: 0.98),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
