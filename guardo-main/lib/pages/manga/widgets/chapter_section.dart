import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../logic/manga_detail_controller.dart';

class ChapterSection extends StatelessWidget {
  final MangaDetailController controller;
  final Function(int) onChapterTap;

  const ChapterSection({
    super.key,
    required this.controller,
    required this.onChapterTap,
  });

  Widget _filterIconButton({required IconData icon, required bool active, required VoidCallback onPressed}) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: active ? Colors.white : Colors.white54),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
    );
  }

  Widget _floatingPaginationButton({required IconData icon, VoidCallback? onPressed}) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: onPressed == null ? Colors.white24 : Colors.white, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleChapters = controller.visibleChapters;
    final totalPages = controller.totalPages;
    final processedCount = controller.processedChapters.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CAPÍTULOS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 24)),
                  if (controller.mwDetails != null) Text('$processedCount Total', style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              // Source Selector
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF080808),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Manhwa Web', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.chevronDown, size: 16, color: Colors.white70),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (controller.loadingChapters)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (controller.mwDetails == null || controller.mwDetails!.chapters.isEmpty)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No se encontraron capítulos.', style: TextStyle(color: Colors.white54))))
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF080808),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  // Search Bar & Filters
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF080808),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: TextField(
                              controller: controller.chapterSearchController,
                              keyboardType: TextInputType.number,
                              textAlignVertical: TextAlignVertical.center,
                              style: const TextStyle(fontSize: 13, height: 1.2),
                              decoration: InputDecoration(
                                hintText: 'Buscar...',
                                prefixIcon: const Icon(LucideIcons.search, size: 18, color: Colors.white38),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.only(right: 12),
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _filterIconButton(
                          icon: controller.isAscending ? LucideIcons.arrowUp01 : LucideIcons.arrowDown10, 
                          active: true,
                          onPressed: controller.toggleOrder,
                        ),
                        const SizedBox(width: 4),
                        _filterIconButton(
                          icon: controller.showOnlyUnread ? LucideIcons.eyeOff : LucideIcons.eye, 
                          active: controller.showOnlyUnread,
                          onPressed: controller.toggleUnreadOnly,
                        ),
                        const SizedBox(width: 4),
                        _filterIconButton(
                          icon: LucideIcons.download, 
                          active: false,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  
                  // Chapters List
                  ...List.generate(visibleChapters.length, (index) {
                    final chapter = visibleChapters[index];
                    final num_ = (chapter['number'] as num).floor();
                    final title = chapter['title']?.toString() ?? 'Capítulo $num_';
                    final isLast = index == visibleChapters.length - 1 && (totalPages <= 1 || controller.chapterQuery.isNotEmpty);

                    return Column(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            onTap: () => onChapterTap(num_),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            title: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(LucideIcons.download, size: 18, color: Colors.white24),
                                  onPressed: () {},
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                const Icon(LucideIcons.bookOpen, size: 18, color: Colors.white24),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast)
                          Divider(height: 1, indent: 20, endIndent: 20, color: Colors.white.withValues(alpha: 0.03)),
                      ],
                    );
                  }),

                  // Chapter Size Selector
                  if (controller.chapterQuery.isEmpty && totalPages > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('MOSTRAR:', style: TextStyle(fontSize: 9, color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                          const SizedBox(width: 8),
                          PopupMenuButton<int>(
                            initialValue: controller.chaptersPerPage,
                            onSelected: controller.setChaptersPerPage,
                            offset: const Offset(0, 30),
                            color: const Color(0xFF161616),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(controller.chaptersPerPage.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                                  const SizedBox(width: 4),
                                  const Icon(LucideIcons.chevronDown, size: 14, color: Colors.white38),
                                ],
                              ),
                            ),
                            itemBuilder: (context) => [5, 10, 20, 50].map((size) => PopupMenuItem(
                              value: size,
                              height: 35,
                              child: Text(size.toString(), style: const TextStyle(fontSize: 13, color: Colors.white)),
                            )).toList(),
                          ),
                        ],
                      ),
                    ),

                  // Pagination
                  if (totalPages > 1 && controller.chapterQuery.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _floatingPaginationButton(
                            icon: LucideIcons.chevronsLeft,
                            onPressed: controller.chapterCurrentPage > 0 ? () => controller.setPage(0) : null,
                          ),
                          _floatingPaginationButton(
                            icon: LucideIcons.chevronLeft,
                            onPressed: controller.chapterCurrentPage > 0 ? () => controller.setPage(controller.chapterCurrentPage - 1) : null,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF121212),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${controller.chapterCurrentPage + 1} / $totalPages',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white54),
                            ),
                          ),
                          _floatingPaginationButton(
                            icon: LucideIcons.chevronRight,
                            onPressed: controller.chapterCurrentPage < totalPages - 1 ? () => controller.setPage(controller.chapterCurrentPage + 1) : null,
                          ),
                          _floatingPaginationButton(
                            icon: LucideIcons.chevronsRight,
                            onPressed: controller.chapterCurrentPage < totalPages - 1 ? () => controller.setPage(totalPages - 1) : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
