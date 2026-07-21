import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../manga_reader_page.dart';

/// Widget que renderiza cada página/imagen del manga
class ReaderPageItem extends StatefulWidget {
  final String url;
  final int index;
  final ReadingMode mode;

  const ReaderPageItem({
    super.key,
    required this.url,
    required this.index,
    required this.mode,
  });

  @override
  State<ReaderPageItem> createState() => _ReaderPageItemState();
}

class _ReaderPageItemState extends State<ReaderPageItem>
    with AutomaticKeepAliveClientMixin {
  
  Size? _imageSize;
  bool _isLongStrip = false;

  @override
  bool get wantKeepAlive => true;

  void _resolveImageSize() {
    if (_imageSize != null) return;
    
    final ImageProvider provider = CachedNetworkImageProvider(widget.url);
    provider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _imageSize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
            _isLongStrip = _imageSize!.height > (_imageSize!.width * 1.5);
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.url.isEmpty || !widget.url.startsWith('http')) {
      return ReaderErrorWidget(
        url: widget.url,
        onRetry: () => setState(() {}),
        errorText: widget.url.isEmpty ? 'URL vacía' : 'URL inválida',
      );
    }

    _resolveImageSize();

    final fit = (widget.mode == ReadingMode.vertical || _isLongStrip)
        ? BoxFit.fitWidth
        : BoxFit.contain;

    return CachedNetworkImage(
      imageUrl: widget.url,
      fit: fit,
      width: double.infinity,
      alignment: Alignment.topCenter,
      fadeInDuration: const Duration(milliseconds: 150),
      memCacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).toInt().clamp(0, 1440),
      placeholder: (context, url) => Container(
        height: _isLongStrip ? 800 : 500,
        color: Colors.white.withValues(alpha: 0.02),
        child: Center(
          child: SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => ReaderErrorWidget(
        url: url,
        onRetry: () => setState(() {}),
      ),
      imageBuilder: (context, imageProvider) {
        Widget imageWidget = Image(
          image: imageProvider,
          fit: fit,
          width: double.infinity,
          alignment: Alignment.topCenter,
        );

        if (widget.mode == ReadingMode.horizontal && _isLongStrip) {
          imageWidget = SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: imageWidget,
          );
        }

        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: imageWidget,
        );
      },
    );
  }
}

/// Widget de error con botón de reintento
class ReaderErrorWidget extends StatelessWidget {
  final String url;
  final VoidCallback onRetry;
  final String? errorText;

  const ReaderErrorWidget({
    super.key,
    required this.url,
    required this.onRetry,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.white.withValues(alpha: 0.03),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.imageOff, color: Colors.white.withValues(alpha: 0.2), size: 28),
            const SizedBox(height: 12),
            Text(
              errorText ?? 'Error al cargar',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (url.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  CachedNetworkImage.evictFromCache(url);
                  onRetry();
                },
                icon: Icon(LucideIcons.refreshCw, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                label: Text(
                  'Reintentar',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
