import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/app_models.dart' as models;
import '../../../services/real_debrid_service.dart';
import '../../../widgets/media_widgets.dart';
import '../logic/watch_formatter.dart';

class TorrentSelectorSheet extends StatefulWidget {
  final Future<List<models.StreamLink>> streamsFuture;
  final Map<String, dynamic> anime;
  final List<models.EpisodeInfo> episodes;
  final int currentEpisodeNumber;
  final String currentProviderId;
  final Function(int) onEpisodeChanged;
  final Function(String) onProviderChanged;
  final bool useRealDebrid;
  final Function(bool) onRealDebridChanged;

  const TorrentSelectorSheet({
    super.key,
    required this.streamsFuture,
    required this.anime,
    required this.episodes,
    required this.currentEpisodeNumber,
    required this.currentProviderId,
    required this.onEpisodeChanged,
    required this.onProviderChanged,
    required this.useRealDebrid,
    required this.onRealDebridChanged,
  });

  @override
  State<TorrentSelectorSheet> createState() => _TorrentSelectorSheetState();
}

class _TorrentSelectorSheetState extends State<TorrentSelectorSheet> {
  late Future<List<models.StreamLink>> _streamsFuture;
  late int _currentEpNum;
  late String _currentProviderId;
  late bool _useRealDebrid;

  @override
  void initState() {
    super.initState();
    _streamsFuture = widget.streamsFuture;
    _currentEpNum = widget.currentEpisodeNumber;
    _currentProviderId = widget.currentProviderId;
    _useRealDebrid = widget.useRealDebrid;
  }

  String _currentTorrentPosterUrl() {
    final banner = widget.anime['bannerImage']?.toString() ?? '';
    if (banner.isNotEmpty) return banner;

    return (widget.anime['coverImage']?['extraLarge'] ??
            widget.anime['coverImage']?['large'] ??
            widget.anime['coverImage']?['medium'] ??
            '')
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final preferredWidth = media.width > 1520 ? 1520.0 : media.width * 0.94;
    final innerScheme = Theme.of(context).colorScheme;
    
    final coverColorHex = widget.anime['coverImage']?['color'] as String?;
    final seedColor = WatchFormatter.tryParseHexColor(coverColorHex ?? '') ?? innerScheme.primary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: preferredWidth),
          child: Container(
            margin: EdgeInsets.only(
              top: 12,
              left: media.width > 900 ? 12 : 0,
              right: media.width > 900 ? 12 : 0,
              bottom: 0,
            ),
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              color: innerScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: innerScheme.outlineVariant.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: innerScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AppCachedImage(
                          _currentTorrentPosterUrl(),
                          width: 90,
                          height: 128,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (widget.anime['title']?['romaji'] ?? widget.anime['title']?['english'] ?? 'Anime').toString(),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: innerScheme.onSurface,
                                letterSpacing: -0.6,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildHeaderTag(
                                  context: context,
                                  label: 'Episodio $_currentEpNum',
                                  accent: innerScheme.primary,
                                ),
                                _buildHeaderTag(
                                  context: context,
                                  label: _currentProviderId.contains('nyaa') ? 'Nyaa' : 'AnimeTosho',
                                  accent: innerScheme.secondary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.cloud_outlined,
                                  size: 16,
                                  color: _useRealDebrid ? Colors.green : innerScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'DEBRID',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: _useRealDebrid ? Colors.green : innerScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                                const Spacer(),
                                SizedBox(
                                  height: 28,
                                  child: Switch(
                                    value: _useRealDebrid,
                                    onChanged: (v) {
                                      setState(() => _useRealDebrid = v);
                                      widget.onRealDebridChanged(v);
                                    },
                                    activeThumbColor: Colors.green,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<models.StreamLink>>(
                  future: _streamsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        height: media.height * 0.4,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          'Error al buscar torrents: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: innerScheme.onSurfaceVariant),
                        ),
                      );
                    }

                    final streams = snapshot.data ?? [];
                    if (streams.isEmpty) {
                      return SizedBox(
                        height: media.height * 0.3,
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Text('No se encontraron streams de torrent.', textAlign: TextAlign.center),
                          ),
                        ),
                      );
                    }

                    if (_useRealDebrid && RealDebridService.instance.isConfigured) {
                      final hashes = streams
                          .where((s) => s.headers?['infoHash'] != null)
                          .map((s) => s.headers!['infoHash']!)
                          .toList();

                      return FutureBuilder<Set<String>>(
                        future: RealDebridService.instance.checkInstantAvailability(hashes),
                        builder: (ctx, rdSnapshot) {
                          final cachedHashes = rdSnapshot.data ?? {};
                          return _buildStreamsList(context, streams, cachedHashes, seedColor);
                        },
                      );
                    }

                    return _buildStreamsList(context, streams, {}, seedColor);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreamsList(BuildContext context, List<models.StreamLink> streams, Set<String> cachedHashes, Color seedColor) {
    final media = MediaQuery.of(context).size;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.height * 0.58),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: streams.length,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemBuilder: (ctx, index) {
          final stream = streams[index];
          final hash = stream.headers?['infoHash']?.toLowerCase() ?? '';
          return TorrentResultCard(
            stream: stream,
            accent: seedColor,
            bannerUrl: _currentTorrentPosterUrl(),
            isRdCached: cachedHashes.contains(hash),
            onTap: () => Navigator.pop(context, stream),
          );
        },
      ),
    );
  }

  Widget _buildHeaderTag({
    required BuildContext context,
    required String label,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class TorrentResultCard extends StatelessWidget {
  final models.StreamLink stream;
  final Color accent;
  final String bannerUrl;
  final bool isRdCached;
  final VoidCallback onTap;

  const TorrentResultCard({
    super.key,
    required this.stream,
    required this.accent,
    required this.bannerUrl,
    required this.isRdCached,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headers = stream.headers ?? const <String, String>{};
    final isTorrentio = headers['provider'] == 'torrentio';
    final rawTitle = (headers[isTorrentio ? 'title' : 'torrentTitle'] ?? '').trim();
    final displayTitle = rawTitle.isNotEmpty ? WatchFormatter.compactTorrentTitle(rawTitle) : stream.quality;
    final source = isTorrentio ? (headers['source'] ?? '') : WatchFormatter.normalizeTorrentSource(headers['torrentSource'] ?? '');
    final group = (headers['torrentGroup'] ?? '').trim();
    final provider = isTorrentio ? source : WatchFormatter.extractReleaseProvider(rawTitle, fallback: group);

    final sizeHeader = headers[isTorrentio ? 'size' : 'torrentSize'] ?? '';
    final sizeText = isTorrentio ? sizeHeader : (int.tryParse(sizeHeader) ?? 0) > 0 ? WatchFormatter.formatSize(int.parse(sizeHeader)) : '';
    final resolution = isTorrentio ? stream.quality : (headers['torrentResolution'] ?? '').trim();
    final isCached = isRdCached || headers['isRdCached'] == 'true';
    final seeders = int.tryParse(headers['torrentSeeders'] ?? '') ?? WatchFormatter.extractSeedersFromQuality(stream.quality);
    final badges = WatchFormatter.extractTorrentBadges(rawTitle.isNotEmpty ? rawTitle : stream.quality, resolution: resolution);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (bannerUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                      child: SizedBox(
                        width: 130,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AppCachedImage(bannerUrl, fit: BoxFit.cover),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.black.withValues(alpha: 0.2), Colors.black.withValues(alpha: 0.7)],
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      provider,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                    ),
                                    if (resolution.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: scheme.primary.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(resolution, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (bannerUrl.isNotEmpty) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (isCached)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                                ),
                                child: const Text('⚡ RD+', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            if (source.isNotEmpty && source.toLowerCase() != 'animetosho')
                              _buildBadge(context, source, accent.withValues(alpha: 0.6)),
                            if (provider.isEmpty && group.isNotEmpty)
                              _buildBadge(context, group, accent.withValues(alpha: 0.6)),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isCached ? Colors.greenAccent : scheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (badges.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: badges.map((b) => _buildBadge(context, b, accent)).toList(),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            if (seeders > 0) _buildStat(Icons.wifi_tethering_rounded, '$seeders seeders', Colors.greenAccent),
                            if (sizeText.isNotEmpty) _buildStat(Icons.save_outlined, sizeText, scheme.onSurfaceVariant),
                            if (group.isNotEmpty) _buildStat(Icons.groups_rounded, group, Colors.amberAccent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
