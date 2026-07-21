import 'package:flutter/material.dart';
import '../../../providers/torrent_provider.dart';
import '../../../services/api_service.dart';
import '../logic/watch_formatter.dart';

class TorrentStatusPanel extends StatelessWidget {
  final String infoHash;

  const TorrentStatusPanel({super.key, required this.infoHash});

  @override
  Widget build(BuildContext context) {
    if (infoHash.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<TorrentBackendInfo?>(
      stream: ApiService.instance.torrent.getTorrentStatusStream(infoHash),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final info = snapshot.data!;
        final progress = info.progress;
        final downloadSpeed = WatchFormatter.formatSize(info.downloadSpeed.toInt()) + '/s';
        final size = WatchFormatter.formatSize(info.size);
        final downloaded = WatchFormatter.formatSize(info.downloaded);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.downloading_rounded, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Descargando Torrent',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    '${progress.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: Colors.white10,
                  color: Colors.greenAccent,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(Icons.speed_rounded, downloadSpeed, Colors.blueAccent),
                  _buildStatItem(Icons.people_alt_rounded, '${info.seeders} Seeds', Colors.orangeAccent),
                  _buildStatItem(Icons.storage_rounded, '$downloaded / $size', Colors.grey),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
