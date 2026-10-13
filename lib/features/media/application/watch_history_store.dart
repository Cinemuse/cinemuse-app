import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';

/// The user's watch history, one row per title, keyed by
/// [WatchHistory.titleKey] (type + id: a movie and a show can share a
/// tmdbId, REV-195). Updates live when the local database changes.
final watchHistoryStoreProvider = StreamProvider<Map<String, WatchHistory>>((
  ref,
) {
  final user = ref.watch(authProvider).asData?.value;
  if (user == null) return Stream.value({});

  final repository = ref.watch(watchHistoryRepositoryProvider);

  // Trigger background sync on initialization to update local Drift from Supabase
  repository.syncWatchHistory(user.id).catchError((_) {});

  return repository
      .watchHistory(user.id)
      .map((list) => {for (final item in list) item.titleKey: item});
});
