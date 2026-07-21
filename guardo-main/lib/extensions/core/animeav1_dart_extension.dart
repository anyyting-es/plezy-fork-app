import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/app_models.dart';
import '../models/extension_manifest.dart';
import 'extension_base.dart';

class AnimeAv1DartExtension extends ExtensionBase {
  AnimeAv1DartExtension()
      : super(
          ExtensionManifest(
            id: 'animeav1_dart',
            name: 'AnimeAv1 (Dart)',
            version: '3.0.0',
            type: 'anime',
            language: 'dart',
            author: 'Antigravity',
            description: 'Dart port for animeav1 testing',
            baseUrl: 'https://animeav1.com',
          ),
        );

  @override
  Future<void> initialize() async {
    // Nothing to do
  }

  @override
  Future<List<SearchResult>> search(String query) async {
    final slug = query.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '-').replaceAll(RegExp(r'[^\w\-]+'), '');
    return [
      SearchResult(id: slug, title: query, slug: slug),
    ];
  }

  @override
  Future<AnimeDetailsResult> getDetails(String idOrUrl) async {
    final slug = idOrUrl;
    final episodes = <EpisodeInfo>[];
    
    final url = 'https://animeav1.com/media/$slug/__data.json';
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"},
      );
      
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final json = jsonDecode(resp.body);
        if (json['nodes'] != null) {
          for (final node in json['nodes']) {
            if (node == null || node['data'] == null) continue;
            
            final List<dynamic> nodeData = node['data'];
            Map<String, dynamic>? root;
            for (final item in nodeData) {
              if (item is Map && item.containsKey('episodes')) {
                root = item as Map<String, dynamic>;
                break;
              }
            }
            if (root == null) continue;
            
            final episodesPtr = root['episodes'];
            if (episodesPtr is int && episodesPtr < nodeData.length) {
              final epsList = nodeData[episodesPtr];
              if (epsList is List) {
                for (final epIdx in epsList) {
                  if (epIdx is int && epIdx < nodeData.length) {
                    final epMap = nodeData[epIdx];
                    if (epMap is Map) {
                      var numVal = epMap['number'];
                      if (numVal is int && numVal < nodeData.length) {
                        numVal = nodeData[numVal];
                      }
                      final number = int.tryParse(numVal.toString()) ?? 1;
                      
                      var titleVal = epMap['title'];
                      if (titleVal is int && titleVal < nodeData.length) {
                        titleVal = nodeData[titleVal];
                      }
                      
                      episodes.add(
                        EpisodeInfo(
                          id: jsonEncode({'slug': slug, 'number': number}),
                          number: number,
                          title: titleVal?.toString() ?? 'Episodio $number',
                        ),
                      );
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print("AnimeAv1DartExtension getDetails error: $e");
    }
    
    episodes.sort((a, b) => a.number.compareTo(b.number));

    if (episodes.isEmpty) {
      for (var i = 1; i <= 24; i++) {
        episodes.add(
          EpisodeInfo(
            id: jsonEncode({'slug': slug, 'number': i}),
            number: i,
            title: 'Episodio $i',
          ),
        );
      }
    }
    
    return AnimeDetailsResult(id: slug, title: slug, episodes: episodes);
  }

  @override
  Future<List<StreamLink>> extractVideos(String episodeIdOrUrl) async {
    dynamic data;
    try {
      data = jsonDecode(episodeIdOrUrl);
    } catch (_) {
      data = {'id': episodeIdOrUrl, 'number': 1};
    }
    
    final rawSlug = data['slug'] ?? data['id'] ?? 'unknown';
    final slug = rawSlug.toString().toLowerCase().trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^\w\-]+'), '')
        .replaceAll(RegExp(r'\-\-+'), '-')
        .replaceAll(RegExp(r'^-+'), '')
        .replaceAll(RegExp(r'-+$'), '');
    
    final number = data['number'] ?? data['episode'] ?? 1;
    final url = "https://animeav1.com/media/$slug/$number/__data.json";
    
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"},
      );
      
      if (resp.statusCode != 200 || resp.body.isEmpty) return [];
      
      final json = jsonDecode(resp.body);
      if (json['nodes'] == null) return [];
      
      final streams = <StreamLink>[];
      
      for (final node in json['nodes']) {
        if (node == null || node['data'] == null) continue;
        
        final List<dynamic> nodeData = node['data'];
        Map<String, dynamic>? root;
        for (final item in nodeData) {
          if (item is Map && item.containsKey('embeds')) {
            root = item as Map<String, dynamic>;
            break;
          }
        }
        if (root == null) continue;
        
        final embedsIndex = root['embeds'];
        if (embedsIndex == null || embedsIndex >= nodeData.length) continue;
        final embeds = nodeData[embedsIndex];
        if (embeds is! Map) continue;
        
        final listPtr = embeds['SUB'] ?? embeds['DUB'];
        if (listPtr == null || listPtr >= nodeData.length) continue;
        final list = nodeData[listPtr];
        if (list is! List) continue;
        
        for (final itemIdx in list) {
          if (itemIdx >= nodeData.length) continue;
          final srv = nodeData[itemIdx];
          if (srv is! Map) continue;
          
          String? name;
          String? link;
          
          if (srv['server'] is int && srv['server'] < nodeData.length) {
            name = nodeData[srv['server']].toString();
          } else {
            name = srv['server']?.toString();
          }
          
          if (srv['url'] is int && srv['url'] < nodeData.length) {
            link = nodeData[srv['url']].toString();
          } else {
            link = srv['url']?.toString();
          }
          
          if (link == null || name == null) continue;
          
          if (name.contains("HLS") || name == "HLS") {
            link = link.replaceAll("/play/", "/m3u8/");
            streams.add(StreamLink(url: link, quality: "HLS (Zilla)", isM3u8: true));
          } else {
            streams.add(StreamLink(url: link, quality: name, isM3u8: false));
          }
        }
      }
      
      return streams;
    } catch (e) {
      print("AnimeAv1DartExtension error: $e");
      return [];
    }
  }
  
  @override
  void dispose() {}
}
