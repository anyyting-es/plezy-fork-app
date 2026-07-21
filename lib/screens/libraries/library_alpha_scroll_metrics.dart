/// Scroll geometry used by the library alpha jump bar.
///
/// The browse tab can render either a fixed-grid layout or a one-column list.
/// This small value object keeps the shared index/offset math out of the
/// widget state so both modes use the same clamping behaviour.
class LibraryAlphaScrollMetrics {
  final int columnCount;
  final double rowHeight;
  final double itemWidth;
  final double itemHeight;

  const LibraryAlphaScrollMetrics({
    required this.columnCount,
    required this.rowHeight,
    required this.itemWidth,
    required this.itemHeight,
  });

  static const empty = LibraryAlphaScrollMetrics(columnCount: 1, rowHeight: 0, itemWidth: 0, itemHeight: 0);

  bool get isUsable => columnCount > 0 && rowHeight > 0;

  LibraryAlphaScrollMetrics copyWith({int? columnCount, double? rowHeight, double? itemWidth, double? itemHeight}) {
    return LibraryAlphaScrollMetrics(
      columnCount: columnCount ?? this.columnCount,
      rowHeight: rowHeight ?? this.rowHeight,
      itemWidth: itemWidth ?? this.itemWidth,
      itemHeight: itemHeight ?? this.itemHeight,
    );
  }

  int itemIndexFromScrollOffset(double offset, {required double contentStartOffset, required int totalSize}) {
    if (!isUsable) return 0;
    final contentOffset = (offset - contentStartOffset).clamp(0.0, double.infinity);
    final row = (contentOffset / rowHeight).floor();
    final maxIndex = totalSize > 0 ? totalSize - 1 : 0;
    return (row * columnCount).clamp(0, maxIndex);
  }

  double scrollOffsetForItemIndex(int index, {required double contentStartOffset}) {
    if (!isUsable) return contentStartOffset;
    final targetRow = index ~/ columnCount;
    return contentStartOffset + targetRow * rowHeight;
  }

  int visibleItemCount(double viewportHeight) {
    if (!isUsable || !viewportHeight.isFinite) return 0;
    final visibleRows = (viewportHeight / rowHeight).ceil() + 1;
    return visibleRows * columnCount;
  }
}
