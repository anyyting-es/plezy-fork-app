import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../mpv/models.dart';
import '../../mpv/video.dart';
import 'package:webview_windows/webview_windows.dart' if (dart.library.html) 'package:anityng/stubs/webview_windows_stub.dart';
import '../../models/app_models.dart' as models;
import 'logic/watch_controller.dart';
import 'widgets/watch_busy_overlays.dart';
import 'widgets/torrent_selector_sheet.dart';
import 'widgets/player_controls.dart';
import '../../widgets/media_widgets.dart';

import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../services/api_service.dart';

class WatchPage extends StatefulWidget {
  final String providerId;
  final Map<String, dynamic> anime;
  final List<models.EpisodeInfo> episodes;
  final Map<int, models.TvdbEpisode> tvdbEpisodes;
  final int initialEpisodeNumber;
  final String audioMode;
  final double? resumeTime;
  final models.StreamLink? initialStream;

  const WatchPage({
    super.key,
    required this.providerId,
    required this.anime,
    required this.episodes,
    required this.tvdbEpisodes,
    required this.initialEpisodeNumber,
    this.audioMode = 'sub',
    this.resumeTime,
    this.initialStream,
  });

  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> {
  late final WatchController _controller;
  IconData? _feedbackIcon;
  String? _feedbackText;
  Timer? _feedbackTimer;
  bool _isAfk = false;
  Timer? _afkTimer;
  DateTime? _lastTapTime;
  Timer? _singleTapTimer;

  void _resetAfk() {
    _afkTimer?.cancel();
    if (_isAfk) {
      setState(() => _isAfk = false);
    }
    if (!_controller.playing) {
      _afkTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && !_controller.playing) {
          setState(() => _isAfk = true);
        }
      });
    }
  }

  void _showFeedback(IconData icon, [String? text]) {
    setState(() {
      _feedbackIcon = icon;
      _feedbackText = text;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _feedbackIcon = null;
          _feedbackText = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = WatchController(
      initialProviderId: widget.providerId,
      anime: widget.anime,
      episodes: widget.episodes,
      tvdbEpisodes: widget.tvdbEpisodes,
      initialEpisodeNumber: widget.initialEpisodeNumber,
      initialAudioMode: widget.audioMode,
      resumeTime: widget.resumeTime,
      initialStream: widget.initialStream,
    );
    _controller.init();
    _controller.addListener(_handleControllerState);
    WakelockPlus.enable();
    // Forzar landscape al entrar al reproductor
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _handleControllerState() {
    if (_controller.playing) {
      _afkTimer?.cancel();
      if (_isAfk) setState(() => _isAfk = false);
    } else {
      _resetAfk();
    }

    final bool isEmpty = _controller.useWebViewPlayer
      ? (_controller.webviewController == null || !_controller.isWebviewInitialized)
      : _controller.useNativePlayer
        ? (_controller.vpController == null || !_controller.vpController!.value.isInitialized)
        : (_controller.player == null);

    if (_controller.currentProviderId.startsWith('torrent') && 
        _controller.loading == false && 
        isEmpty &&
        !_controller.rdResolving &&
        _controller.error == null) {
      // Trigger picker if we are in a torrent provider but not playing anything yet
      // This is a bit simplified, usually we'd have a specific state for this.
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _controller.removeListener(_handleControllerState);
    _controller.dispose();
    _feedbackTimer?.cancel();
    _afkTimer?.cancel();
    _singleTapTimer?.cancel();
    
    // Restaurar orientación portrait y UI del sistema al salir
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    
    super.dispose();
  }

  void _onEpisodeTap(int epNum) async {
    final ep = _controller.episodes.firstWhere((e) => e.number == epNum);
    if (_controller.currentProviderId == 'torrent') {
      _controller.currentEpNum = epNum;
      _controller.loading = false;
      _controller.error = null;
      
      final selectedStream = await _pickTorrentStream();
      if (selectedStream != null) {
        final magnet = selectedStream.headers?['magnet'];
        if (magnet != null) {
          final info = await ApiService.instance.torrent.addTorrent(magnet);
          if (info != null && mounted) {
            final tvdb = _controller.tvdbEpisodes[_controller.currentEpNum];
            ApiService.instance.torrent.setEpisodeMetadata(
              episodeId: 'download-${widget.anime['id']}-${_controller.currentEpNum}',
              number: _controller.currentEpNum.toDouble(),
              title: tvdb?.name ?? ep.title,
              coverImage: tvdb?.stillPath ?? ep.image ?? widget.anime['coverImage']?['large'],
              synopsis: tvdb?.overview,
              infoHash: info.infoHash,
              torrentName: info.name,
            );
          }
        }
        _controller.playStream(selectedStream);
      }
    } else {
      _controller.loadEpisode(epNum);
    }
  }

  Future<models.StreamLink?> _pickTorrentStream() async {
    final Future<List<models.StreamLink>> streamsFuture;
    if (_controller.currentProviderId == 'torrentio') {
      streamsFuture = _controller.fetchTorrentioStreams();
    } else if (_controller.currentProviderId == 'torrent') {
      final anidbId = widget.anime['anidbEpisodeMap']?[_controller.currentEpNum] ?? widget.anime['anidbId'];
      streamsFuture = ApiService.instance.torrent.getStreams(
        jsonEncode({
          'type': 'torrent',
          'anilistId': widget.anime['id'],
          'episode': _controller.currentEpNum,
          'anidbId': anidbId,
        }),
      );
    } else {
      return null; 
    }

    return await showModalBottomSheet<models.StreamLink>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TorrentSelectorSheet(
        streamsFuture: streamsFuture,
        anime: widget.anime,
        episodes: widget.episodes,
        currentEpisodeNumber: _controller.currentEpNum,
        currentProviderId: _controller.currentProviderId,
        onEpisodeChanged: (ep) async {
          if (_controller.currentProviderId == 'torrent') {
            Navigator.pop(ctx);
            // Will let the side panel's tap logic handle showing it again for the new episode
            _onEpisodeTap(ep);
          } else {
            _controller.loadEpisode(ep);
          }
        },
        onProviderChanged: (p) => {},
        useRealDebrid: _controller.useRealDebrid,
        onRealDebridChanged: (v) => setState(() => _controller.useRealDebrid = v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final controller = _controller;
        final isWide = MediaQuery.of(context).size.width > 800;

        Widget videoWidget = controller.useWebViewPlayer
          ? (controller.webviewController != null && controller.isWebviewInitialized
              ? Stack(
                  children: [
                    Webview(controller.webviewController!),
                    if (!controller.webviewHasVideo)
                      const ColoredBox(
                        color: Colors.black,
                        child: Center(child: CircularProgressIndicator(color: Colors.white)),
                      ),
                  ],
                )
              : const ColoredBox(
                  color: Colors.black,
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ))
          : controller.useNativePlayer
              ? (controller.vpController != null && controller.vpController!.value.isInitialized
                  ? VideoPlayer(controller.vpController!)
                  : const Center(child: CircularProgressIndicator(color: Colors.white)))
              : (controller.player != null
                  ? Video(player: controller.player!)
                  : const Center(child: CircularProgressIndicator(color: Colors.white)));

        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            _resetAfk();
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                final target = controller.displayPosition + const Duration(seconds: 5);
                controller.seekTo(target);
                _showFeedback(LucideIcons.fastForward, _fmt(target));
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                final target = controller.displayPosition - const Duration(seconds: 5);
                controller.seekTo(target);
                _showFeedback(LucideIcons.rewind, _fmt(target));
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.space) {
                final willPlay = !controller.playing;
                controller.togglePlay();
                _showFeedback(willPlay ? LucideIcons.play : LucideIcons.pause);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
                final wasMuted = controller.volume == 0;
                controller.setVolume(wasMuted ? 100 : 0);
                _showFeedback(wasMuted ? LucideIcons.volume2 : LucideIcons.volumeX);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
            backgroundColor: ((Platform.isAndroid || Platform.isWindows) && !controller.useNativePlayer && !controller.useWebViewPlayer)
                ? Colors.transparent
                : Colors.black,
            body: MouseRegion(
              onHover: (_) {
                _resetAfk();
                if (!controller.showControls) controller.showControlsForce();
                controller.startHideTimer();
              },
              onEnter: (_) {
                _resetAfk();
                controller.showControlsForce();
                controller.startHideTimer();
              },
              onExit: (_) {
                _resetAfk();
                controller.hideControls();
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final now = DateTime.now();
                  if (_lastTapTime != null && now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
                    _lastTapTime = null;
                    _singleTapTimer?.cancel();
                    final width = MediaQuery.of(context).size.width;
                    final x = details.globalPosition.dx;
                    if (x < width / 3) {
                      final target = controller.displayPosition - const Duration(seconds: 5);
                      controller.seekTo(target);
                      _showFeedback(LucideIcons.rewind, _fmt(target));
                    } else if (x > width * 2 / 3) {
                      final target = controller.displayPosition + const Duration(seconds: 5);
                      controller.seekTo(target);
                      _showFeedback(LucideIcons.fastForward, _fmt(target));
                    } else {
                      final willPlay = !controller.playing;
                      controller.togglePlay();
                      _showFeedback(willPlay ? LucideIcons.play : LucideIcons.pause);
                      _resetAfk();
                    }
                  } else {
                    _lastTapTime = now;
                    _singleTapTimer?.cancel();
                    _singleTapTimer = Timer(const Duration(milliseconds: 300), () {
                      if ((Platform.isAndroid || Platform.isIOS) && !controller.isSettingsOpen) {
                        controller.toggleControls();
                      }
                    });
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── Video surface fills the entire screen ──
                    RepaintBoundary(child: videoWidget),

                    // ── AFK/idle overlay ──
                    IgnorePointer(
                      ignoring: !_isAfk,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        opacity: _isAfk ? 1.0 : 0.0,
                        child: _buildAfkOverlay(controller, isWide),
                      ),
                    ),

                    // ── Controls overlay ──
                    IgnorePointer(
                      ignoring: !controller.showControls,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: controller.showControls ? 1.0 : 0.0,
                        child: _buildControls(controller, isWide),
                      ),
                    ),

                    // ── Loading / error overlays ──
                    WatchBusyOverlays(
                      loading: controller.loading,
                      error: controller.error,
                      rdResolving: controller.rdResolving,
                      rdStatusMessage: controller.rdStatusMessage,
                      onRetry: () => controller.loadEpisode(controller.currentEpNum),
                      onBack: () => Navigator.pop(context),
                    ),

                    // ── Seek / play feedback icon ──
                    if (_feedbackIcon != null)
                      Center(
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(_feedbackIcon),
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Opacity(
                                opacity: (1.0 - (value - 1.0).abs()).clamp(0.0, 1.0),
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(isWide ? 20 : 14),
                                      decoration: const BoxDecoration(
                                        color: Colors.black45,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(_feedbackIcon, color: Colors.white, size: isWide ? 40 : 28),
                                    ),
                                    if (_feedbackText != null)
                                      Positioned(
                                        bottom: isWide ? -34 : -26,
                                        child: Text(
                                          _feedbackText!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isWide ? 16 : 13,
                                            fontWeight: FontWeight.bold,
                                            shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onNextEpisode() {
    final nextEpNum = _controller.currentEpNum + 1;
    if (widget.episodes.any((e) => e.number == nextEpNum)) {
      _onEpisodeTap(nextEpNum);
    }
  }

  Widget _buildControls(WatchController controller, bool isWide) {
    return PlayerControls(
      controller: controller,
      animeTitle: widget.anime['title']?['romaji'] ?? widget.anime['title']?['english'] ?? 'Anime',
      isWide: isWide,
      onToggleFullscreen: controller.toggleFullscreen,
      onBack: () => Navigator.pop(context),
      onNextEpisode: _onNextEpisode,
    );
  }



  Widget _buildAfkOverlay(WatchController controller, bool isWide) {
    final tvdb = controller.tvdbEpisodes[controller.currentEpNum];
    final title = widget.anime['title']?['romaji'] ?? widget.anime['title']?['english'] ?? 'Anime';
    final logoToShow = widget.anime['logoImage']?.toString();
    
    final epTitle = "EPISODIO ${controller.currentEpNum} : ${tvdb?.name ?? 'Sin título'}";
    final rating = tvdb?.voteAverage != null && tvdb!.voteAverage > 0 
        ? tvdb!.voteAverage.toStringAsFixed(1) 
        : "";
    final runtime = tvdb?.runtime != null 
        ? "${tvdb!.runtime} min" 
        : "";
    final airDate = tvdb?.airDate ?? "";
    final synopsis = tvdb?.overview ?? widget.anime['description'] ?? '';
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.65),
            Colors.black.withOpacity(0.2),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (logoToShow != null && logoToShow.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: isWide ? 24 : 16),
              child: AppCachedImage(
                logoToShow,
                height: isWide ? 160 : 70,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                showPlaceholderBg: false,
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 700 : 250),
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isWide ? 52 : 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
            ),
          
          Text(
            epTitle.toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: isWide ? 24 : 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          
          if (rating.isNotEmpty || runtime.isNotEmpty || airDate.isNotEmpty) ...[
            SizedBox(height: isWide ? 14 : 8),
            Row(
              children: [
                if (rating.isNotEmpty) ...[
                  Icon(LucideIcons.star, color: Colors.amber, size: isWide ? 18 : 14),
                  const SizedBox(width: 4),
                  Text(
                    rating,
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: isWide ? 18 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: isWide ? 20 : 12),
                ],
                if (runtime.isNotEmpty) ...[
                  Icon(LucideIcons.clock, color: Colors.white70, size: isWide ? 18 : 14),
                  const SizedBox(width: 4),
                  Text(
                    runtime,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isWide ? 18 : 12,
                    ),
                  ),
                  SizedBox(width: isWide ? 20 : 12),
                ],
                if (airDate.isNotEmpty) ...[
                  Icon(LucideIcons.calendar, color: Colors.white70, size: isWide ? 18 : 14),
                  const SizedBox(width: 4),
                  Text(
                    airDate,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isWide ? 18 : 12,
                    ),
                  ),
                ],
              ],
            ),
          ],
          
          SizedBox(height: isWide ? 32 : 20),
          if (synopsis.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 600 : 300),
              child: Text(
                synopsis.replaceAll(RegExp(r'<[^>]*>'), ''),
                maxLines: isWide ? 6 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: isWide ? 17 : 12,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class FullWidthSliderTrackShape extends RoundedRectSliderTrackShape {
  const FullWidthSliderTrackShape();
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + parentBox.size.height - trackHeight;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
