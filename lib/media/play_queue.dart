import 'package:freezed_annotation/freezed_annotation.dart';

import 'media_item.dart';

part 'play_queue.freezed.dart';

/// Backend-neutral play queue — a flat ordered list of items with a current
/// cursor. Implementations differ in whether the queue is server-resourced
/// (Plex) or client-only (Jellyfin).
@freezed
sealed class PlayQueue with _$PlayQueue {
  const PlayQueue._();

  /// Plex play queue — coordinated server-side via `/playQueues` so multiple
  /// devices can view/control the same queue.
  const factory PlayQueue.plex({
    /// Plex `playQueueID` — addresses the queue for subsequent fetches.
    required int playQueueId,
    required List<MediaItem> items,
    int? currentIndex,
    @Default(false) bool shuffled,

    /// Plex `playQueueSelectedItemID` of the active item.
    int? selectedItemId,

    /// Plex `playQueueVersion` — server-side optimistic concurrency token.
    int? version,

    /// Plex `playQueueSourceURI` — used for "Up Next" derivation.
    String? sourceUri,
  }) = PlexServerPlayQueue;

  /// Client-only play queue used by Jellyfin and any backend without a
  /// server-side queue concept. Each [LocalPlayQueue] is anchored by a
  /// client-generated UUID so callers can address it like a Plex queue.
  const factory PlayQueue.local({
    /// Client-generated UUID identifying this queue for the session.
    required String id,
    required List<MediaItem> items,

    /// Server kind that owns this queue's items (typically `"jellyfin"`).
    required String backendId,
    int? currentIndex,
    @Default(false) bool shuffled,
  }) = LocalPlayQueue;

  MediaItem? get current => switch (this) {
    PlexServerPlayQueue(:final items, :final currentIndex) || LocalPlayQueue(:final items, :final currentIndex) =>
      currentIndex != null && currentIndex >= 0 && currentIndex < items.length ? items[currentIndex] : null,
  };

  bool get hasNext => switch (this) {
    PlexServerPlayQueue(:final items, :final currentIndex) ||
    LocalPlayQueue(:final items, :final currentIndex) => currentIndex != null && currentIndex + 1 < items.length,
  };

  bool get hasPrevious => switch (this) {
    PlexServerPlayQueue(:final currentIndex) ||
    LocalPlayQueue(:final currentIndex) => currentIndex != null && currentIndex > 0,
  };
}
