import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockListsRepository extends Mock implements ListsRepository {}

class _MockWatchHistoryRepository extends Mock
    implements WatchHistoryRepository {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

/// The empty Watchlist of [offlineListsOverrides].
final offlineWatchlist = UserList(
  id: 'watchlist',
  userId: 'user-a',
  name: 'Watchlist',
  type: ListType.watchlist,
  createdAt: DateTime.utc(2026),
);

/// Signed in, with an empty Watchlist, and every list save failing as if
/// offline (the real repository has already undone its local change then).
List<Override> offlineListsOverrides() {
  final user = User(
    id: 'user-a',
    appMetadata: {},
    userMetadata: {},
    aud: '',
    createdAt: '',
  );
  final auth = _MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(user);
  when(
    () => auth.currentSession,
  ).thenReturn(Session(accessToken: 'token', tokenType: 'bearer', user: user));
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  final client = _MockSupabaseClient();
  when(() => client.auth).thenReturn(auth);

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
      meta: any(named: 'meta'),
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
  final history = _MockWatchHistoryRepository();
  when(() => history.saveMediaItem(any())).thenAnswer((_) async {});

  return [
    authProvider.overrideWith((ref) => AuthService(client)),
    listsRepositoryProvider.overrideWithValue(lists),
    watchHistoryRepositoryProvider.overrideWithValue(history),
  ];
}
