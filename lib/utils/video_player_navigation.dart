import 'dart:async';
import '../media/ids.dart';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../media/media_item.dart';
import '../mpv/mpv.dart';
import '../models/transcode_quality_preset.dart';
import '../providers/download_provider.dart';
import '../providers/multi_server_provider.dart';
import '../providers/watch_state_store.dart';
import '../watch_together/providers/watch_together_provider.dart';
import '../screens/video_player_screen.dart';
import '../services/external_player_service.dart';
import '../services/offline_watch_sync_service.dart';
import '../services/settings_service.dart';
import 'app_logger.dart';
import 'platform_detector.dart';
import '../media/media_backend.dart';
import '../widgets/torrent_stream_selector_dialog.dart';
import '../media/media_kind.dart';
import '../services/plugin_extensions_service.dart';
import '../services/tmdb_service.dart';

const String kVideoPlayerRouteName = '/video_player';

class VideoPlayerNavigationInFlightGuard {
  final Set<String> _keys = <String>{};

  bool tryStart(
    MediaItem metadata, {
    required int mediaIndex,
    required String? selectedMediaSourceId,
    required TranscodeQualityPreset? selectedQualityPreset,
    required bool isOffline,
  }) {
    return _keys.add(
      _keyFor(
        metadata,
        mediaIndex: mediaIndex,
        selectedMediaSourceId: selectedMediaSourceId,
        selectedQualityPreset: selectedQualityPreset,
        isOffline: isOffline,
      ),
    );
  }

  void finish(
    MediaItem metadata, {
    required int mediaIndex,
    required String? selectedMediaSourceId,
    required TranscodeQualityPreset? selectedQualityPreset,
    required bool isOffline,
  }) {
    _keys.remove(
      _keyFor(
        metadata,
        mediaIndex: mediaIndex,
        selectedMediaSourceId: selectedMediaSourceId,
        selectedQualityPreset: selectedQualityPreset,
        isOffline: isOffline,
      ),
    );
  }

  String _keyFor(
    MediaItem metadata, {
    required int mediaIndex,
    required String? selectedMediaSourceId,
    required TranscodeQualityPreset? selectedQualityPreset,
    required bool isOffline,
  }) {
    return [
      metadata.globalKey,
      mediaIndex,
      selectedMediaSourceId ?? '',
      selectedQualityPreset?.name ?? 'auto',
      isOffline,
    ].join('|');
  }
}

final _videoPlayerNavigationInFlightGuard = VideoPlayerNavigationInFlightGuard();

class WatchTogetherPlaybackNavigationException implements Exception {
  final String message;

  const WatchTogetherPlaybackNavigationException(this.message);

  @override
  String toString() => message;
}

/// Series (keyed by grandparent) or standalone-item key under
/// [SettingsService.mediaVersionPreferences].
String _mediaVersionPreferenceKey(MediaItem metadata) => metadata.grandparentId ?? metadata.id;

/// Saved media-version preference for [metadata], or null when none is
/// stored. Shared by launch navigation and in-player version switching so
/// reads and writes can't drift onto different keys.
Future<int?> savedMediaVersionIndexFor(MediaItem metadata) async {
  try {
    final settingsService = await SettingsService.getInstance();
    return settingsService.read(SettingsService.mediaVersionPreferences)[_mediaVersionPreferenceKey(metadata)];
  } catch (_) {
    return null;
  }
}

/// Persist [index] as the preferred media version for [metadata]'s series/movie.
Future<void> saveMediaVersionIndexFor(MediaItem metadata, int index) async {
  final settingsService = await SettingsService.getInstance();
  await settingsService.write(SettingsService.mediaVersionPreferences, {
    ...settingsService.read(SettingsService.mediaVersionPreferences),
    _mediaVersionPreferenceKey(metadata): index,
  });
}

/// Navigates to the VideoPlayerScreen with instant transitions to prevent white flash.
///
/// This utility function provides a consistent way to navigate to the video player
/// across the app, using PageRouteBuilder with zero-duration transitions to eliminate
/// the white flash that occurs with MaterialPageRoute.
///
/// Parameters:
/// - [context]: The build context for navigation
/// - [metadata]: The neutral [MediaItem] for the content to play
/// - [preferredAudioTrack]: Optional audio track to select on playback start
/// - [preferredSubtitleTrack]: Optional subtitle track to select on playback start
/// - [selectedMediaIndex]: Optional media version index to use; if not provided,
///   loads the saved preference for the series/movie. Defaults to 0 if no preference exists.
/// - [selectedMediaSourceId]: Optional stable backend source id for the chosen version.
/// - [usePushReplacement]: If true, replaces current route instead of pushing;
///   useful for episode-to-episode navigation. Defaults to false.
/// - [isOffline]: If true, plays from downloaded content without requiring server connection.
/// - [resolveWatchState]: Resolve [metadata] through [WatchStateStore] so the
///   resume offset/watched flag are session-fresh even when the caller holds a
///   stale list snapshot. Pass false for explicit intents like play-from-start.
///
/// Returns a Future that completes with a boolean indicating whether the content
/// was watched, or null if navigation was cancelled.
Future<bool?> navigateToVideoPlayer(
  BuildContext context, {
  required MediaItem metadata,
  AudioTrack? preferredAudioTrack,
  SubtitleTrack? preferredSubtitleTrack,
  SubtitleTrack? preferredSecondarySubtitleTrack,
  int? selectedMediaIndex,
  String? selectedMediaSourceId,
  TranscodeQualityPreset? selectedQualityPreset,
  bool usePushReplacement = false,
  bool isOffline = false,
  bool resolveWatchState = true,
  String? directStreamUrl,
}) async {
  if (resolveWatchState) {
    metadata = context.readFreshWatchState(metadata);
  }

  appLogger.i('[PlaybackNavigation] Launching player for item ${metadata.id} ("${metadata.title}", index=${metadata.index}, grandparent="${metadata.grandparentTitle}") - backend=${metadata.backend}');

  if ((metadata.isAnilist || metadata.isTmdb) && directStreamUrl == null) {
    if (metadata.isAnilist) {
      final autoSelect = SettingsService.instance.read(SettingsService.autoSelectExtensionStream);
      if (autoSelect) {
        try {
          final episodeNum = metadata.index ?? 1;
          final animeTitle = metadata.grandparentTitle ?? metadata.title ?? '';
          if (animeTitle.isNotEmpty) {
            final stream = await PluginExtensionsService.getOnlineStreamUrl(
              title: animeTitle,
              episodeNumber: episodeNum,
            );
            if (stream != null && stream.isNotEmpty) {
              directStreamUrl = stream;
            }
          }
        } catch (e, st) {
          appLogger.e('[PlaybackNavigation] Failed to resolve online stream from extensions', error: e, stackTrace: st);
        }
      }
    }

    if (directStreamUrl == null) {
      try {
        String? imdbId;
        if (metadata.guid != null && metadata.guid!.startsWith('imdb://')) {
          imdbId = metadata.guid!.replaceAll('imdb://', '');
        } else if (metadata.isTmdb) {
          if (metadata.grandparentId != null) {
            // TMDB episodes do not hold the IMDb ID directly, so we load the TV show's details
            final showDetails = await TmdbService.getDetails(metadata.grandparentId!, MediaKind.show);
            if (showDetails != null && showDetails.guid != null && showDetails.guid!.startsWith('imdb://')) {
              imdbId = showDetails.guid!.replaceAll('imdb://', '');
            }
          } else {
            // It's a Movie, load movie details to get the IMDb ID if missing
            final movieDetails = await TmdbService.getDetails(metadata.id, MediaKind.movie);
            if (movieDetails != null && movieDetails.guid != null && movieDetails.guid!.startsWith('imdb://')) {
              imdbId = movieDetails.guid!.replaceAll('imdb://', '');
            }
          }
        }
        if (context.mounted) {
          final streamUrl = await ExtensionSourceSelectorDialog.show(
            context: context,
            metadata: metadata,
            seasonNumber: metadata.parentIndex ?? 1,
            episodeNumber: metadata.index ?? 1,
            imdbId: imdbId ?? '',
          );
          if (streamUrl == null) return null;
          directStreamUrl = streamUrl;
        }
      } catch (e, st) {
        appLogger.e('[TorrentNavigation] Failed to resolve stream details', error: e, stackTrace: st);
        return null;
      }
    }
  }

  final navigator = Navigator.of(context);
  final downloadProvider = context.read<DownloadProvider>();
  // Use the manager-routed lookup so Jellyfin items don't trip the
  // Plex-only client. The player branches on the returned type internally.
  final manager = context.read<MultiServerProvider>().serverManager;
  final offlineWatchService = context.read<OfflineWatchSyncService>();
  final serverId = serverIdOrNull(metadata.serverId);
  final mediaClient = serverId != null && (!isOffline || manager.isClientOnline(serverId))
      ? manager.getClient(serverId)
      : null;

  // Plain Play on a downloaded item must target the version actually on
  // disk. Only one version can be downloaded per item, and saved version
  // preferences describe online intent — they may point at a version that
  // was never downloaded (issue #1440). Explicit caller selections still win.
  int? downloadedMediaIndex;
  String? downloadedMediaSourceId;
  if (isOffline && selectedMediaIndex == null && selectedMediaSourceId == null) {
    final downloaded = await downloadProvider.getCompletedDownload(metadata.globalKey);
    if (downloaded != null) {
      downloadedMediaIndex = downloaded.mediaIndex;
      downloadedMediaSourceId = downloaded.mediaSourceId;
    }
  }

  final mediaIndex =
      selectedMediaIndex ?? downloadedMediaIndex ?? await savedMediaVersionIndexFor(metadata) ?? 0;
  final mediaSourceId = selectedMediaSourceId ?? downloadedMediaSourceId;

  var markedInFlight = false;
  if (!usePushReplacement) {
    markedInFlight = _videoPlayerNavigationInFlightGuard.tryStart(
      metadata,
      mediaIndex: mediaIndex,
      selectedMediaSourceId: mediaSourceId,
      selectedQualityPreset: selectedQualityPreset,
      isOffline: isOffline,
    );
    if (!markedInFlight) {
      appLogger.d(
        'Video player navigation already in flight for ${metadata.id} (mediaIndex=$mediaIndex), '
        'skipping duplicate navigation',
      );
      return null;
    }
  }

  try {
    // Check if external player is enabled
    try {
      final settingsService = await SettingsService.getInstance();
      if (PlatformDetector.supportsExternalPlayers() && settingsService.read(SettingsService.useExternalPlayer)) {
        bool launched = false;

        if (isOffline) {
          final globalKey = metadata.globalKey;
          final videoPath = await downloadProvider.getVideoFilePath(
            globalKey,
            mediaIndex: mediaIndex,
            mediaSourceId: mediaSourceId,
          );
          if (videoPath != null && context.mounted) {
            final videoUrl = videoPath.contains('://') ? videoPath : 'file://$videoPath';
            launched = await ExternalPlayerService.launch(
              context: context,
              videoUrl: videoUrl,
              metadata: metadata,
              client: mediaClient,
              offlineWatchService: offlineWatchService,
              mediaIndex: mediaIndex,
              mediaSourceId: mediaSourceId,
            );
          }
        } else if (context.mounted) {
          launched = await ExternalPlayerService.launch(
            context: context,
            metadata: metadata,
            client: mediaClient,
            offlineWatchService: offlineWatchService,
            mediaIndex: mediaIndex,
            mediaSourceId: mediaSourceId,
          );
        }

        if (launched) return null;
      }
    } catch (e) {
      appLogger.w('External player launch failed, falling back to built-in player', error: e);
    }

    // Prevent stacking an identical video player when already active
    if (!usePushReplacement &&
        VideoPlayerScreenState.activeId == metadata.id &&
        VideoPlayerScreenState.activeMediaIndex == mediaIndex) {
      appLogger.d(
        'Video player already active for ${metadata.id} (mediaIndex=$mediaIndex), skipping duplicate navigation',
      );
      return null;
    }

    final route = PageRouteBuilder<bool>(
      settings: const RouteSettings(name: kVideoPlayerRouteName),
      pageBuilder: (context, animation, secondaryAnimation) => VideoPlayerScreen(
        metadata: metadata,
        preferredAudioTrack: preferredAudioTrack,
        preferredSubtitleTrack: preferredSubtitleTrack,
        preferredSecondarySubtitleTrack: preferredSecondarySubtitleTrack,
        selectedMediaIndex: mediaIndex,
        selectedMediaSourceId: mediaSourceId,
        selectedQualityPreset: selectedQualityPreset,
        isOffline: isOffline,
        directStreamUrl: directStreamUrl,
      ),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );

    final playResult = await (usePushReplacement ? navigator.pushReplacement<bool, bool>(route) : navigator.push<bool>(route));
    return playResult ?? false;
  } finally {
    if (markedInFlight) {
      _videoPlayerNavigationInFlightGuard.finish(
        metadata,
        mediaIndex: mediaIndex,
        selectedMediaSourceId: mediaSourceId,
        selectedQualityPreset: selectedQualityPreset,
        isOffline: isOffline,
      );
    }
  }
}

/// Navigates to the video player and optionally refreshes content when returning.
///
/// This helper consolidates the common pattern of:
/// 1. Navigating to the video player
/// 2. Logging the return
/// 3. Calling a refresh callback if not offline
///
/// Parameters:
/// - [context]: The build context for navigation
/// - [metadata]: The neutral [MediaItem] for the content to play
/// - [isOffline]: If true, plays from downloaded content
/// - [onRefresh]: Optional callback to refresh data when returning from playback
///   (only called when not offline)
/// - All other parameters are passed through to [navigateToVideoPlayer]
Future<bool?> navigateToVideoPlayerWithRefresh(
  BuildContext context, {
  required MediaItem metadata,
  bool isOffline = false,
  VoidCallback? onRefresh,
  AudioTrack? preferredAudioTrack,
  SubtitleTrack? preferredSubtitleTrack,
  SubtitleTrack? preferredSecondarySubtitleTrack,
  int? selectedMediaIndex,
  String? selectedMediaSourceId,
  bool usePushReplacement = false,
}) async {
  final result = await navigateToVideoPlayer(
    context,
    metadata: metadata,
    isOffline: isOffline,
    preferredAudioTrack: preferredAudioTrack,
    preferredSubtitleTrack: preferredSubtitleTrack,
    preferredSecondarySubtitleTrack: preferredSecondarySubtitleTrack,
    selectedMediaIndex: selectedMediaIndex,
    selectedMediaSourceId: selectedMediaSourceId,
    usePushReplacement: usePushReplacement,
  );

  appLogger.d('Returned from playback, refreshing metadata');

  if (result != null && !isOffline && onRefresh != null && context.mounted) {
    onRefresh();
  }

  return result;
}

/// Resolves the current Watch Together media and opens the video player.
///
/// Returns whether navigation was initiated. The fetch can outlive the
/// dispatch that requested it (slow server, host switching again, dispatcher
/// timeout); navigating then would stack a stale player route on top of the
/// live one, so the key is re-validated against the session's current
/// playback snapshot before the push.
Future<bool> navigateToWatchTogetherPlayback(
  BuildContext context, {
  required String ratingKey,
  required ServerId serverId,
  VoidCallback? onBeforeNavigate,
}) async {
  final multiServer = context.read<MultiServerProvider>();
  final client = multiServer.getClientForServer(serverId);

  if (client == null) {
    throw const WatchTogetherPlaybackNavigationException('Watch Together server is unavailable');
  }

  final metadata = await client.fetchItem(ratingKey);
  if (metadata == null) {
    throw const WatchTogetherPlaybackNavigationException('Current Watch Together media is unavailable');
  }

  if (!context.mounted) return false;

  final watchTogether = context.read<WatchTogetherProvider>();
  if (watchTogether.currentMediaRatingKey != ratingKey || watchTogether.currentMediaServerId != serverId) {
    appLogger.d('WatchTogether: Skipping stale navigation to $ratingKey');
    return false;
  }

  onBeforeNavigate?.call();
  unawaited(navigateToVideoPlayer(context, metadata: metadata));
  return true;
}
