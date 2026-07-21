import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../logic/watch_controller.dart';
import '../../../mpv/models.dart';

import 'player_settings_panel.dart';

enum _FeedbackType { volume, brightness, seek }

class PlayerControls extends StatefulWidget {
  final WatchController controller;
  final String animeTitle;
  final bool isWide;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onBack;
  final VoidCallback onNextEpisode;
  final Widget? centerOverlay;

  const PlayerControls({
    super.key,
    required this.controller,
    required this.animeTitle,
    required this.isWide,
    required this.onToggleFullscreen,
    required this.onBack,
    required this.onNextEpisode,
    this.centerOverlay,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _isLocked = false;
  bool _showSettingsPanel = false;
  
  // Feedback state
  _FeedbackType? _activeFeedback;
  double _feedbackValue = 0.0;
  String _feedbackText = '';
  Timer? _feedbackTimer;
  double _mockBrightness = 0.5;

  void _showFeedback(_FeedbackType type, {double value = 0.0, String text = ''}) {
    setState(() {
      _activeFeedback = type;
      _feedbackValue = value;
      _feedbackText = text;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _activeFeedback = null);
    });
  }

  void _toggleSettingsPanel() {
    setState(() {
      _showSettingsPanel = !_showSettingsPanel;
      widget.controller.isSettingsOpen = _showSettingsPanel;
      if (_showSettingsPanel) {
        widget.controller.showControlsForce();
      } else {
        widget.controller.startHideTimer();
      }
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return _buildLockedOverlay();
    }

    return Stack(
      children: [
        // Background for gestures and tap to toggle
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              if (_showSettingsPanel) {
                _toggleSettingsPanel();
              } else {
                widget.controller.toggleControls();
              }
            },
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),

        // Gestures Layer
        Positioned.fill(
          child: _PlayerGestureOverlay(
            controller: widget.controller,
            brightness: _mockBrightness,
            onVolumeChanged: (v) {
              widget.controller.setVolume(v);
              _showFeedback(_FeedbackType.volume, value: v / 100.0);
            },
            onBrightnessChanged: (b) {
              setState(() => _mockBrightness = b);
              _showFeedback(_FeedbackType.brightness, value: b);
            },
            onSeek: (delta) {
              final newPos = widget.controller.displayPosition + Duration(seconds: delta);
              widget.controller.seekTo(newPos);
              _showFeedback(_FeedbackType.seek, text: delta > 0 ? '+$delta s' : '$delta s');
            },
          ),
        ),

        // Top Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: widget.controller.showControls && !_showSettingsPanel ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !widget.controller.showControls || _showSettingsPanel,
              child: _TopBar(
                title: widget.animeTitle,
                episode: 'Episodio ${widget.controller.currentEpNum}',
                onBack: widget.onBack,
                actions: [
                  _ControlIconButton(
                    icon: LucideIcons.settings,
                    onPressed: _toggleSettingsPanel,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom Bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: widget.controller.showControls && !_showSettingsPanel ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !widget.controller.showControls || _showSettingsPanel,
              child: _BottomBar(
                controller: widget.controller,
                isWide: widget.isWide,
                onToggleFullscreen: widget.onToggleFullscreen,
                onNextEpisode: widget.onNextEpisode,
                onLock: () => setState(() => _isLocked = true),
              ),
            ),
          ),
        ),

        if (widget.centerOverlay != null)
          Center(child: widget.centerOverlay),
        
        // Feedback Layer
        if (_activeFeedback != null)
          _PlayerFeedbackLayer(
            type: _activeFeedback!,
            value: _feedbackValue,
            text: _feedbackText,
          ),

        // Settings Panel Layer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          right: _showSettingsPanel ? 0 : -360, // Wider panel
          top: 0,
          bottom: 0,
          child: PlayerSettingsPanel(
            controller: widget.controller,
            onClose: _toggleSettingsPanel,
          ),
        ),
      ],
    );
  }

  Widget _buildLockedOverlay() {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.controller.toggleControls,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          right: 24,
          top: 0,
          bottom: 0,
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: widget.controller.showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !widget.controller.showControls,
                child: _ControlIconButton(
                  icon: Icons.lock_outline_rounded,
                  size: 28,
                  onPressed: () => setState(() => _isLocked = false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String episode;
  final VoidCallback onBack;
  final List<Widget> actions;

  const _TopBar({
    required this.title,
    required this.episode,
    required this.onBack,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4, 1.0],
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
              onPressed: onBack,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    episode,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final WatchController controller;
  final bool isWide;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onNextEpisode;
  final VoidCallback onLock;

  const _BottomBar({
    required this.controller,
    required this.isWide,
    required this.onToggleFullscreen,
    required this.onNextEpisode,
    required this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0.0, 0.4, 1.0],
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Time
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Row(
                children: [
                  Text(
                    _formatDuration(controller.displayPosition),
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(' / ', style: TextStyle(color: Colors.white24, fontSize: 12)),
                  Text(
                    _formatDuration(controller.displayDuration),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), 
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Row 2: Progress Slider
            _PlayerProgressSlider(
              value: controller.displayPosition.inMilliseconds.toDouble(),
              max: controller.displayDuration.inMilliseconds.toDouble(),
              onChanged: (val) {
                controller.seekTo(Duration(milliseconds: val.toInt()));
              },
              activeColor: primaryColor,
              controller: controller,
            ),

            // Row 3: Controls
            Row(
              children: [
                _ControlIconButton(
                  icon: controller.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 38,
                  onPressed: controller.togglePlay,
                ),
                _ControlIconButton(
                  icon: Icons.skip_next_rounded,
                  size: 32,
                  onPressed: onNextEpisode,
                ),
                const SizedBox(width: 8),
                
                _VolumeControl(controller: controller),
                
                const Spacer(),
                
                _ControlIconButton(
                  icon: Icons.lock_open_rounded,
                  size: 24,
                  onPressed: onLock,
                ),

                const SizedBox(width: 8),

                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    // Logic for speed selector could be here
                  },
                  child: Text(
                    '${controller.player?.state.rate ?? 1.0}x',
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 14,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                
                _ControlIconButton(
                  icon: controller.isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  size: 32,
                  onPressed: onToggleFullscreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ControlIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final double size;

  const _ControlIconButton({
    required this.icon,
    required this.onPressed,
    this.isActive = true,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        color: isActive ? Colors.white : Colors.white38,
        size: size,
      ),
      onPressed: onPressed,
    );
  }
}

class _VolumeControl extends StatefulWidget {
  final WatchController controller;

  const _VolumeControl({required this.controller});

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  bool _showSlider = false;

  @override
  Widget build(BuildContext context) {
    final volume = widget.controller.volume;
    final icon = volume == 0 
        ? Icons.volume_off_rounded 
        : (volume < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded);

    return MouseRegion(
      onEnter: (_) => setState(() => _showSlider = true),
      onExit: (_) => setState(() => _showSlider = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlIconButton(
            icon: icon,
            onPressed: () => widget.controller.setVolume(volume == 0 ? 100 : 0),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: _showSlider ? 100 : 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: 100,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    value: volume.clamp(0.0, 100.0),
                    max: 100,
                    onChanged: widget.controller.setVolume,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerProgressSlider extends StatefulWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final Color activeColor;
  final WatchController controller;

  const _PlayerProgressSlider({
    required this.value,
    required this.max,
    required this.onChanged,
    required this.activeColor,
    required this.controller,
  });

  @override
  State<_PlayerProgressSlider> createState() => _PlayerProgressSliderState();
}

class _PlayerProgressSliderState extends State<_PlayerProgressSlider> {
  bool _isDragging = false;
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: widget.activeColor,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
        thumbColor: widget.activeColor,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 6, // Constant size like Animeko
          elevation: 2,
          pressedElevation: 4,
        ), 
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        trackShape: const _PlayerSliderTrackShape(),
      ),
      child: Slider(
        value: (_dragValue ?? widget.value).clamp(0, widget.max),
        max: widget.max.clamp(1, double.infinity),
        onChangeStart: (v) {
          setState(() {
            _isDragging = true;
            _dragValue = v;
          });
          widget.controller.isDragging = true;
          widget.controller.showControlsForce();
        },
        onChangeEnd: (v) {
          setState(() {
            _isDragging = false;
            _dragValue = null;
          });
          widget.controller.isDragging = false;
          widget.onChanged(v);
        },
        onChanged: (v) {
          setState(() => _dragValue = v);
          widget.controller.showControlsForce();
        },
      ),
    );
  }
}

class _PlayerSliderTrackShape extends RoundedRectSliderTrackShape {
  const _PlayerSliderTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }

    final Paint activePaint = Paint()..color = sliderTheme.activeTrackColor!;
    final Paint inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor!;

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Radius trackRadius = Radius.circular(trackRect.height / 2);

    context.canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        trackRect.left,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
        topLeft: trackRadius,
        bottomLeft: trackRadius,
        topRight: trackRadius,
        bottomRight: trackRadius,
      ),
      inactivePaint,
    );
    
    context.canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        trackRect.left,
        trackRect.top,
        thumbCenter.dx,
        trackRect.bottom,
        topLeft: trackRadius,
        bottomLeft: trackRadius,
        topRight: thumbCenter.dx >= trackRect.right ? trackRadius : Radius.zero,
        bottomRight: thumbCenter.dx >= trackRect.right ? trackRadius : Radius.zero,
      ),
      activePaint,
    );
  }
}

class _PlayerGestureOverlay extends StatefulWidget {
  final WatchController controller;
  final double brightness;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<int> onSeek;

  const _PlayerGestureOverlay({
    required this.controller,
    required this.brightness,
    required this.onVolumeChanged,
    required this.onBrightnessChanged,
    required this.onSeek,
  });

  @override
  State<_PlayerGestureOverlay> createState() => _PlayerGestureOverlayState();
}

class _PlayerGestureOverlayState extends State<_PlayerGestureOverlay> {
  double _verticalDelta = 0;
  double _horizontalDelta = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        final xPos = details.globalPosition.dx;
        
        setState(() {
          _verticalDelta -= details.primaryDelta! / 2;
        });

        if (xPos > screenWidth / 2) {
          final newVol = (widget.controller.volume + _verticalDelta).clamp(0.0, 100.0);
          widget.onVolumeChanged(newVol);
        } else {
          final newBri = (widget.brightness + _verticalDelta / 100.0).clamp(0.0, 1.0);
          widget.onBrightnessChanged(newBri);
        }
        _verticalDelta = 0;
      },
      onHorizontalDragUpdate: (details) {
        setState(() {
          _horizontalDelta += details.primaryDelta!;
        });
        
        if (_horizontalDelta.abs() > 40) {
          final seconds = (_horizontalDelta / 20).toInt();
          widget.onSeek(seconds);
          _horizontalDelta = 0;
        }
      },
      behavior: HitTestBehavior.translucent,
    );
  }
}

class _PlayerFeedbackLayer extends StatelessWidget {
  final _FeedbackType type;
  final double value;
  final String text;

  const _PlayerFeedbackLayer({
    required this.type,
    required this.value,
    this.text = '',
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case _FeedbackType.volume:
        icon = value == 0 ? Icons.volume_off_rounded : (value < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded);
        break;
      case _FeedbackType.brightness:
        icon = value < 0.33 ? Icons.brightness_low_rounded : (value < 0.67 ? Icons.brightness_medium_rounded : Icons.brightness_high_rounded);
        break;
      case _FeedbackType.seek:
        icon = text.startsWith('+') ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded;
        break;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            if (type != _FeedbackType.seek) ...[
              const SizedBox(width: 12),
              _FeedbackProgressBar(value: value),
            ] else if (text.isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedbackProgressBar extends StatelessWidget {
  final double value;

  const _FeedbackProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Container(
          width: 100,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Container(
          width: 100 * value,
          height: 4,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // The "DOT" indicator at the end of the progress
        Positioned(
          left: (100 * value) - 3,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
