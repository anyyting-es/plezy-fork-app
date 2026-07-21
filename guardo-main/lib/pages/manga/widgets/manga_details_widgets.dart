import 'package:flutter/material.dart';
import '../../../widgets/media_widgets.dart';

class CharacterSectionWidget extends StatelessWidget {
  final List<dynamic> characters;
  const CharacterSectionWidget({super.key, required this.characters});

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 40, 16, 16),
          child: Text('REPARTO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
        ),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: characters.length,
            itemBuilder: (context, index) {
              final char = characters[index]['node'];
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      width: 85, height: 115,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: (char['image']?['large']?.toString().isNotEmpty == true)
                            ? DecorationImage(image: NetworkImage(char['image']!['large']), fit: BoxFit.cover)
                            : null,
                      )
                    ),
                    const SizedBox(height: 8),
                    Text(char['name']?['full'] ?? '?', maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(characters[index]['role'] ?? '', style: const TextStyle(fontSize: 9, color: Colors.white38)),
                  ]
                )
              );
            },
          ),
        ),
      ],
    );
  }
}

class StaffSectionWidget extends StatelessWidget {
  final List<dynamic> staff;
  const StaffSectionWidget({super.key, required this.staff});

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 40, 16, 16),
          child: Text('STAFF', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
        ),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: staff.length,
            itemBuilder: (context, index) {
              final member = staff[index]['node'];
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      width: 85, height: 115,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: (member['image']?['large']?.toString().isNotEmpty == true)
                            ? DecorationImage(image: NetworkImage(member['image']!['large']), fit: BoxFit.cover)
                            : null,
                      )
                    ),
                    const SizedBox(height: 8),
                    Text(member['name']?['full'] ?? '?', maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(staff[index]['role'] ?? '', style: const TextStyle(fontSize: 9, color: Colors.white38)),
                  ]
                )
              );
            },
          ),
        ),
      ],
    );
  }
}

class RelationSectionWidget extends StatelessWidget {
  final List<dynamic> relations;
  final Function(int, String, {String? posterHeroTag, String? titleHeroTag}) onMediaTap;
  const RelationSectionWidget({super.key, required this.relations, required this.onMediaTap});

  @override
  Widget build(BuildContext context) {
    if (relations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 48, 16, 16),
          child: Text('RELACIONES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16)),
        ),
        SizedBox(
          height: 310,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: relations.length,
            itemBuilder: (context, index) {
              final edge = relations[index];
              final node = edge['node'];
              final id = (node['id'] as num).toInt();
              final type = node['type']?.toString() ?? 'ANIME';
              
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: MediaCard(
                  item: Map<String, dynamic>.from(node),
                  onTap: () => onMediaTap(
                    id,
                    type,
                    posterHeroTag: 'relation-$id',
                    titleHeroTag: 'relation-title-$id',
                  ),
                  heroTagPrefix: 'relation',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
