import 'dart:ui';

class WatchFormatter {
  static String formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  static String compactTorrentTitle(String title) {
    return title
        .replaceAll(RegExp(r'^\[[^\]]+\]\s*'), '')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String extractReleaseProvider(String rawTitle, {String fallback = ''}) {
    final firstBracket =
        RegExp(r'^\[([^\]]+)\]').firstMatch(rawTitle)?.group(1)?.trim() ?? '';
    if (firstBracket.isNotEmpty) return firstBracket;
    return fallback;
  }

  static String normalizeTorrentSource(String source) {
    final lower = source.trim().toLowerCase();
    if (lower == 'nyaa') return 'Nyaa';
    if (lower == 'animetosho') return 'AnimeTosho';
    return source;
  }

  static int extractSeedersFromQuality(String quality) {
    final m = RegExp(
      r'(\d+)\s*seeders',
      caseSensitive: false,
    ).firstMatch(quality);
    return int.tryParse(m?.group(1) ?? '') ?? 0;
  }

  static List<String> extractTorrentBadges(String raw, {String resolution = ''}) {
    final lower = raw.toLowerCase();
    final out = <String>[];

    void addIf(bool cond, String label) {
      if (cond && !out.contains(label)) out.add(label);
    }

    if (resolution.isNotEmpty) {
      out.add(resolution);
    } else {
      final res = RegExp(
        r'\b(2160p|1080p|720p|480p)\b',
        caseSensitive: false,
      ).firstMatch(raw)?.group(1);
      if (res != null && res.isNotEmpty) out.add(res.toUpperCase());
    }

    addIf(RegExp(r'\b(hevc|h\.?265|x265)\b', caseSensitive: false).hasMatch(raw), 'HEVC');
    addIf(RegExp(r'\b(avc|h\.?264|x264)\b', caseSensitive: false).hasMatch(raw), 'H.264');
    addIf(RegExp(r'\bav1\b', caseSensitive: false).hasMatch(raw), 'AV1');
    addIf(RegExp(r'\b10[\s-]?bit\b', caseSensitive: false).hasMatch(raw), '10-bit');
    addIf(RegExp(r'\b8[\s-]?bit\b', caseSensitive: false).hasMatch(raw), '8-bit');
    addIf(RegExp(r'\b(hdr10\+?|hdr)\b', caseSensitive: false).hasMatch(raw), 'HDR');
    addIf(RegExp(r'\bdv\b|dolby\s*vision', caseSensitive: false).hasMatch(raw), 'Dolby Vision');
    addIf(RegExp(r'\b(e-?ac-?3|eac3|ddp|ddp5\.1|ac-?3|aac|flac)\b', caseSensitive: false).hasMatch(raw), 'Audio Pro');
    addIf(RegExp(r'dual[\s-]?audio|multi[\s-]?audio|original\s*\+\s*dub|dual[\s-]?dub', caseSensitive: false).hasMatch(raw), 'Dual Audio');
    addIf(RegExp(r'multi[\s-]?sub(s)?|multi[\s-]?subs|softsub', caseSensitive: false).hasMatch(raw), 'Multi Subs');

    if (lower.contains('web-dl')) out.add('WEB-DL');
    if (lower.contains('webrip')) out.add('WEBRip');
    if (lower.contains('bluray') || lower.contains('bdrip')) out.add('BluRay');

    if (out.length > 7) return out.take(7).toList();
    return out;
  }

  static Color? tryParseHexColor(String raw) {
    var hex = raw.trim().replaceAll('#', '');
    if (hex.isEmpty) return null;
    if (hex.length == 3) {
      hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    return value != null ? Color(value) : null;
  }
}
