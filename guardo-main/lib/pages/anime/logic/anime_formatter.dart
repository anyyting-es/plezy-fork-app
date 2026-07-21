class AnimeFormatter {
  static String displayScore(dynamic score) {
    if (score == null) return '0.0';
    final s = (score as num).toDouble();
    if (s > 10) return (s / 10).toStringAsFixed(1);
    return s.toStringAsFixed(1);
  }

  static String displayFormat(dynamic format) {
    final f = (format?.toString() ?? '').trim().toUpperCase();
    switch (f) {
      case 'TV': return 'TV';
      case 'TV_SHORT': return 'TV Corto';
      case 'MOVIE': return 'Película';
      case 'SPECIAL': return 'Especial';
      case 'OVA': return 'OVA';
      case 'ONA': return 'ONA';
      case 'MUSIC': return 'Música';
      case 'MANGA': return 'Manga';
      case 'NOVEL': return 'Novela';
      case 'ONE_SHOT': return 'One Shot';
      default: return f.replaceAll('_', ' ');
    }
  }

  static String formatAnimeStatus(dynamic rawStatus) {
    final status = (rawStatus?.toString() ?? '').trim().toUpperCase();
    switch (status) {
      case 'RELEASING': return 'EN EMISIÓN';
      case 'FINISHED': return 'FINALIZADO';
      case 'NOT_YET_RELEASED': return 'PRÓXIMAMENTE';
      case 'CANCELLED': return 'CANCELADO';
      case 'HIATUS': return 'PAUSADO';
      default: return status.isEmpty ? 'DESCONOCIDO' : status.replaceAll('_', ' ');
    }
  }

  static String formatMetadata(Map<String, dynamic> anime, int airedCount) {
    final format = displayFormat(anime['format']);
    final year = (anime['seasonYear'] as num?)?.toInt() ??
        (anime['startDate']?['year'] as num?)?.toInt();
    
    final totalCount = (anime['episodes'] as num?)?.toInt();
    final episodeText = (totalCount != null && totalCount > airedCount && airedCount > 0)
        ? '$airedCount / $totalCount EP'
        : '$airedCount EP';

    final parts = <String>[format];
    if (year != null) parts.add('$year');
    parts.add(episodeText);

    return parts.join(' • ');
  }

  static String formatMetadataWithStatus(Map<String, dynamic> anime, int episodeCount) {
    final base = formatMetadata(anime, episodeCount);
    final status = formatAnimeStatus(anime['status']);
    if (status == 'DESCONOCIDO') return base;
    return '$base • $status';
  }

  static String formatReleaseDate(int? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.day}/${date.month}/${date.year}';
  }

  static String formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    final parts = <String>[];
    if (hours > 0) parts.add('${hours}h');
    if (remainingMinutes > 0 || hours == 0) parts.add('${remainingMinutes}m');
    return parts.join(' ');
  }
}
