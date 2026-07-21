import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) 'package:anityng/stubs/io_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../mpv/player/player.dart';
import '../../../mpv/models.dart' as mpv_models;
import '../../../models/app_models.dart' as models;
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/hls_proxy_service.dart';
import '../../../services/aniskip_service.dart';
import '../../../services/real_debrid_service.dart';
import '../../../services/torrentio_service.dart';
import '../../../services/app_shell_controller.dart';
import '../../../extensions/core/extension_base.dart';
import '../../../extensions/extension_service.dart';
import '../../../providers/torrent_provider.dart';
import '../../../providers/video_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io' if (dart.library.html) 'package:anityng/stubs/io_stub.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart' if (dart.library.html) 'package:anityng/stubs/bitsdojo_window_stub.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_windows/webview_windows.dart' if (dart.library.html) 'package:anityng/stubs/webview_windows_stub.dart';

class WatchController extends ChangeNotifier {
  final String initialProviderId;
  final Map<String, dynamic> anime;
  final List<models.EpisodeInfo> episodes;
  final Map<int, models.TvdbEpisode> tvdbEpisodes;
  final int initialEpisodeNumber;
  final String initialAudioMode;
  final double? resumeTime;
  final models.StreamLink? initialStream;

  WatchController({
    required this.initialProviderId,
    required this.anime,
    required this.episodes,
    required this.tvdbEpisodes,
    required this.initialEpisodeNumber,
    this.initialAudioMode = 'sub',
    this.resumeTime,
    this.initialStream,
  });

  // Services
  final _api = ApiService.instance;
  final _storage = StorageService.instance;
  final hlsProxy = HlsProxyService();
  final _extensions = ExtensionService();

  int _extensionIndex = 0;
  
  ExtensionBase? _resolveAnimeExtension() {
    final exts = _extensions.extensions.where((e) => e.manifest.type == 'anime').toList();
    if (exts.isEmpty) return null;
    if (_extensionIndex >= 0 && _extensionIndex < exts.length) return exts[_extensionIndex];
    return exts.first;
  }
  
  bool get useNativePlayer {
    if (!(Platform.isAndroid || Platform.isIOS)) return false;
    if (_isTorrentProvider || isPlayingLocalFile) return false;
    final pref = settings?.preferredPlayer ?? 'mpv';
    return pref == 'exoplayer';
  }

  bool get useWebViewPlayer {
    if (!Platform.isWindows) return false;
    if (_isTorrentProvider || isPlayingLocalFile) return false;
    if (_forceMediaKit) return false;
    return currentProviderId == 'extension' || currentProviderId == 'sudatchi' || currentProviderId.startsWith('ext_');
  }
  
  Player? player;
  VideoPlayerController? vpController;
  WebviewController? webviewController;
  bool isWebviewInitialized = false;
  
  String? _lastOpenUrl;
  models.StreamLink? _lastSelectedStream;

  // State
  String currentProviderId = '';
  List<models.EpisodeInfo> providerEpisodes = [];
  int currentEpNum = 1;
  bool loading = true;
  String audioMode = 'sub';
  String? error;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = false;
  double playbackSpeed = 1.0;

  bool showControls = true;
  bool isDragging = false;
  bool isSettingsOpen = false;
  Timer? hideTimer;
  double volume = 100;
  bool isFullscreen = false;
  bool buffering = false;
  double? targetSeekPosition;
  String? currentTorrentHash;

  bool isProxied = false;
  bool isPlayingLocalFile = false;

  List<models.SkipTime> skipTimes = [];
  models.SkipTime? currentSkip;

  bool useRealDebrid = false;
  String rdStatusMessage = '';
  bool rdResolving = false;
  bool isRealDebridStream = false;
  bool isCompatibilityMode = false;
  String? imdbId;
  int? providerLookupAniListId;
  int? providerLookupAniDbId;
  models.AppSettings? settings;

  bool isControlsLocked = false;
  bool showSidePanel = true;

  bool _forceMediaKit = false;
  bool _webviewHasVideo = false;
  bool get webviewHasVideo => _webviewHasVideo;
  Timer? _webviewFallbackTimer;

  final episodeScrollController = ScrollController();
  
  Completer<void> mpvConfigured = Completer();
  Completer<void> hlsProxyReady = Completer();

  bool _isDisposed = false;

  Future<void> changeProvider(String newProviderId) async {
    if (currentProviderId == newProviderId) return;
    currentProviderId = newProviderId;
    providerEpisodes.clear();
    await loadEpisode(currentEpNum);
    notifyListeners();
  }

  void init() {
    currentProviderId = initialProviderId == 'torrent'
        ? 'torrent_animetosho'
        : initialProviderId;
    currentEpNum = initialEpisodeNumber;
    audioMode = initialAudioMode;

    _storage.getAppSettings().then((s) {
      settings = s;

      if (useNativePlayer || useWebViewPlayer) {
        if (!mpvConfigured.isCompleted) mpvConfigured.complete();
      } else {
        _initMediaKit();
      }

      hlsProxy.start().then((_) => hlsProxyReady.complete());

      _initRealDebrid();
      loadEpisode(currentEpNum, resume: resumeTime ?? 0);
      startHideTimer();
    });
  }

  void toggleControls() {
    showControls = !showControls;
    if (showControls) {
      startHideTimer();
    } else {
      hideTimer?.cancel();
    }
    _safeNotify();
  }

  void startHideTimer() {
    hideTimer?.cancel();
    if (isDragging || isSettingsOpen) return;
    hideTimer = Timer(const Duration(seconds: 3), () {
      if (!_isDisposed && !isDragging && !isSettingsOpen) {
        showControls = false;
        _safeNotify();
      }
    });
  }

  void hideControls() {
    if (isSettingsOpen) return;
    hideTimer?.cancel();
    showControls = false;
    _safeNotify();
  }

  void showControlsForce() {
    showControls = true;
    _safeNotify();
  }

  void dispose() {
    _isDisposed = true;
    _webviewFallbackTimer?.cancel();
    hideTimer?.cancel();
    player?.dispose();
    vpController?.dispose();
    webviewController?.dispose();
    hlsProxy.dispose();
    episodeScrollController.dispose();
    super.dispose();
  }

  void _initMediaKit() {
    if (player != null) return;
    player = Player(useExoPlayer: false);
    _setupListeners();
    _configureMpv();
    if (!mpvConfigured.isCompleted) mpvConfigured.complete();
  }

  DateTime _lastNotify = DateTime.now();
  
  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  /// Throttled notify - limits UI rebuilds to ~4/sec for smooth performance on mobile
  void _throttledNotify() {
    if (_isDisposed) return;
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds >= 250) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  void _setupVpListeners() {
    if (vpController == null) return;
    DateTime lastSave = DateTime.now();
    vpController!.addListener(() {
      if (_isDisposed) return;
      final val = vpController!.value;
      
      position = val.position;
      duration = val.duration;
      
      // Important state changes notify immediately
      if (playing != val.isPlaying || buffering != val.isBuffering) {
        playing = val.isPlaying;
        buffering = val.isBuffering;
        _safeNotify();
        return;
      }
      playing = val.isPlaying;
      buffering = val.isBuffering;
      
      if (val.hasError && val.errorDescription != null) {
        loading = false;
        error = 'Error de reproducción: ${val.errorDescription}';
        _safeNotify();
        return;
      }
      
      final currentSecs = position.inMilliseconds / 1000.0;
      models.SkipTime? matched;
      for (final s in skipTimes) {
        if (currentSecs >= s.startTime && currentSecs <= s.endTime) {
          matched = s;
          break;
        }
      }
      if (currentSkip?.skipType != matched?.skipType) {
        currentSkip = matched;
        _safeNotify();
        return;
      }

      if (playing && DateTime.now().difference(lastSave).inSeconds >= 5) {
        lastSave = DateTime.now();
        saveProgress();
      }
      
      // Position-only updates use throttled notify
      _throttledNotify();
    });
  }

  void _setupWebviewListeners() {
    if (webviewController == null) return;
    DateTime lastSave = DateTime.now();
    webviewController!.webMessage.listen((msg) {
      if (_isDisposed) return;
      try {
        final data = jsonDecode(msg);
        switch (data['type']) {
          case 'time':
            position = Duration(milliseconds: (data['data'] * 1000).toInt());
            final currentSecs = position.inMilliseconds / 1000.0;
            models.SkipTime? matched;
            for (final s in skipTimes) {
              if (currentSecs >= s.startTime && currentSecs <= s.endTime) {
                matched = s;
                break;
              }
            }
            if (currentSkip?.skipType != matched?.skipType) {
              currentSkip = matched;
            }
            if (playing && DateTime.now().difference(lastSave).inSeconds >= 5) {
              lastSave = DateTime.now();
              saveProgress();
            }
            _safeNotify();
            break;
          case 'duration':
            duration = Duration(milliseconds: (data['data'] * 1000).toInt());
            _safeNotify();
            break;
          case 'play':
            playing = data['data'];
            _webviewHasVideo = true;
            _safeNotify();
            break;
          case 'buffering':
            buffering = data['data'];
            _safeNotify();
            break;
          case 'error':
            loading = false;
            error = 'Error de reproducción: ${data['data']}';
            _safeNotify();
            break;
        }
      } catch (_) {}
    });
  }

  void _setupListeners() {
    if (player == null) return;
    DateTime lastSave = DateTime.now();
    player!.streams.position.listen((p) {
      position = p;
      final currentSecs = displayPosition.inMilliseconds / 1000.0;
      models.SkipTime? matched;
      for (final s in skipTimes) {
        if (currentSecs >= s.startTime && currentSecs <= s.endTime) {
          matched = s;
          break;
        }
      }
      if (currentSkip?.skipType != matched?.skipType) {
        currentSkip = matched;
        _safeNotify();
        return;
      }

      if (DateTime.now().difference(lastSave).inSeconds >= 5) {
        lastSave = DateTime.now();
        saveProgress();
      }
      // Position-only updates use throttled notify
      _throttledNotify();
    });

    player!.streams.duration.listen((d) {
      duration = d;
      _safeNotify();
    });

    player!.streams.log.listen((event) {
      debugPrint('[MPV DEBUG] ${event.level}: ${event.text}');
    });

    player!.streams.playing.listen((p) {
      playing = p;
      _safeNotify();
    });

    player!.streams.volume.listen((v) {
      volume = v;
      _safeNotify();
    });

    player!.streams.error.listen((e) {
      if (e.message.isEmpty) return;
      if (position.inSeconds < 5 && (Platform.isAndroid || Platform.isIOS)) {
        print('MPV error, falling back to ExoPlayer: ${e.message}');
        _fallbackToExoPlayer();
      } else {
        loading = false;
        error = 'Error de reproducción: ${e.message}';
        _safeNotify();
      }
    });
  }

  Future<void> _fallbackToExoPlayer() async {
    if (_lastOpenUrl == null || _lastSelectedStream == null) return;
    try {
      player?.dispose();
      player = null;

      vpController = VideoPlayerController.networkUrl(
        Uri.parse(_lastOpenUrl!),
        httpHeaders: _lastSelectedStream!.headers ?? {},
        formatHint: _lastSelectedStream!.isM3u8 ? VideoFormat.hls : null,
      );
      _setupVpListeners();
      await vpController!.initialize();
      if (position.inSeconds > 0) {
        await vpController!.seekTo(position);
      }
      await vpController!.play();
      playing = true;
      loading = false;
      _safeNotify();
    } catch (ex) {
      error = 'Error de reproducción: $ex';
      loading = false;
      _safeNotify();
    }
  }

  Duration get displayPosition => isProxied && !useNativePlayer && !useWebViewPlayer
      ? (targetSeekPosition != null
          ? Duration(milliseconds: targetSeekPosition!.toInt())
          : Duration(milliseconds: (hlsProxy.timeOffset * 1000 + position.inMilliseconds).toInt()))
      : position;

  Duration get displayDuration => isProxied && !useNativePlayer && !useWebViewPlayer
      ? Duration(milliseconds: (hlsProxy.totalDuration * 1000).toInt())
      : duration;

  Future<void> _initRealDebrid() async {
    settings = await _storage.getAppSettings();
    // Real-Debrid and Torrentio config removed - simplified
    _safeNotify();
  }

  Future<void> _configureMpv() async {
    if (player == null) return;
    final s = settings ?? await _storage.getAppSettings();
    if (kIsWeb) return;
    try {
      await player!.setProperty('demuxer-lavf-o', 'allowed_extensions=ALL,reconnect_on_http_error=4xx,reconnect_delay_max=2');
      await player!.setProperty('cache', 'yes');
      await player!.setProperty('demuxer-max-bytes', '134217728');
      await player!.setProperty('demuxer-readahead-secs', '20');
      await player!.setProperty('sub-ass', 'yes');
      await player!.setProperty('sub-visibility', 'yes');
      await player!.setProperty('sid', 'auto');
      // Smooth track switching during torrent streaming
      await player!.setProperty('demuxer-thread', 'yes');
      await player!.setProperty('cache-pause-wait', '1');
      await player!.setProperty('cache-pause-initial', 'no');
      await player!.setProperty('hr-seek', 'yes');
      
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          await player!.setProperty('hwdec', 'mediacodec-copy');
          await player!.setProperty('hwdec', 'auto-safe');
        } else if (Platform.isLinux) {
          await player!.setProperty('hwdec', 'auto');
        }
      }
    } catch (e) {
      debugPrint('[WatchController] MPV config error: $e');
    }
    _safeNotify();
    if (!mpvConfigured.isCompleted) {
      mpvConfigured.complete();
    }
  }

  void saveProgress() {
    if (displayDuration.inSeconds <= 0) return;
    final ep = episodes.firstWhere((e) => e.number == currentEpNum, orElse: () => episodes.first);
    _storage.updateEpisodeProgress(
      animeId: (anime['id'] as num?)?.toInt() ?? 0,
      episodeNumber: currentEpNum,
      currentTime: displayPosition.inSeconds.toDouble(),
      duration: displayDuration.inSeconds.toDouble(),
      anime: anime,
      episodeTitle: ep.title,
      audioMode: audioMode,
    );
  }

  Future<void> loadEpisode(int epNum, {double resume = 0}) async {
    loading = true;
    error = null;
    currentEpNum = epNum;
    skipTimes = [];
    currentSkip = null;
    isPlayingLocalFile = false;
    isRealDebridStream = false;
    isCompatibilityMode = false;
    _safeNotify();

    final malId = (anime['idMal'] as num?)?.toInt();
    if (malId != null && malId > 0) {
      AniSkipService.getSkipTimes(malId: malId, episodeNumber: epNum).then((times) {
        skipTimes = times;
        _safeNotify();
      });
    }

    await mpvConfigured.future;
    await hlsProxyReady.future;
    try { 
      if (useNativePlayer) {
        if (vpController != null) {
          await vpController!.pause();
          await vpController!.dispose();
          vpController = null;
        }
      } else if (useWebViewPlayer) {
        if (webviewController != null) {
          _webviewFallbackTimer?.cancel();
          webviewController!.dispose();
          webviewController = null;
          isWebviewInitialized = false;
        }
      } else {
        await player?.stop(); 
      }
    } catch (_) {}

    VideoProvider? provider;
    
    // Parse extension index from providerId (ext_0, ext_1, etc.)
    if (currentProviderId.startsWith('ext_')) {
      _extensionIndex = int.tryParse(currentProviderId.substring(4)) ?? 0;
    }
    
    final animeExtension = _resolveAnimeExtension();
    final useJsExtension =
        animeExtension != null &&
        (currentProviderId == 'extension' || 
         currentProviderId == 'torrentio' ||
         currentProviderId.startsWith('ext_'));

    if (_isTorrentProvider) {
      provider = _api.torrent;
    } else {
      provider = _api.torrent;
    }

    if (_isTorrentProvider && currentProviderId != 'torrentio') {
      final source = currentProviderId == 'torrent_nyaa' 
          ? TorrentSearchSource.nyaa 
          : TorrentSearchSource.animetosho;
      _api.torrent.setSearchSource(source);
    }

    Map<int, int> parseIntMap(dynamic raw) {
      final out = <int, int>{};
      if (raw is! Map) return out;
      for (final entry in raw.entries) {
        final k = int.tryParse('${entry.key}');
        final v = int.tryParse('${entry.value}');
        if (k != null && v != null) out[k] = v;
      }
      return out;
    }

    final anilistId = (anime['id'] as num?)?.toInt() ?? 0;
    final titleMap = anime['title'] as Map?;
    final romaji = (anime['baseTitle'] as String?)?.trim() ?? titleMap?['romaji']?.toString().trim() ?? '';
    final english = (anime['baseTitleEnglish'] as String?)?.trim() ?? titleMap?['english']?.toString().trim() ?? '';
    final slug = (anime['slug'] as String?)?.trim() ?? '';
    final desiredAniDbId = (anime['anidbId'] as num?)?.toInt();

    if (providerEpisodes.isEmpty) {
      try {
        if (useJsExtension) {
          print('🎮 [WatchController] Using Extension: ${animeExtension!.manifest.name}');
          
          // All Dart extensions support search/getDetails natively
          const hasSearch = true;
          const hasDetails = true;
          
          String detailsLookup = slug;
          models.AnimeDetailsResult? details;
          
          if (hasDetails) {
            // Flujo normal: buscar y obtener detalles
            if (detailsLookup.isEmpty) {
              print('🔍 [WatchController] No slug found, searching by title...');
              final byRomaji = await animeExtension.search(romaji);
              final byEnglish = byRomaji.isEmpty && english.isNotEmpty && english != romaji
                  ? await animeExtension.search(english)
                  : const <models.SearchResult>[];
              final results = byRomaji.isNotEmpty ? byRomaji : byEnglish;
              if (results.isNotEmpty) {
                detailsLookup = results.first.id;
                print('✅ [WatchController] Found match: $detailsLookup');
              }
            }

            if (detailsLookup.isEmpty) {
              print('❌ [WatchController] Could not find anime in extension');
              throw Exception('No se encontró anime en extensión');
            }

            details = await animeExtension.getDetails(detailsLookup);
            providerEpisodes = details.episodes;
            print('✅ [WatchController] Loaded ${providerEpisodes.length} episodes from JS extension');
          } else {
            // Extensión sin search/getDetails: usar datos de Anilist/TVDB
            // y pasar directo a getStreams cuando se seleccione un episodio
            print('ℹ️ [WatchController] Extension only supports getStreams, using AniList data');
            providerEpisodes = episodes.map((e) => models.EpisodeInfo(
              id: jsonEncode({
                'anilistId': anilistId,
                'episode': e.number,
                'title': e.title,
                'slug': romaji.isNotEmpty ? romaji : slug,
                'number': e.number,
              }),
              number: e.number,
              title: e.title,
            )).toList();
          }
        } else {
          final details = await provider!.getDetails(
            anilistId: anilistId,
            slug: slug,
            romajiTitle: romaji,
            englishTitle: english,
            anidbId: desiredAniDbId,
          );
          providerEpisodes = details.episodes;
        }

        providerLookupAniListId = anilistId;
        providerLookupAniDbId = desiredAniDbId;
      } catch (e) {
        print('❌ [WatchController] Provider error: $e');
        loading = false;
        error = 'No se pudo obtener información del proveedor';
        _safeNotify();
        return;
      }
    }

    if (providerEpisodes.isEmpty) {
      loading = false;
      error = 'No se encontraron episodios en el proveedor';
      _safeNotify();
      return;
    }

    models.EpisodeInfo? targetEp = providerEpisodes.firstWhere((e) => e.number == epNum, orElse: () => providerEpisodes.first);

    final localFile = await _findLocalDownloadedEpisode(epNum);
    if (localFile != null) {
      isPlayingLocalFile = true;
      _initMediaKit(); // Ensure media_kit is ready for local file
      await player!.open(mpv_models.Media(localFile.path));
      if (resume > 0) await player!.seek(Duration(seconds: resume.toInt()));
      loading = false;
      _safeNotify();
      return;
    }

    models.StreamLink? selectedStream;
    if (_isTorrentProvider) {
       if (initialStream != null && epNum == initialEpisodeNumber) {
         selectedStream = initialStream;
       } else {
         // Page will call playStream after picking via selector
         loading = false;
         _safeNotify();
         return;
       }
    } else {
      if (useJsExtension) {
        print('🎥 [WatchController] Extracting videos using JS extension for episode ID: ${targetEp.id}');
      }
      final streams = useJsExtension
          ? await animeExtension!.extractVideos(targetEp.id)
          : await provider!.getStreams(targetEp.id, overrideType: audioMode);
      if (streams.isEmpty) {
        print('❌ [WatchController] No streams found');
        loading = false;
        error = 'No hay streams disponibles';
        _safeNotify();
        return;
      }
      print('✅ [WatchController] Found ${streams.length} streams');
      selectedStream = streams.firstWhere((s) => s.isM3u8, orElse: () => streams.first);
    }

    if (selectedStream != null) {
      await playStream(selectedStream, resume: resume);
    } else {
      loading = false;
      error = 'No se seleccionó ningún stream válido';
      _safeNotify();
    }
  }

  Future<void> playStream(models.StreamLink selectedStream, {double resume = 0}) async {
    try {
      loading = true;
      _safeNotify();

      final selectedUrl = selectedStream.isM3u8
          ? await _extractMediaPlaylist(selectedStream.url, selectedStream.headers)
          : selectedStream.url;
      
      String openUrl = selectedUrl;
      
      if (_isTorrentProvider) {
        final isLazy = selectedStream.headers?['lazyTorrent'] == 'true';
        final hash = selectedStream.headers?['infoHash'];
        if (hash != null && hash.isNotEmpty) {
          currentTorrentHash = hash;
        }

        if (isLazy) {
          final magnet = selectedStream.headers!['magnet']!;
          
          bool rdSuccess = false;
          if (useRealDebrid && RealDebridService.instance.isConfigured && magnet.isNotEmpty) {
            try {
              rdResolving = true;
              rdStatusMessage = 'Conectando con Real-Debrid...';
              _safeNotify();
              
              openUrl = await RealDebridService.instance.resolveMagnetToStream(
                magnet,
                onStatusUpdate: (status) {
                  rdStatusMessage = status;
                  _safeNotify();
                },
              );
              isRealDebridStream = true;
              rdResolving = false;
              rdSuccess = true;
            } catch (e) {
              debugPrint('[WatchController] Real-Debrid error: $e. Falling back to local backend.');
              rdResolving = false;
              rdSuccess = false;
            }
          }

          if (!rdSuccess) {
            // Local Go backend fallback
            rdStatusMessage = 'Conectando con Backend Local...';
            _safeNotify();
            final info = await _api.torrent.addTorrent(magnet);
            if (info != null) {
              final url = await _api.torrent.getStreamUrl(info.infoHash, 0);
              if (url != null && url.isNotEmpty) {
                openUrl = url;
              } else {
                throw Exception('No se pudo obtener la URL de streaming del backend local.');
              }
            } else {
              throw Exception('No se pudo agregar el torrent al backend local.');
            }
          }
        }
      } else if (selectedStream.isM3u8) {
        if (!useWebViewPlayer && (Platform.isAndroid || Platform.isIOS)) {
          final proxyUrl = await hlsProxy.prepare(selectedUrl, headers: selectedStream.headers);
          if (proxyUrl != null) {
            isProxied = true;
            if (useNativePlayer) {
              hlsProxy.disableSeekProxy = true; // Use native seeking for Android native player
            }
            openUrl = hlsProxy.freshUrl;
          }
        }
      }

      if ((Platform.isAndroid || Platform.isIOS) && selectedStream.isM3u8) {
        openUrl = hlsProxy.freshUrl;
      }

      _lastOpenUrl = openUrl;
      _lastSelectedStream = selectedStream;

      if (useNativePlayer) {
        vpController = VideoPlayerController.networkUrl(
          Uri.parse(openUrl),
          httpHeaders: selectedStream.headers ?? {},
          formatHint: selectedStream.isM3u8 ? VideoFormat.hls : null,
        );
        _setupVpListeners();
        await vpController!.initialize();
        if (resume > 0) await vpController!.seekTo(Duration(seconds: resume.toInt()));
        // Always auto-play when opening a stream
        await vpController!.play();
        playing = true;
      } else if (useWebViewPlayer) {
        _forceMediaKit = false;
        _webviewHasVideo = false;
        _webviewFallbackTimer?.cancel();
        
        webviewController = WebviewController();
        await webviewController!.initialize();
        isWebviewInitialized = true;
        _setupWebviewListeners();
        
        final html = '''
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body, html { margin: 0; padding: 0; width: 100%; height: 100%; background-color: #000; overflow: hidden; }
                video { width: 100%; height: 100%; outline: none; background: #000; }
            </style>
            <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
        </head>
        <body>
            <video id="video" autoplay playsinline></video>
            <script>
                var video = document.getElementById('video');
                var videoSrc = '$openUrl';
                
                function sendMsg(type, data) {
                    window.chrome.webview.postMessage(JSON.stringify({type: type, data: data}));
                }
        
                video.addEventListener('timeupdate', () => sendMsg('time', video.currentTime));
                video.addEventListener('durationchange', () => sendMsg('duration', video.duration));
                video.addEventListener('play', () => sendMsg('play', true));
                video.addEventListener('pause', () => sendMsg('play', false));
                video.addEventListener('waiting', () => sendMsg('buffering', true));
                video.addEventListener('playing', () => { sendMsg('buffering', false); sendMsg('play', true); });
                video.addEventListener('ended', () => sendMsg('ended', true));
                video.addEventListener('error', (e) => sendMsg('error', e.message));
        
                function tryPlay() {
                    var p = video.play();
                    if (p !== undefined) {
                        p.catch(e => setTimeout(tryPlay, 500));
                    }
                }

                if (Hls.isSupported()) {
                    var hls = new Hls({ autoStartLoad: true });
                    hls.loadSource(videoSrc);
                    hls.attachMedia(video);
                    hls.on(Hls.Events.MANIFEST_PARSED, function() {
                        ${resume > 0 ? 'video.currentTime = $resume;' : ''}
                        tryPlay();
                    });
                    hls.on(Hls.Events.ERROR, function(event, data) {
                        if (data.fatal) sendMsg('error', data.type);
                    });
                }
                else if (video.canPlayType('application/vnd.apple.mpegurl')) {
                    video.src = videoSrc;
                    video.addEventListener('loadedmetadata', function() {
                        ${resume > 0 ? 'video.currentTime = $resume;' : ''}
                        tryPlay();
                    });
                }
            </script>
        </body>
        </html>
        ''';
        
        await webviewController!.loadStringContent(html);
        
        // Forzar autoplay desde Dart después de que el webview cargue
        Future.delayed(const Duration(seconds: 2), () {
          if (_isDisposed || webviewController == null) return;
          (webviewController as dynamic).executeScript("document.getElementById('video').play().catch(function(){})");
        });

        _webviewFallbackTimer = Timer(const Duration(seconds: 15), () {
          if (_isDisposed || _webviewHasVideo) return;
          if (position.inMilliseconds < 500) return;
          _forceMediaKit = true;
          _safeNotify();
          webviewController?.dispose();
          webviewController = null;
          isWebviewInitialized = false;
          _initMediaKit();
          player!.open(mpv_models.Media(openUrl, headers: selectedStream.headers));
          if (resume > 0) {
            player!.seek(Duration(seconds: resume.toInt()));
          }
        });
      } else {
        _initMediaKit(); // Ensure media_kit is ready for torrents/linux/etc
        await player!.open(mpv_models.Media(openUrl, headers: selectedStream.headers));
        if (resume > 0) await player!.seek(Duration(seconds: resume.toInt()));
        await player!.play();
      }
      
      loading = false;
      _safeNotify();
    } catch (e) {
      if (!useNativePlayer && (Platform.isAndroid || Platform.isIOS)) {
        print('MPV open failed, falling back to ExoPlayer: $e');
        await _fallbackToExoPlayer();
      } else {
        loading = false;
        error = 'Error de reproducción: $e';
        _safeNotify();
      }
    }
  }

  Future<String> _extractMediaPlaylist(String masterUrl, Map<String, String>? headers) async {
    try {
      final res = await http.get(Uri.parse(masterUrl), headers: headers);
      if (res.statusCode != 200) return masterUrl;
      final lines = res.body.split('\n');
      String? bestUrl;
      int maxRes = 0;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('#EXT-X-STREAM-INF')) {
          final m = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
          if (m != null) {
            final r = int.parse(m.group(2)!);
            if (r > maxRes) {
              maxRes = r;
              if (i + 1 < lines.length) bestUrl = lines[i + 1].trim();
            }
          }
        }
      }
      if (bestUrl != null) {
        if (!bestUrl.startsWith('http')) {
          final uri = Uri.parse(masterUrl);
          return uri.resolve(bestUrl).toString();
        }
        return bestUrl;
      }
    } catch (_) {}
    return masterUrl;
  }

  Future<List<models.StreamLink>> fetchTorrentioStreams() async {
    if (imdbId == null) return [];
    final torrentio = TorrentioService.instance;
    final season = anime['seasonNumber'] ?? 1;
    try {
      final streams = await torrentio.fetchStreams(imdbId: imdbId!, season: season, episode: currentEpNum);
      return streams.map((s) => models.StreamLink(
        url: s.url ?? '',
        quality: s.quality,
        isM3u8: false,
        headers: {'infoHash': s.infoHash ?? '', 'magnet': s.magnetLink ?? '', 'lazyTorrent': (s.url == null).toString()},
      )).toList();
    } catch (_) { return []; }
  }

  Future<File?> _findLocalDownloadedEpisode(int epNum) async {
    try {
      final anilistId = (anime['id'] as num?)?.toInt() ?? 0;
      final baseDir = await _api.torrent.getDownloadDirectory();
      final animeDir = Directory('$baseDir${Platform.pathSeparator}$anilistId');
      if (!await animeDir.exists()) return null;
      await for (final entity in animeDir.list(recursive: true)) {
        if (entity is File && entity.path.contains('Episode $epNum')) return entity;
      }
    } catch (_) {}
    return null;
  }

  bool get _isTmdbAnime => anime['tmdbId'] != null;
  bool get _isTorrentProvider => currentProviderId.startsWith('torrent');

  void togglePlay() {
    if (useNativePlayer) {
      if (vpController != null) {
        vpController!.value.isPlaying ? vpController!.pause() : vpController!.play();
      }
    } else if (useWebViewPlayer) {
      if (webviewController != null && isWebviewInitialized) {
        (webviewController as dynamic).executeScript(playing ? "document.getElementById('video').pause()" :
        "document.getElementById('video').play()");
      }
    } else {
      player?.playOrPause();
    }
    startHideTimer();
  }
  
  void setPlaybackSpeed(double s) { 
    playbackSpeed = s; 
    if (useNativePlayer) {
      vpController?.setPlaybackSpeed(s);
    } else if (useWebViewPlayer) {
      if (webviewController != null && isWebviewInitialized) {
        (webviewController as dynamic).executeScript("document.getElementById('video').playbackRate = $s");
      }
    } else {
      player?.setRate(s); 
    }
    startHideTimer();
    _safeNotify(); 
  }

  void seekTo(Duration pos) async {
    if (useNativePlayer) {
      vpController?.seekTo(pos);
    } else if (useWebViewPlayer) {
      if (webviewController != null && isWebviewInitialized) {
        (webviewController as dynamic).executeScript("document.getElementById('video').currentTime = ${pos.inMilliseconds / 1000.0}");
      }
    } else {
      player?.seek(pos);
    }
    startHideTimer();
  }
  
  void setVolume(double v) { 
    volume = v; 
    if (useNativePlayer) {
      vpController?.setVolume(v / 100.0);
    } else if (useWebViewPlayer) {
      if (webviewController != null && isWebviewInitialized) {
        (webviewController as dynamic).executeScript("document.getElementById('video').volume = ${v / 100.0}");
      }
    } else {
      player?.setVolume(v); 
    }
    startHideTimer();
    _safeNotify(); 
  }
  void toggleSidePanel() { showSidePanel = !showSidePanel; _safeNotify(); }
  void toggleFullscreen() async {
    isFullscreen = !isFullscreen;
    AppShellController.isPlayerFullscreen.value = isFullscreen;
    if (isFullscreen) {
      // Hide side panel in fullscreen for immersive experience
      showSidePanel = false;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await defaultEnterNativeFullscreen();
    } else {
      // Restore side panel when exiting fullscreen
      showSidePanel = true;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await defaultExitNativeFullscreen();
    }
    _safeNotify();
  }

  Future<void> defaultEnterNativeFullscreen() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      try {
        appWindow.maximize();
      } catch (_) {}
    }
  }

  Future<void> defaultExitNativeFullscreen() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      try {
        appWindow.restore();
      } catch (_) {}
    }
  }
}
