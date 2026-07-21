import 'package:flutter/material.dart';
import '../mpv/video.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:video_player/video_player.dart';
import '../services/video_player_service.dart';
import '../pages/watch/watch_page.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: VideoPlayerService.instance.isMinimized,
      builder: (context, isMinimized, _) {
        if (!isMinimized) return const SizedBox.shrink();

        return ValueListenableBuilder<PlayerSession?>(
          valueListenable: VideoPlayerService.instance.currentSession,
          builder: (context, session, _) {
            if (session == null) return const SizedBox.shrink();

            final media = MediaQuery.of(context);
            final isMobile = media.size.width < 600;
            
            return Positioned(
              right: isMobile ? 10 : 20,
              bottom: isMobile ? 80 : 20, // Avoid bottom nav
              child: _buildMiniPlayerCard(context, session),
            );
          },
        );
      },
    );
  }

  Widget _buildMiniPlayerCard(BuildContext context, PlayerSession session) {
    final scheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: () {
        VideoPlayerService.instance.restore();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WatchPage(
              providerId: session.providerId,
              anime: session.anime,
              episodes: session.episodes,
              tvdbEpisodes: session.tvdbEpisodes,
              initialEpisodeNumber: session.currentEpisodeNumber,
              audioMode: session.audioMode,
              // We'll modify WatchPage to pick up the existing session
            ),
          ),
        );
      },
      child: Container(
        width: 300,
        height: 180,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          // boxShadow removed as requested
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            session.vpController != null 
                ? VideoPlayer(session.vpController!)
                : (session.player != null ? Video(player: session.player!) : const SizedBox()),
            // Controls overlay (simple)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      session.anime['title']?['romaji'] ?? 'Reproduciendo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => VideoPlayerService.instance.stop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  session.vpController != null 
                      ? ValueListenableBuilder(
                          valueListenable: session.vpController!,
                          builder: (context, val, _) {
                            return IconButton(
                              icon: Icon(
                                val.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () => val.isPlaying ? session.vpController!.pause() : session.vpController!.play(),
                            );
                          },
                        )
                      : StreamBuilder(
                          stream: session.player!.streams.playing,
                          builder: (context, snapshot) {
                            final playing = snapshot.data ?? false;
                            return IconButton(
                              icon: Icon(
                                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () => session.player!.playOrPause(),
                            );
                          },
                        ),
                ],
              ),
            ),
            // Progress bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: session.vpController != null
                  ? ValueListenableBuilder(
                      valueListenable: session.vpController!,
                      builder: (context, val, _) {
                        final pos = val.position;
                        final dur = val.duration;
                        if (dur.inMilliseconds == 0) return const SizedBox.shrink();
                        
                        return LinearProgressIndicator(
                          value: pos.inMilliseconds / dur.inMilliseconds,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(scheme.primary),
                          minHeight: 2,
                        );
                      },
                    )
                  : StreamBuilder(
                      stream: session.player!.streams.position,
                      builder: (context, snapshot) {
                        final pos = snapshot.data ?? Duration.zero;
                        final dur = session.player!.state.duration;
                        if (dur.inMilliseconds == 0) return const SizedBox.shrink();
                        
                        return LinearProgressIndicator(
                          value: pos.inMilliseconds / dur.inMilliseconds,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(scheme.primary),
                          minHeight: 2,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
