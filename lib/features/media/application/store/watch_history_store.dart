import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

// GLOBAL WATCH HISTORY STORE
// Acts as a centralized, reactive in-memory store for all watch history.
// Listeners (UI) update instantly when the database changes.

final watchHistoryStoreProvider = StreamProvider<Map<String, WatchHistory>>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value({});

  final repository = ref.watch(watchHistoryRepositoryProvider);
  
  return repository.watchAllHistory(userId).map((list) {
    final map = <String, WatchHistory>{};
    
    // Sort by last watched (ascending) so later entries (more recent) overwrite in our loop for the base key
    final sortedList = List<WatchHistory>.from(list);
    sortedList.sort((a, b) => a.lastWatchedAt.compareTo(b.lastWatchedAt));

    for (final item in sortedList) {
      final baseKey = item.tmdbId.toString();
      
      // 1. Store as base entry (Show or Movie) - Latest will win
      map[baseKey] = item;
      
      // 2. Store as specific episodic entry if applicable
      if (item.mediaType == MediaKind.tv && item.season != null && item.episode != null) {
        final epKey = '$baseKey-${item.season}-${item.episode}';
        map[epKey] = item;
      }
    }
    return map;
  });
});
