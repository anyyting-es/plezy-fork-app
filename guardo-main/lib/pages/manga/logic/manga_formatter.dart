class MangaFormatter {
  static String displayStatus(dynamic status) {
    final s = status?.toString().toUpperCase() ?? '';
    switch (s) {
      case 'RELEASING': return 'PUBLICÁNDOSE';
      case 'FINISHED': return 'FINALIZADO';
      case 'NOT_YET_RELEASED': return 'PRÓXIMAMENTE';
      case 'CANCELLED': return 'CANCELADO';
      case 'HIATUS': return 'EN PAUSA';
      default: return 'DESCONOCIDO';
    }
  }

  static String displayFormat(dynamic format) {
    final f = format?.toString().toUpperCase() ?? '';
    switch (f) {
      case 'MANGA': return 'MANGA';
      case 'NOVEL': return 'NOVELA';
      case 'ONE_SHOT': return 'ONE SHOT';
      default: return f.replaceAll('_', ' ');
    }
  }

  static String displayScore(dynamic score) {
    if (score == null) return '0.0';
    final s = (score as num).toDouble();
    if (s > 10) return (s / 10).toStringAsFixed(1);
    return s.toStringAsFixed(1);
  }

  static String relationTypeLabel(dynamic raw) {
    final value = (raw?.toString() ?? '').trim().toUpperCase();
    if (value.isEmpty) return 'RELACIÓN';
    return value.replaceAll('_', ' ');
  }
}
