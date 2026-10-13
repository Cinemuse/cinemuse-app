import 'dart:async';

import 'package:cinemuse_app/core/utils/app_logger.dart';
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

  // Refresh the local copy from Supabase in the background. The local copy
  // is shown meanwhile, so a failure (e.g. offline) is only logged (DATA-07).
  unawaited(
    repository.syncWatchHistory(user.id).catchError((Object e, StackTrace st) {
      AppLogger.warn(
        'WatchHistoryStore',
        'Background sync failed',
        error: e,
        stackTrace: st,
      );
    }),
  );

  return repository
      .watchHistory(user.id)
      .map((list) => {for (final item in list) item.titleKey: item});
});
