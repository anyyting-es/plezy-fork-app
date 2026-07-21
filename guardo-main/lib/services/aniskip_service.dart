import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/app_models.dart';

class AniSkipService {
  static const _baseUrl = 'https://api.aniskip.com/v2';
  
  static Future<List<SkipTime>> getSkipTimes({
    required int malId,
    required int episodeNumber,
    double episodeLength = 0.0,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/skip-times/$malId/$episodeNumber?types=op&types=ed&episodeLength=$episodeLength');
      final res = await http.get(url);
      
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['found'] == true) {
          final results = json['results'] as List<dynamic>?;
          if (results != null) {
            return results.map((e) => SkipTime.fromJson(e)).toList();
          }
        }
      }
    } catch (_) {
      // Ignorar errores y devolver lista vacía
    }
    return [];
  }
}
