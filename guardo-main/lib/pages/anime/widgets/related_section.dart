import 'package:flutter/material.dart';
import 'related_widgets.dart';
import '../anime_detail_page.dart';
import '../../../services/api_service.dart';
import '../../../models/app_models.dart';

class RelatedSection extends StatelessWidget {
  final Map<String, dynamic> anime;
  final int currentAnimeId;
  final bool forceAniList;
  final AppSettings settings;
  final ApiService api;

  const RelatedSection({
    super.key,
    required this.anime,
    required this.currentAnimeId,
    required this.forceAniList,
    required this.settings,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> relationsRaw = (anime['relations']?['edges'] as List?) ?? [];

    final List<Map<String, dynamic>> allRelated = [];

    // 1. Process AniList Relations
    for (final edge in relationsRaw) {
      if (edge is! Map) continue;
      final node = edge['node'];
      if (node is! Map) continue;

      final type = edge['relationType']?.toString() ?? 'RELACIÓN';
      final item = Map<String, dynamic>.from(node);
      item['relationLabel'] = _formatRelationType(type);
      allRelated.add(item);
    }

    // 2. Process AniList Recommendations
    final List<dynamic> recNodes = (anime['recommendations']?['nodes'] as List?) ?? [];
    for (final node in recNodes) {
      if (node is! Map) continue;
      final media = node['mediaRecommendation'];
      if (media is! Map) continue;

      final id = (media['id'] as num?)?.toInt();
      if (id == null || id == currentAnimeId) continue;

      final alreadyAdded = allRelated.any((r) => (r['id'] == id));
      if (!alreadyAdded) {
        final Map<String, dynamic> relatedItem = Map<String, dynamic>.from(media);
        relatedItem['relationLabel'] = 'RECOMENDADO';
        allRelated.add(relatedItem);
        if (allRelated.length >= 15) break;
      }
    }

    if (allRelated.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECOMENDADOS',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 320,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: allRelated.length,
            separatorBuilder: (context, index) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              final item = allRelated[index];
              return RelatedCard(
                item: item,
                onTap: () async {
                  int targetId = (item['id'] as num).toInt();
                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnimeDetailPage(
                        animeId: targetId,
                        forceAniList: forceAniList,
                        posterHeroTag: 'related-poster-$targetId',
                        titleHeroTag: 'related-title-$targetId',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatRelationType(String type) {
    switch (type) {
      case 'PREQUEL': return 'PRECUELA';
      case 'SEQUEL': return 'SECUELA';
      case 'PARENT': return 'HISTORIA PADRE';
      case 'SIDE_STORY': return 'HISTORIA LATERAL';
      case 'SPIN_OFF': return 'SPIN-OFF';
      case 'ALTERNATIVE': return 'VERSIÓN ALTERNATIVA';
      case 'OTHER': return 'OTROS';
      case 'SOURCE': return 'MANGA/NOVELA';
      default: return type.replaceAll('_', ' ');
    }
  }
}
