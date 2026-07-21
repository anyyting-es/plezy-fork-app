import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../logic/watch_controller.dart';
import '../../../mpv/models.dart';

class PlayerSettingsPanel extends StatefulWidget {
  final WatchController controller;
  final VoidCallback onClose;

  const PlayerSettingsPanel({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  State<PlayerSettingsPanel> createState() => _PlayerSettingsPanelState();
}

enum _SettingsPage { main, tracks, audio, subtitles, speed }

class _PlayerSettingsPanelState extends State<PlayerSettingsPanel> {
  _SettingsPage _currentPage = _SettingsPage.main;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360, // Restored original width
      color: Colors.black, // Solid black background
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildCurrentPage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title = 'Settings';
    if (_currentPage == _SettingsPage.tracks) title = 'Audio & Subtitles';
    if (_currentPage == _SettingsPage.audio) title = 'Audio';
    if (_currentPage == _SettingsPage.subtitles) title = 'Subtitles';
    if (_currentPage == _SettingsPage.speed) title = 'Playback Speed';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8, left: 16, right: 16),
        child: Row(
          children: [
            if (_currentPage != _SettingsPage.main) ...[
              IconButton(
                icon: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (_currentPage == _SettingsPage.audio || _currentPage == _SettingsPage.subtitles) {
                    setState(() => _currentPage = _SettingsPage.tracks);
                  } else {
                    setState(() => _currentPage = _SettingsPage.main);
                  }
                },
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 18, 
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, color: Colors.white54, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case _SettingsPage.main:
        return _buildMainPage();
      case _SettingsPage.tracks:
        return _buildTracksPage();
      case _SettingsPage.audio:
        return _buildAudioPage();
      case _SettingsPage.subtitles:
        return _buildSubtitlesPage();
      case _SettingsPage.speed:
        return _buildSpeedPage();
    }
  }

  Widget _buildMainPage() {
    return _SettingsGroup(
      children: [
        _SettingsItem(
          icon: LucideIcons.gauge,
          title: 'Playback Speed',
          trailingText: '${widget.controller.player?.state.rate ?? 1.0}x',
          onTap: () => setState(() => _currentPage = _SettingsPage.speed),
        ),
        _SettingsItem(
          icon: LucideIcons.appWindow,
          title: 'Audio & Subtitles',
          trailingText: 'Tracks',
          onTap: () => setState(() => _currentPage = _SettingsPage.tracks),
        ),
      ],
    );
  }

  Widget _buildTracksPage() {
    final player = widget.controller.player;
    final currentAudio = player?.state.track.audio;
    final currentSub = player?.state.track.subtitle;

    return _SettingsGroup(
      children: [
        _SettingsItem(
          icon: LucideIcons.mic,
          title: 'Audio',
          trailingText: currentAudio?.displayName ?? 'None',
          onTap: () => setState(() => _currentPage = _SettingsPage.audio),
        ),
        _SettingsItem(
          icon: LucideIcons.messageSquare,
          title: 'Subtitles',
          trailingText: currentSub?.displayName ?? 'None',
          onTap: () => setState(() => _currentPage = _SettingsPage.subtitles),
        ),
      ],
    );
  }

  Widget _buildAudioPage() {
    final player = widget.controller.player;
    if (player == null) return const SizedBox();
    
    final tracks = player.state.tracks.audio;
    final currentTrack = player.state.track.audio;

    return _SettingsGroup(
      children: [
        _SettingsCheckItem(
          title: 'Off',
          isSelected: currentTrack == AudioTrack.off,
          onTap: () {
            player.selectAudioTrack(AudioTrack.off);
            setState(() {});
          },
        ),
        for (final track in tracks)
          _SettingsCheckItem(
            title: track.displayName,
            isSelected: currentTrack == track,
            onTap: () {
              player.selectAudioTrack(track);
              setState(() {});
            },
          ),
      ],
    );
  }

  Widget _buildSubtitlesPage() {
    final player = widget.controller.player;
    if (player == null) return const SizedBox();
    
    final tracks = player.state.tracks.subtitle;
    final currentTrack = player.state.track.subtitle;

    return _SettingsGroup(
      children: [
        _SettingsCheckItem(
          title: 'Off',
          isSelected: currentTrack == SubtitleTrack.off,
          onTap: () {
            player.selectSubtitleTrack(SubtitleTrack.off);
            setState(() {});
          },
        ),
        for (final track in tracks)
          _SettingsCheckItem(
            title: track.displayName,
            isSelected: currentTrack == track,
            onTap: () {
              player.selectSubtitleTrack(track);
              setState(() {});
            },
          ),
      ],
    );
  }

  Widget _buildSpeedPage() {
    final player = widget.controller.player;
    if (player == null) return const SizedBox();
    
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentSpeed = player.state.rate;

    return _SettingsGroup(
      children: [
        for (final speed in speeds)
          _SettingsCheckItem(
            title: speed == 1.0 ? 'Normal' : '${speed}x',
            isSelected: currentSpeed == speed,
            onTap: () {
              player.setRate(speed);
              setState(() {});
            },
          ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03), // Subtle grouped background
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1, 
                    thickness: 1, 
                    color: Colors.white.withValues(alpha: 0.05),
                    indent: 52, // Align with text
                  ),
              ]
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String trailingText;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.trailingText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title, 
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                trailingText, 
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), 
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, color: Colors.white.withValues(alpha: 0.3), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCheckItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SettingsCheckItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const SizedBox(width: 30), // Align with standard items
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                Icon(LucideIcons.check, color: Theme.of(context).colorScheme.primary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
