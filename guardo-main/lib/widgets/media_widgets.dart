import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:async';
import 'package:anityng/widgets/tv_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'media_preview.dart';
import '../services/api_service.dart';

class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.05, end: 0.12).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class AppCachedImage extends StatelessWidget {
  const AppCachedImage(
    this.imageUrl, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.memCacheWidth,
    this.errorWidget,
    this.showPlaceholderBg = true,
    this.filterQuality = FilterQuality.medium,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final int? memCacheWidth;
  final Widget? errorWidget;
  final bool showPlaceholderBg;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: showPlaceholderBg ? Colors.white10 : Colors.transparent,
        child: errorWidget ?? const Icon(Icons.broken_image, size: 20),
      );
    }

    if (imageUrl.startsWith('assets/')) {
      if (imageUrl.toLowerCase().endsWith('.svg')) {
        return SvgPicture.asset(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
        );
      }
      return Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: showPlaceholderBg ? Colors.white10 : Colors.transparent,
          child: errorWidget ?? const Icon(Icons.broken_image, size: 20),
        ),
      );
    }

    if (imageUrl.toLowerCase().contains('.svg') || imageUrl.toLowerCase().contains('vector')) {
      return SvgPicture.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        placeholderBuilder: (context) => Container(
          width: width,
          height: height,
          color: showPlaceholderBg ? Colors.white10 : Colors.transparent,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: showPlaceholderBg ? Colors.white10 : Colors.transparent,
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: showPlaceholderBg ? Colors.white10 : Colors.transparent,
        child: errorWidget ?? const Icon(Icons.broken_image, size: 20),
      ),
    );
  }
}

class MediaCard extends StatefulWidget {
  const MediaCard({
    super.key,
    required this.item,
    required this.onTap,
    this.compact = false,
    this.useBackdrop = false,
    this.heroTagPrefix = 'preview',
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final bool compact;
  final bool useBackdrop;
  final String heroTagPrefix;

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final id = (widget.item['id'] as num?)?.toInt();
    if (id != null) {
      ApiService.instance.cacheMedia(id, widget.item);
    }
    final title = widget.item['title']?['romaji'] ??
        widget.item['title']?['english'] ??
        'Anime';
    final image = (widget.useBackdrop
            ? (widget.item['bannerImage'] ?? widget.item['coverImage']?['extraLarge'])
            : (widget.item['coverImage']?['extraLarge'] ??
                widget.item['coverImage']?['large'])) ??
        '';

    final logo = widget.item['customLogo'] as String?;
    final format = widget.item['format']?.toString().replaceAll('_', ' ') ?? '';
    final episodes = widget.item['episodes']?.toString();
    final year = widget.item['startDate']?['year'] ?? widget.item['seasonYear'];
    final status = widget.item['status']?.toString().replaceAll('_', ' ');
    final hexColor = widget.item['coverImage']?['color'] as String?;
    Color? focusColor;
    if (hexColor != null && hexColor.startsWith('#')) {
      try {
        focusColor = Color(int.parse(hexColor.substring(1), radix: 16) + 0xFF000000);
      } catch (_) {}
    }

    final isDesktop = defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;

    final card = AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: widget.useBackdrop
                  ? (widget.compact ? 280 : 320)
                  : (widget.compact ? 120 : 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TVFocusWrapper(
                    onTap: widget.onTap,
                    onLongPress: () => _showPreview(context),
                    borderRadius: 12,
                    focusColor: focusColor,
                    showBorder: true,
                    showGlow: false,
                    scaleOnFocus: 1.08,
                    child: AspectRatio(
                      aspectRatio: widget.useBackdrop ? 16 / 9 : 2 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            image.isEmpty
                                ? Container(color: Colors.white10)
                                : Hero(
                                    tag: '${widget.heroTagPrefix}-${widget.item['id']}',
                                    child: AppCachedImage(
                                      image,
                                      fit: BoxFit.cover,
                                      memCacheWidth: widget.useBackdrop ? 700 : 350,
                                    ),
                                  ),
                            
                            // Glass Badges
                            if (!widget.useBackdrop) ...[
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (format.isNotEmpty)
                                      _buildGlassBadge(format),
                                    if (format.isNotEmpty && episodes != null)
                                      const SizedBox(width: 4),
                                    if (episodes != null)
                                      _buildGlassBadge('$episodes Ep'),
                                  ],
                                ),
                              ),
                            ],

                            if (widget.useBackdrop) ...[
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.9),
                                        Colors.black.withValues(alpha: 0.4),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.4, 0.7],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (logo != null && logo.isNotEmpty)
                                      AppCachedImage(
                                        logo,
                                        height: 45,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.bottomLeft,
                                        showPlaceholderBg: false,
                                      )
                                    else
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                    if (!widget.useBackdrop) ...[
                      const SizedBox(height: 10),
                      Hero(
                        tag: '${widget.heroTagPrefix}-title-${widget.item['id']}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${year ?? ''}${year != null && status != null ? ' · ' : ''}${status ?? ''}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

    if (!isDesktop) return card;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: card,
    );
  }

  Widget _buildGlassBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showPreview(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) => MediaPreviewDialog(item: widget.item),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: curve,
            child: child,
          ),
        );
      },
    );
  }
}

class MediaSection extends StatelessWidget {
  const MediaSection({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
    this.useBackdrop = false,
    this.heroTagPrefix,
  });

  final String title;
  final List<dynamic> items;
  final void Function(Map<String, dynamic> item, String posterHeroTag, String titleHeroTag) onItemTap;
  final bool useBackdrop;
  final String? heroTagPrefix;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
          ),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: useBackdrop ? 220 : 330,
          child: ListView.separated(
            clipBehavior: Clip.hardEdge,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(
              left: 16,
              right: 32,
            ),
            itemBuilder: (context, index) {
              final item = Map<String, dynamic>.from(items[index] as Map);
              final prefix = heroTagPrefix ?? title.toLowerCase().replaceAll(' ', '-');
              final posterTag = '$prefix-${item['id']}';
              final titleTag = '$prefix-title-${item['id']}';
              return MediaCard(
                item: item,
                onTap: () => onItemTap(item, posterTag, titleTag),
                useBackdrop: useBackdrop,
                heroTagPrefix: prefix,
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 20),
            itemCount: items.length,
          ),
        ),
      ],
    );
  }
}

class EntranceFader extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final int delay;
  final Offset offset;

  const EntranceFader({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = 0,
    this.offset = const Offset(0, 10),
  });

  @override
  State<EntranceFader> createState() => _EntranceFaderState();
}

class _EntranceFaderState extends State<EntranceFader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _offset = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.delay > 0) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: AnimatedBuilder(
        animation: _offset,
        builder: (context, child) {
          return Transform.translate(
            offset: _offset.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
