import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

class StorageService {
  static const _watchHistoryKey = 'aniting_watch_history';
  static const _favoritesKey = 'aniting_favorites';
  static const _listsKey = 'aniting_lists';
  static const _mangaReadHistoryKey = 'aniting_manga_read_history';
  static const _mangaFavoritesKey = 'aniting_manga_favorites';
  static const _mangaListsKey = 'aniting_manga_lists';
  static const _appSettingsKey = 'aniting_app_settings';
  static const _anilistTokenKey = 'aniting_anilist_token';
  static const _homeCacheKey = 'aniting_home_cache';
  static const _homeCacheTimestampKey = 'aniting_home_cache_ts';
  static const _mangaCacheKey = 'aniting_manga_cache';
  static const _mangaCacheTimestampKey = 'aniting_manga_cache_ts';

  StorageService._();

  static final StorageService instance = StorageService._();

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  List<dynamic> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) return parsed;
    } catch (_) {}
    return const [];
  }

  Future<void> _setList(String key, List<Map<String, dynamic>> value) async {
    final prefs = await _prefs;
    await prefs.setString(key, jsonEncode(value));
  }

  Future<AppSettings> getAppSettings() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_appSettingsKey);
    if (raw == null) {
      final defaults = AppSettings.defaults();
      await prefs.setString(_appSettingsKey, jsonEncode(defaults.toJson()));
      return defaults;
    }
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      final defaults = AppSettings.defaults();
      await prefs.setString(_appSettingsKey, jsonEncode(defaults.toJson()));
      return defaults;
    }
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    final prefs = await _prefs;
    await prefs.setString(_appSettingsKey, jsonEncode(settings.toJson()));
  }

  Future<List<WatchEntry>> getWatchHistory() async {
    final prefs = await _prefs;
    return _decodeList(prefs.getString(_watchHistoryKey))
        .whereType<Map>()
        .map((item) => WatchEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<WatchEntry?> getWatchEntry(int animeId) async {
    final history = await getWatchHistory();
    for (final entry in history) {
      if (entry.animeId == animeId) return entry;
    }
    return null;
  }

  Future<void> updateWatchEntry(WatchEntry entry) async {
    final history = await getWatchHistory();
    final list = history.where((item) => item.animeId != entry.animeId).toList()
      ..add(entry);
    await _setList(_watchHistoryKey, list.map((item) => item.toJson()).toList());
  }

  Future<void> updateEpisodeProgress({
    required int animeId,
    required int episodeNumber,
    required double currentTime,
    required double duration,
    required Map<String, dynamic> anime,
    String? episodeTitle,
    String? sourceEpisodeId,
    bool? hasDub,
    String? audioMode,
    String? episodeStill,
  }) async {
    final progress = duration > 0 ? (currentTime / duration) * 100 : 0.0;
    final existing = await getWatchEntry(animeId);
    final watchedEpisodes = [...(existing?.watchedEpisodes ?? const <int>[])];

    if (progress >= 85 && !watchedEpisodes.contains(episodeNumber)) {
      watchedEpisodes.add(episodeNumber);
      watchedEpisodes.sort();
    }

    await updateWatchEntry(
      WatchEntry(
        animeId: animeId,
        animeTitleRomaji: (anime['title']?['romaji'] as String?) ?? '',
        animeTitleEnglish: anime['title']?['english'] as String?,
        animeCover: (anime['coverImage']?['extraLarge'] as String?) ??
            (anime['coverImage']?['large'] as String?) ??
            '',
        animeBanner: anime['bannerImage'] as String?,
        totalEpisodes: (anime['episodes'] as num?)?.toInt(),
        animeStatus: anime['status'] as String?,
        lastEpisodeNumber: episodeNumber,
        lastEpisodeTitle: episodeTitle,
        currentTime: currentTime,
        duration: duration,
        progress: progress,
        watchedEpisodes: watchedEpisodes,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        sourceEpisodeId: sourceEpisodeId,
        hasDub: hasDub,
        audioMode: audioMode,
        lastEpisodeStill: episodeStill ?? existing?.lastEpisodeStill,
      ),
    );
  }

  Future<List<WatchEntry>> getContinueWatching() async {
    final history = await getWatchHistory();
    history.removeWhere((item) =>
        item.totalEpisodes != null && item.watchedEpisodes.length >= item.totalEpisodes!);
    history.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return history;
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final prefs = await _prefs;
    return _decodeList(prefs.getString(_favoritesKey))
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMangaFavorites() async {
    final prefs = await _prefs;
    return _decodeList(prefs.getString(_mangaFavoritesKey))
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<bool> isFavorite(int animeId) async {
    final favorites = await getFavorites();
    return favorites.any((item) => (item['animeId'] as num?)?.toInt() == animeId);
  }

  Future<bool> toggleFavorite(Map<String, dynamic> anime, {bool manga = false}) async {
    final key = manga ? _mangaFavoritesKey : _favoritesKey;
    final idKey = manga ? 'mangaId' : 'animeId';
    final prefs = await _prefs;
    final favorites = _decodeList(prefs.getString(key))
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final id = (anime['id'] as num?)?.toInt() ?? 0;
    final idx = favorites.indexWhere((item) => (item[idKey] as num?)?.toInt() == id);

    if (idx >= 0) {
      favorites.removeAt(idx);
      await _setList(key, favorites);
      return false;
    }

    favorites.add({
      idKey: id,
      'title': anime['title'] is Map ? anime['title']['romaji'] : anime['title'],
      'titleEnglish': anime['title'] is Map ? anime['title']['english'] : anime['titleEnglish'],
      'cover': (anime['coverImage']?['extraLarge'] as String?) ??
          (anime['coverImage']?['large'] as String?) ??
          anime['cover'] ??
          '',
      'addedAt': DateTime.now().millisecondsSinceEpoch,
      'averageScore': anime['averageScore'],
      'episodes': anime['episodes'],
      'chapters': anime['chapters'],
      'status': anime['status'],
      'format': anime['format'],
    });
    await _setList(key, favorites);
    return true;
  }

  Future<List<ListEntry>> getAnimeLists() async {
    final prefs = await _prefs;
    return _decodeList(prefs.getString(_listsKey))
        .whereType<Map>()
        .map((item) => ListEntry.fromJson(Map<String, dynamic>.from(item), isManga: false))
        .toList();
  }

  Future<void> setAnimeList(Map<String, dynamic> anime, ListType type, {int progress = 0}) async {
    final list = await getAnimeLists();
    final id = (anime['id'] as num?)?.toInt() ?? 0;
    final index = list.indexWhere((item) => item.id == id);
    final now = DateTime.now().millisecondsSinceEpoch;

    final entry = ListEntry(
      id: id,
      title: (anime['title']?['romaji'] as String?) ?? anime['title']?.toString() ?? '',
      titleEnglish: anime['title']?['english'] as String?,
      cover: (anime['coverImage']?['extraLarge'] as String?) ??
          (anime['coverImage']?['large'] as String?) ??
          '',
      list: type,
      progress: progress,
      updatedAt: now,
      addedAt: index >= 0 ? list[index].addedAt : now,
      totalEpisodes: (anime['episodes'] as num?)?.toInt(),
      averageScore: anime['averageScore'] as num?,
      status: anime['status'] as String?,
      format: anime['format'] as String?,
    );

    if (index >= 0) {
      list[index] = entry;
    } else {
      list.add(entry);
    }

    await _setList(_listsKey, list.map((item) => item.toJson(isManga: false)).toList());
  }

  Future<List<ListEntry>> getMangaLists() async {
    final prefs = await _prefs;
    return _decodeList(prefs.getString(_mangaListsKey))
        .whereType<Map>()
        .map((item) => ListEntry.fromJson(Map<String, dynamic>.from(item), isManga: true))
        .toList();
  }

  Future<void> setMangaList(Map<String, dynamic> manga, ListType type, {int progress = 0}) async {
    final list = await getMangaLists();
    final id = (manga['id'] as num?)?.toInt() ?? 0;
    final index = list.indexWhere((item) => item.id == id);
    final now = DateTime.now().millisecondsSinceEpoch;

    final entry = ListEntry(
      id: id,
      title: (manga['title']?['romaji'] as String?) ?? manga['title']?.toString() ?? '',
      titleEnglish: manga['title']?['english'] as String?,
      cover: (manga['coverImage']?['extraLarge'] as String?) ??
          (manga['coverImage']?['large'] as String?) ??
          '',
      list: type,
      progress: progress,
      updatedAt: now,
      addedAt: index >= 0 ? list[index].addedAt : now,
      totalChapters: (manga['chapters'] as num?)?.toInt(),
      averageScore: manga['averageScore'] as num?,
      status: manga['status'] as String?,
      format: manga['format'] as String?,
    );

    if (index >= 0) {
      list[index] = entry;
    } else {
      list.add(entry);
    }

    await _setList(_mangaListsKey, list.map((item) => item.toJson(isManga: true)).toList());
  }

  Future<List<ReadEntry>> getReadHistory() async {
    final prefs = await _prefs;
    return _decodeList(prefs.getString(_mangaReadHistoryKey))
        .whereType<Map>()
        .map((item) => ReadEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ReadEntry?> getReadEntry(int mangaId) async {
    final list = await getReadHistory();
    for (final item in list) {
      if (item.mangaId == mangaId) return item;
    }
    return null;
  }

  Future<void> markChapterRead({
    required int mangaId,
    required int chapterNumber,
    required Map<String, dynamic> manga,
    String? sourceSlug,
  }) async {
    final existing = await getReadEntry(mangaId);
    final readChapters = [...(existing?.readChapters ?? const <int>[])];
    if (!readChapters.contains(chapterNumber)) {
      readChapters.add(chapterNumber);
      readChapters.sort();
    }

    final entry = ReadEntry(
      mangaId: mangaId,
      mangaTitleRomaji: (manga['title']?['romaji'] as String?) ?? '',
      mangaTitleEnglish: manga['title']?['english'] as String?,
      mangaCover: (manga['coverImage']?['extraLarge'] as String?) ??
          (manga['coverImage']?['large'] as String?) ??
          '',
      mangaBanner: manga['bannerImage'] as String?,
      totalChapters: (manga['chapters'] as num?)?.toInt(),
      mangaStatus: manga['status'] as String?,
      lastChapterNumber: chapterNumber.toDouble(),
      readChapters: readChapters,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      sourceSlug: sourceSlug,
    );

    final history = await getReadHistory();
    final list = history.where((item) => item.mangaId != mangaId).toList()..add(entry);
    await _setList(_mangaReadHistoryKey, list.map((item) => item.toJson()).toList());
  }

  Future<List<ReadEntry>> getContinueReading() async {
    final history = await getReadHistory();
    history.removeWhere((item) => item.totalChapters != null && item.readChapters.length >= item.totalChapters!);
    history.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return history;
  }

  Future<String?> getAnilistToken() async {
    final prefs = await _prefs;
    return prefs.getString(_anilistTokenKey);
  }

  Future<void> setAnilistToken(String? token) async {
    final prefs = await _prefs;
    if (token == null) {
      await prefs.remove(_anilistTokenKey);
    } else {
      await prefs.setString(_anilistTokenKey, token);
    }
  }

  Future<String> loadAssetString(String path) async {
    return await rootBundle.loadString(path);
  }

  // ─── HOME CACHE (Anime & Manga) ──────────────────────────────
  
  Future<void> saveHomeCache({
    required List<dynamic> carousel,
    required Map<String, List<dynamic>> sections,
    bool isManga = false,
  }) async {
    final prefs = await _prefs;
    final key = isManga ? _mangaCacheKey : _homeCacheKey;
    final tsKey = isManga ? _mangaCacheTimestampKey : _homeCacheTimestampKey;
    
    final payload = {
      'carousel': carousel,
      'sections': sections,
    };
    await prefs.setString(key, jsonEncode(payload));
    await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<HomeCacheData?> loadHomeCache({bool isManga = false}) async {
    final prefs = await _prefs;
    final key = isManga ? _mangaCacheKey : _homeCacheKey;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      
      final carouselData = (data['carousel'] ?? data['banner']) as List?;
      
      final sectionsRaw = data['sections'] as Map<String, dynamic>? ?? {};
      final sections = sectionsRaw.map((key, value) {
        return MapEntry(key, (value as List).cast<dynamic>());
      });
      return HomeCacheData(
        carousel: carouselData?.cast<dynamic>() ?? [],
        sections: sections,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> isHomeCacheFresh({
    bool isManga = false,
    Duration maxAge = const Duration(hours: 6),
  }) async {
    final prefs = await _prefs;
    final tsKey = isManga ? _mangaCacheTimestampKey : _homeCacheTimestampKey;
    final ts = prefs.getInt(tsKey);
    if (ts == null) return false;
    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    return age < maxAge;
  }

  Future<void> clearHomeCache({bool isManga = false}) async {
    final prefs = await _prefs;
    final key = isManga ? _mangaCacheKey : _homeCacheKey;
    final tsKey = isManga ? _mangaCacheTimestampKey : _homeCacheTimestampKey;
    await prefs.remove(key);
    await prefs.remove(tsKey);
  }

  // Compatibilidad para MangaPage antiguo si aún se usa
  Future<void> saveMangaCache({
    required List<dynamic> banner,
    required Map<String, List<dynamic>> sections,
  }) => saveHomeCache(carousel: banner, sections: sections, isManga: true);

  Future<HomeCacheData?> loadMangaCache() => loadHomeCache(isManga: true);

  Future<bool> isMangaCacheFresh({Duration maxAge = const Duration(hours: 6)}) => 
      isHomeCacheFresh(isManga: true, maxAge: maxAge);
}

class HomeCacheData {
  final List<dynamic> carousel;
  final Map<String, List<dynamic>> sections;

  const HomeCacheData({
    required this.carousel,
    required this.sections,
  });
}
