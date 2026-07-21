import 'package:flutter/material.dart';
import '../../../models/app_models.dart' as models;
import '../../../widgets/media_widgets.dart';
import 'torrent_status_panel.dart';

class WatchSidePanel extends StatelessWidget {
  final List<models.EpisodeInfo> episodes;
  final int currentEpNum;
  final Function(int) onEpisodeTap;
  final ScrollController scrollController;
  final VoidCallback onShowProviders;
  final String currentProviderId;
  final String? infoHash;
  final String animeTitle;

  const WatchSidePanel({
    super.key,
    required this.episodes,
    required this.currentEpNum,
    required this.onEpisodeTap,
    required this.scrollController,
    required this.onShowProviders,
    required this.currentProviderId,
    required this.animeTitle,
    this.infoHash,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Column(
        children: [
          _buildHeader(context),
          if (infoHash != null && infoHash!.isNotEmpty && currentProviderId == 'torrent')
            TorrentStatusPanel(infoHash: infoHash!),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final currentEp = episodes.firstWhere((e) => e.number == currentEpNum, orElse: () => episodes.first);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EPISODIO $currentEpNum',
                      style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentEp.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      animeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Moved the provider button to a more prominent place below
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onShowProviders,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      currentProviderId.contains('torrent') ? Icons.cloud_download_outlined : Icons.language_outlined,
                      size: 14,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentProviderId.contains('torrent') ? 'AnimeTosho' : 'Extension',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.white38),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
