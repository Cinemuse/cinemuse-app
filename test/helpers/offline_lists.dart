import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_progress_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:flutter_riverpod/misc.dart';

class _MockListsRepository extends Mock implements ListsRepository {}

class _MockMediaRepository extends Mock implements MediaRepository {}

class _MockWatchHistoryRepository extends Mock
    implements WatchHistoryRepository {}

class _MockWatchProgressRepository extends Mock
    implements WatchProgressRepository {}

/// The empty Watchlist of [offlineListsOverrides].
final offlineWatchlist = UserList(
  id: 'watchlist',
  userId: 'user-a',
  name: 'Watchlist',
  type: ListType.watchlist,
  createdAt: DateTime.utc(2026),
);

/// Signed in, with an empty Watchlist and no Dropped titles, and every list
/// and Continue Watching save failing as if offline (the real repositories
/// have already undone their local change then).
List<Override> offlineListsOverrides() {
  final user = User(
    id: 'user-a',
    appMetadata: {},
    userMetadata: {},
    aud: '',
    createdAt: '',
  );

  registerFallbackValue(MediaKind.movie);
  final lists = _MockListsRepository();
  when(() => lists.syncUserLists(any())).thenAnswer((_) async {});
  when(
    () => lists.watchUserLists(any()),
  ).thenAnswer((_) => Stream.value([offlineWatchlist]));
  const offline = NetworkFailure('offline');
  when(
    () => lists.addItemToList(
      listId: any(named: 'listId'),
      tmdbId: any(named: 'tmdbId'),
      mediaType: any(named: 'mediaType'),
    ),
  ).thenThrow(offline);
  when(
    () => lists.removeItemFromList(
      listId: any(named: 'listId'),
      tmdbId: any(named: 'tmdbId'),
      mediaType: any(named: 'mediaType'),
    ),
  ).thenThrow(offline);

  registerFallbackValue(
    MediaItem(tmdbId: 0, mediaType: MediaKind.movie, updatedAt: DateTime(0)),
  );
  final media = _MockMediaRepository();
  when(() => media.getMediaItem(any(), any())).thenAnswer((_) async => null);
  final history = _MockWatchHistoryRepository();
  when(() => history.getDroppedItems(any())).thenAnswer((_) async => []);
  final progress = _MockWatchProgressRepository();
  when(
    () => progress.dropFromContinueWatching(any(), any(), any()),
  ).thenThrow(offline);
  when(
    () => progress.clearProgress(
      userId: any(named: 'userId'),
      tmdbId: any(named: 'tmdbId'),
      mediaType: any(named: 'mediaType'),
    ),
  ).thenThrow(offline);

  return [
    // Signed in; the rest of the app keeps no Supabase client.
    authProvider.overrideWithBuild((ref, notifier) => AsyncData(user)),
    listsRepositoryProvider.overrideWithValue(lists),
    mediaRepositoryProvider.overrideWithValue(media),
    watchHistoryRepositoryProvider.overrideWithValue(history),
    watchProgressRepositoryProvider.overrideWithValue(progress),
  ];
}
