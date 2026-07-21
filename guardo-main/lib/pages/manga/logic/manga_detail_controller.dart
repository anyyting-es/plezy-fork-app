import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/app_models.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';

class MangaDetailController extends ChangeNotifier {
  MangaDetailController({
    required this.mangaId,
    this.resume,
  });

  final int mangaId;
  final ReadEntry? resume;

  // Services
  final _api = ApiService.instance;
  final _storage = StorageService.instance;

  // State
  Map<String, dynamic>? manga;
  ManhwaDetails? mwDetails;
  bool loading = true;
  bool loadingChapters = true;
  bool isFavorite = false;
  ReadEntry? readEntry;

  // Chapter Pagination & Search
  int chapterCurrentPage = 0;
  int chaptersPerPage = 10;
  final TextEditingController chapterSearchController = TextEditingController();
  String chapterQuery = '';
  bool isAscending = false;
  bool showOnlyUnread = false;

  bool _isDisposed = false;

  void init() {
    chapterSearchController.addListener(_onSearchChanged);

    final cached = _api.getCachedMedia(mangaId);
    if (cached != null) {
      manga = cached;
      loading = false;
    } else if (resume != null) {
      manga = {
        'id': mangaId,
        'title': {
          'romaji': resume!.mangaTitleRomaji,
          'english': resume!.mangaTitleEnglish ?? resume!.mangaTitleRomaji,
        },
        'coverImage': {
          'extraLarge': resume!.mangaCover,
          'large': resume!.mangaCover,
        },
        'bannerImage': resume!.mangaBanner,
        'chapters': resume!.totalChapters,
        'status': resume!.mangaStatus,
      };
      loading = false;
      _api.cacheMedia(mangaId, manga!);
    } else {
      loading = true;
    }

    final cachedDetails = _api.getCachedManhwaDetails(mangaId);
    if (cachedDetails != null) {
      mwDetails = cachedDetails;
      loadingChapters = false;
    } else {
      loadingChapters = true;
    }

    load();
  }

  @override
  void dispose() {
    _isDisposed = true;
    chapterSearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    chapterQuery = chapterSearchController.text;
    chapterCurrentPage = 0;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> load() async {
    if (manga == null) {
      loading = true;
    }
    _safeNotify();

    final data = await _api.fetchMediaById(mangaId, isManga: true);
    if (data != null) {
      manga = data;
    }
    isFavorite = await _storage.isFavorite(mangaId);
    readEntry = await _storage.getReadEntry(mangaId);
    
    loading = false;
    _safeNotify();

    await loadManhwaDetails();
  }

  Future<void> loadManhwaDetails() async {
    if (manga == null) return;
    if (mwDetails == null) {
      loadingChapters = true;
      _safeNotify();
    }

    final romaji = (manga!['title']?['romaji'] as String?) ?? '';
    final english = (manga!['title']?['english'] as String?) ?? '';
    final native_ = (manga!['title']?['native'] as String?) ?? '';

    final queries = <String>[english, romaji, native_]
      ..removeWhere((item) => item.trim().isEmpty);

    ManhwaDetails? details;
    for (final query in queries) {
      final results = await _api.manhwaSearch(query);
      if (results.isEmpty) continue;

      final best = results.first;
      details = await _api.manhwaGetDetails(best['id'].toString(), slug: best['slug']);
      if (details != null && details.chapters.isNotEmpty) break;
    }

    mwDetails = details;
    if (details != null) {
      _api.cacheManhwaDetails(mangaId, details);
    }
    loadingChapters = false;
    _safeNotify();
  }

  void setChaptersPerPage(int size) {
    chaptersPerPage = size;
    chapterCurrentPage = 0;
    _safeNotify();
  }

  void setPage(int page) {
    chapterCurrentPage = page;
    _safeNotify();
  }

  void toggleOrder() {
    isAscending = !isAscending;
    _safeNotify();
  }

  void toggleUnreadOnly() {
    showOnlyUnread = !showOnlyUnread;
    _safeNotify();
  }

  Future<void> toggleFavorite() async {
    if (manga == null) return;
    final success = await _storage.toggleFavorite(manga!);
    if (success) {
      isFavorite = !isFavorite;
      _safeNotify();
    }
  }

  // Logic for filtered chapters
  List<dynamic> get processedChapters {
    final allChapters = List.from(mwDetails?.chapters ?? []);
    
    // 1. Filter by Query
    var processed = chapterQuery.isEmpty 
      ? allChapters 
      : allChapters.where((c) => (c['number']?.toString() ?? '').contains(chapterQuery)).toList();
      
    // 2. Filter by Unread
    if (showOnlyUnread && readEntry != null) {
      final read = readEntry!.readChapters;
      processed = processed.where((c) => !read.contains((c['number'] as num).floor())).toList();
    }
    
    // 3. Sort
    if (!isAscending) {
      processed = processed.reversed.toList();
    }
    
    return processed;
  }

  List<dynamic> get visibleChapters {
    final processed = processedChapters;
    final startIndex = chapterCurrentPage * chaptersPerPage;
    final endIndex = (startIndex + chaptersPerPage).clamp(0, processed.length);
    return processed.sublist(startIndex, endIndex);
  }

  int get totalPages {
    final count = processedChapters.length;
    return (count / chaptersPerPage).ceil();
  }

  Future<void> refreshReadEntry() async {
    readEntry = await _storage.getReadEntry(mangaId);
    _safeNotify();
  }
}
