import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';

// GLOBAL WATCH HISTORY STORE
// Acts as a centralized, reactive in-memory store for all watch history.
// Listeners (UI) update instantly when the database changes.

final watchHistoryStoreProvider = StreamProvider<Map<String, WatchHistory>>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value({});

  final repository = ref.watch(watchHistoryRepositoryProvider);
  
  return repository.watchAllHistory(userId).map((list) {
    // Convert List to Map for O(1) lookup
    // Key: tmdb_id (as String)
    return {
      for (final item in list) 
        item.tmdbId.toString(): item
    };
  });
});
