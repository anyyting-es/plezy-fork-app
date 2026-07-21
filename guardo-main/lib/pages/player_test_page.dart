import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../mpv/player/player.dart';
import '../mpv/models.dart' as mpv_models;
import '../mpv/video.dart';

import '../services/app_shell_controller.dart';

class PlayerTestPage extends StatefulWidget {
  const PlayerTestPage({super.key});

  @override
  State<PlayerTestPage> createState() => _PlayerTestPageState();
}

class _PlayerTestPageState extends State<PlayerTestPage> {
  final _urlController = TextEditingController();

  // mpv player
  Player? _player;

  bool _loading = false;
  String? _error;
  String? _sourceLabel; // "URL" o nombre del archivo

  // Playback state
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _buffering = false;
  double _volume = 100;
  double _speed = 1.0;
  bool _showControls = true;
  bool _isDragging = false;

  double? _dragValue;
  double? _hoverX;
  Duration? _hoverTime;

  @override
  void dispose() {
    _disposePlayer();
    _urlController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    AppShellController.isPlayerFullscreen.value = false;
    super.dispose();
  }

  void _disposePlayer() {
    _player?.dispose();
    _player = null;
  }

  Future<void> _playUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await _startPlayback(url, label: 'Stream URL');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    await _startPlayback(path, label: result.files.single.name);
  }

  Future<void> _startPlayback(String source, {required String label}) async {
    _disposePlayer();
    setState(() {
      _loading = true;
      _error = null;
      _sourceLabel = label;
      _position = Duration.zero;
      _duration = Duration.zero;
      _playing = false;
      _buffering = false;
      _showControls = true;
    });

    try {
      _player = Player(useExoPlayer: false);

      try {
        await _player!.setProperty('demuxer-max-bytes', '134217728');
        await _player!.setProperty('demuxer-readahead-secs', '20');
        await _player!.setProperty('cache', 'yes');
        await _player!.setProperty('hr-seek', 'yes');
      } catch (_) {}

      _player!.streams.position.listen((p) {
        if (mounted && !_isDragging) setState(() => _position = p);
      });
      _player!.streams.duration.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _player!.streams.playing.listen((p) {
        if (mounted) setState(() => _playing = p);
      });
      _player!.streams.buffering.listen((b) {
        if (mounted) setState(() => _buffering = b);
      });
      _player!.streams.volume.listen((v) {
        if (mounted) setState(() => _volume = v);
      });
      _player!.streams.error.listen((e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Error: ${e.message}';
          });
        }
      });

      await _player!.open(mpv_models.Media(source));
      await _player!.play();

      if (!mounted) return;
      setState(() {
        _loading = false;
        _playing = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _togglePlay() => _player?.playOrPause();

  void _setVolume(double v) {
    _player?.setVolume(v);
    setState(() => _volume = v);
  }

  void _setSpeed(double s) {
    _player?.setRate(s);
    setState(() => _speed = s);
  }

  void _seekTo(Duration pos) => _player?.seek(pos);

  void _toggleFullscreen() {
    if (MediaQuery.of(context).orientation == Orientation.landscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      AppShellController.isPlayerFullscreen.value = false;
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      AppShellController.isPlayerFullscreen.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Probador de Reproductor',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // URL input row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: 'URL del stream',
                          hintText: 'https://...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _urlController.clear();
                              _disposePlayer();
                              setState(() {
                                _error = null;
                                _playing = false;
                                _sourceLabel = null;
                              });
                            },
                          ),
                        ),
                        onSubmitted: (_) => _playUrl(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _playUrl,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: const Text('Cargar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // File picker button
                OutlinedButton.icon(
                  onPressed: _loading ? null : _pickFile,
                  icon: const Icon(LucideIcons.folderOpen),
                  label: const Text('Abrir archivo de video local'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style:
                          TextStyle(color: colorScheme.error, fontSize: 13)),
                ],
              ],
            ),
          ),

          // Player area
          Expanded(child: _buildPlayerArea()),
        ],
      ),
    );
  }

  Widget _buildPlayerArea() {
    if (_loading) {
      return Container(
        color: Colors.black,
        child: const Center(
            child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (!_playing && _error != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    if (!_playing) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.tv, color: Colors.white24, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Ingresa una URL o selecciona\nun archivo de video local',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video fills the full area
          if (_player != null) RepaintBoundary(child: Video(player: _player!)),
          if (_buffering)
            const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          if (_showControls) _buildControlsOverlay(),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.2, 0.75, 1.0],
          colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87],
        ),
      ),
      child: Column(
        children: [
          // Top bar
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      _disposePlayer();
                      setState(() {
                        _playing = false;
                        _error = null;
                        _sourceLabel = null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Probador de Reproductor',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        if (_sourceLabel != null)
                          Text(
                            _sourceLabel!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Bottom bar
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSeekBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                            _playing ? LucideIcons.pause : LucideIcons.play,
                            color: Colors.white),
                        onPressed: _togglePlay,
                      ),
                      IconButton(
                        icon: Icon(
                          _volume == 0
                              ? LucideIcons.volumeX
                              : (_volume > 50
                                  ? LucideIcons.volume2
                                  : LucideIcons.volume1),
                          color: Colors.white,
                        ),
                        onPressed: () => _setVolume(_volume == 0 ? 100 : 0),
                      ),
                      SizedBox(
                        width: 90,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _volume.clamp(0.0, 100.0),
                            max: 100,
                            onChanged: _setVolume,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_fmt(_position)} / ${_fmt(_duration)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const Spacer(),
                      // Speed selector
                      PopupMenuButton<double>(
                        color: Colors.grey[900],
                        icon: Text('${_speed}x',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        onSelected: _setSpeed,
                        itemBuilder: (_) =>
                            [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                                .map((s) => PopupMenuItem(
                                      value: s,
                                      child: Text('${s}x',
                                          style: TextStyle(
                                              color: _speed == s
                                                  ? Colors.blueAccent
                                                  : Colors.white)),
                                    ))
                                .toList(),
                      ),
                      IconButton(
                        icon: Icon(
                          MediaQuery.of(context).orientation ==
                                  Orientation.landscape
                              ? LucideIcons.minimize
                              : LucideIcons.maximize,
                          color: Colors.white,
                        ),
                        onPressed: _toggleFullscreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar() {
    final maxMs =
        (_duration.inMilliseconds.toDouble()).clamp(1.0, double.infinity);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return MouseRegion(
            onHover: (e) {
              final trackWidth = constraints.maxWidth - 12;
              if (trackWidth <= 0) return;
              final percent =
                  ((e.localPosition.dx - 6) / trackWidth).clamp(0.0, 1.0);
              setState(() {
                _hoverX = e.localPosition.dx;
                _hoverTime = _duration * percent;
              });
            },
            onExit: (_) => setState(() {
              _hoverX = null;
              _hoverTime = null;
            }),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: (_dragValue ??
                            _position.inMilliseconds.toDouble())
                        .clamp(0, maxMs),
                    max: maxMs,
                    onChangeStart: (val) {
                      _isDragging = true;
                      setState(() => _dragValue = val);
                    },
                    onChanged: (val) => setState(() => _dragValue = val),
                    onChangeEnd: (val) {
                      _isDragging = false;
                      _seekTo(Duration(milliseconds: val.toInt()));
                      setState(() => _dragValue = null);
                    },
                  ),
                ),
                if (_hoverX != null && _hoverTime != null)
                  Positioned(
                    left: _hoverX!,
                    bottom: 44,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _fmt(_hoverTime!),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
