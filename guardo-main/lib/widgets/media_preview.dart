import 'package:anityng/widgets/media_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../mpv/player/player.dart';
import '../mpv/models.dart' as mpv_models;
import '../mpv/video.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

class MediaPreviewDialog extends StatefulWidget {
  final Map<String, dynamic> item;

  const MediaPreviewDialog({super.key, required this.item});

  @override
  State<MediaPreviewDialog> createState() => _MediaPreviewDialogState();
}

class _MediaPreviewDialogState extends State<MediaPreviewDialog> {
  late final Player _player;
  bool _isPlaying = false;
  bool _loadingTrailer = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player(useExoPlayer: false);
    _checkAndPlayTrailer();
  }

  Future<void> _checkAndPlayTrailer() async {
    final trailer = widget.item['trailer'];
    if (trailer != null && trailer['site'] == 'youtube') {
      setState(() => _loadingTrailer = true);
      try {
        final ytInstance = yt.YoutubeExplode();
        final videoId = trailer['id'];
        final manifest = await ytInstance.videos.streamsClient.getManifest(videoId);
        final streamInfo = manifest.muxed.withHighestBitrate();
        
        await _player.open(mpv_models.Media(streamInfo.url.toString()));
        _player.setVolume(0); // Mute by default for preview
        _player.setProperty('loop', 'inf');
        
        if (mounted) {
          setState(() {
            _isPlaying = true;
            _loadingTrailer = false;
          });
        }
        ytInstance.close();
      } catch (e) {
        if (mounted) {
          setState(() {
            _loadingTrailer = false;
            _error = 'No se pudo cargar el tráiler';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item['title']?['romaji'] ?? widget.item['title']?['english'] ?? 'Anime';
    final banner = widget.item['bannerImage'] ?? widget.item['coverImage']?['extraLarge'] ?? '';
    final poster = widget.item['coverImage']?['extraLarge'] ?? widget.item['coverImage']?['large'] ?? '';
    final score = widget.item['averageScore'] != null ? (widget.item['averageScore'] as num) / 10 : null;
    final year = widget.item['seasonYear'];
    final genres = (widget.item['genres'] as List?)?.cast<String>() ?? [];
    final description = (widget.item['description'] as String?)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxWidth: 800),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 50,
              spreadRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Player/Banner
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _isPlaying
                          ? Video(player: _player)
                          : AppCachedImage(
                              banner.isNotEmpty ? banner : poster,
                              fit: BoxFit.cover,
                            ),
                    ),
                    if (_loadingTrailer)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white24),
                        ),
                      ),
                    if (_isPlaying)
                      Positioned(
                        top: 20,
                        right: 20,
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              final vol = _player.state.volume;
                              _player.setVolume(vol == 0 ? 100 : 0);
                            });
                          },
                          icon: Icon(
                            _player.state.volume == 0 ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(backgroundColor: Colors.black45),
                        ),
                      ),
                  ],
                ),

                // Info Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            if (score != null) ...[
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                score.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            if (year != null) ...[
                              Text(
                                year.toString(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            if (widget.item['status'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white38),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.item['status'].toString().replaceAll('_', ' '),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: genres.map((g) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            g,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        description,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                          height: 1.5,
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
