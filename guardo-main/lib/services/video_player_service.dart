import 'package:flutter/foundation.dart';
import '../mpv/player/player.dart';
import 'package:video_player/video_player.dart';
import '../models/app_models.dart' as models;

class PlayerSession {
  final Player? player;
  final VideoPlayerController? vpController;
  final Map<String, dynamic> anime;
  final List<models.EpisodeInfo> episodes;
  final Map<int, models.TvdbEpisode> tvdbEpisodes;
  final String providerId;
  int currentEpisodeNumber;
  final String audioMode;
  final dynamic hlsProxy;

  PlayerSession({
    this.player,
    this.vpController,
    required this.anime,
    required this.episodes,
    required this.tvdbEpisodes,
    required this.providerId,
    required this.currentEpisodeNumber,
    required this.audioMode,
    this.hlsProxy,
  });
}

class VideoPlayerService {
  VideoPlayerService._();
  static final VideoPlayerService instance = VideoPlayerService._();

  final ValueNotifier<PlayerSession?> _currentSession = ValueNotifier<PlayerSession?>(null);
  ValueListenable<PlayerSession?> get currentSession => _currentSession;

  final ValueNotifier<bool> _isMinimized = ValueNotifier<bool>(false);
  ValueListenable<bool> get isMinimized => _isMinimized;

  void setSession(PlayerSession session) {
    _currentSession.value = session;
  }

  void minimize() {
    if (_currentSession.value != null) {
      _isMinimized.value = true;
    }
  }

  void restore() {
    _isMinimized.value = false;
  }

  void stop() {
    final session = _currentSession.value;
    if (session != null) {
      session.player?.dispose();
      session.vpController?.dispose();
      try {
        session.hlsProxy?.dispose();
      } catch (_) {}
      _currentSession.value = null;
    }
    _isMinimized.value = false;
  }
  
  void updateEpisode(int epNum) {
    if (_currentSession.value != null) {
      _currentSession.value!.currentEpisodeNumber = epNum;
      // We trigger a notification by re-assigning the value
      _currentSession.value = _currentSession.value;
    }
  }
}
