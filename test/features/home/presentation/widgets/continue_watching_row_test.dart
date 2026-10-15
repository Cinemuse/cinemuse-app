import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/continue_watching_row.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/backdrop_card.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockWatchHistoryRepository extends Mock
    implements WatchHistoryRepository {}

class MockListsRepository extends Mock implements ListsRepository {}

class MockUnifiedStreamResolver extends Mock implements UnifiedStreamResolver {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

const _offline = NetworkFailure('offline');

// REV-73, REV-184: a Continue Watching action that fails offline used to only
// log; the card must come back with a translated error message.
void main() {
  final l10n = AppLocalizationsEn();
  late MockWatchHistoryRepository repo;

  final movie = WatchHistory(
    userId: 'user-a',
    tmdbId: 1,
    mediaType: MediaKind.movie,
    status: WatchStatus.watching,
    progressSeconds: 600,
    totalDuration: 6000,
    lastWatchedAt: DateTime.utc(2026, 10, 1),
    media: MediaItem(
      tmdbId: 1,
      mediaType: MediaKind.movie,
      titleEn: 'Some Movie',
      titleIt: 'Some Movie',
      updatedAt: DateTime.utc(2026),
    ),
  );

  AuthService signedIn() {
    final auth = MockGoTrueClient();
    when(() => auth.currentSession).thenReturn(
      Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: User(
          id: 'user-a',
          appMetadata: {},
          userMetadata: {},
          aud: '',
          createdAt: '',
        ),
      ),
    );
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    final client = MockSupabaseClient();
    when(() => client.auth).thenReturn(auth);
    return AuthService(client);
  }

  Widget app() {
    final resolver = MockUnifiedStreamResolver();
    when(
      () => resolver.hasCachedStream(
        any(),
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenReturn(false);
    final lists = MockListsRepository();
    when(() => lists.syncUserLists(any())).thenAnswer((_) async {});
    when(() => lists.watchUserLists(any())).thenAnswer((_) => Stream.value([]));
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => signedIn()),
        watchHistoryRepositoryProvider.overrideWithValue(repo),
        listsRepositoryProvider.overrideWithValue(lists),
        watchHistoryStoreProvider.overrideWith(
          (ref) => Stream.value({movie.titleKey: movie}),
        ),
        isRewatchingProvider.overrideWith((ref, title) async => false),
        unifiedStreamResolverProvider.overrideWithValue(resolver),
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: ContinueWatchingRow()),
        ),
      ),
    );
  }

  setUp(() {
    repo = MockWatchHistoryRepository();
    when(
      () => repo.dropFromContinueWatching(any(), any(), any()),
    ).thenThrow(_offline);
    when(
      () => repo.clearProgress(
        userId: any(named: 'userId'),
        tmdbId: any(named: 'tmdbId'),
        mediaType: any(named: 'mediaType'),
      ),
    ).thenThrow(_offline);
  });

  for (final action in [l10n.menuStopWatching, l10n.menuClearProgress]) {
    testWidgets('offline "$action": error message, the card comes back', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.pump();

      await tester.longPress(find.byType(BackdropCard));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(l10n.failureNetwork), findsOneWidget);
      expect(find.byType(BackdropCard), findsOneWidget);
    });
  }

  // A show in Continue Watching at S1 E3, after [progressSeconds].
  WatchHistory showAt({int progressSeconds = 600}) => WatchHistory(
    userId: 'user-a',
    tmdbId: 2,
    mediaType: MediaKind.tv,
    season: 1,
    episode: 3,
    status: WatchStatus.watching,
    progressSeconds: progressSeconds,
    totalDuration: 2400,
    lastWatchedAt: DateTime.utc(2026, 10, 1),
    media: MediaItem(
      tmdbId: 2,
      mediaType: MediaKind.tv,
      titleEn: 'Some Show',
      titleIt: 'Some Show',
      updatedAt: DateTime.utc(2026),
    ),
  );

  // Continue Watching with the real rewatch check, then the card menu open.
  Future<void> pumpShowCard(
    WidgetTester tester,
    Stream<Map<String, WatchHistory>> store,
  ) async {
    final resolver = MockUnifiedStreamResolver();
    when(
      () => resolver.hasCachedStream(
        any(),
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenReturn(false);
    final lists = MockListsRepository();
    when(() => lists.syncUserLists(any())).thenAnswer((_) async {});
    when(() => lists.watchUserLists(any())).thenAnswer((_) => Stream.value([]));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => signedIn()),
          watchHistoryRepositoryProvider.overrideWithValue(repo),
          listsRepositoryProvider.overrideWithValue(lists),
          watchHistoryStoreProvider.overrideWith((ref) => store),
          unifiedStreamResolverProvider.overrideWithValue(resolver),
          settingsProvider.overrideWith(FakeSettingsNotifier.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: ContinueWatchingRow()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.longPress(find.byType(BackdropCard));
    await tester.pumpAndSettle();
  }

  testWidgets('a show with a later episode logged is a rewatch: the card '
      'menu offers "Cancel rewatch" (REV-191)', (tester) async {
    when(
      () => repo.getHighestLoggedEpisode('user-a', 2),
    ).thenAnswer((_) async => (season: 1, episode: 5));
    final show = showAt();
    await pumpShowCard(tester, Stream.value({show.titleKey: show}));

    expect(find.text(l10n.menuCancelRewatch), findsOneWidget);
    expect(find.text(l10n.menuStopWatching), findsNothing);
  });

  // The card is at S1 E3; the highest episode the user has logged:
  for (final (logged, isRewatch) in [
    ((season: 1, episode: 5), true),
    ((season: 2, episode: 1), true),
    ((season: 1, episode: 3), false),
    ((season: 1, episode: 2), false),
    (null, false),
  ]) {
    testWidgets('logged up to $logged: rewatch $isRewatch (REV-194)', (
      tester,
    ) async {
      when(
        () => repo.getHighestLoggedEpisode('user-a', 2),
      ).thenAnswer((_) async => logged);
      final show = showAt();
      await pumpShowCard(tester, Stream.value({show.titleKey: show}));

      expect(
        find.text(l10n.menuCancelRewatch),
        isRewatch ? findsOneWidget : findsNothing,
      );
      expect(
        find.text(l10n.menuStopWatching),
        isRewatch ? findsNothing : findsOneWidget,
      );
    });
  }

  testWidgets('playing on saves the progress: still a rewatch, asked once '
      '(REV-194)', (tester) async {
    when(
      () => repo.getHighestLoggedEpisode('user-a', 2),
    ).thenAnswer((_) async => (season: 1, episode: 5));
    final store = StreamController<Map<String, WatchHistory>>();
    addTearDown(store.close);
    final show = showAt();
    store.add({show.titleKey: show});
    await pumpShowCard(tester, store.stream);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    // The player saves the new spot: a new history entry, same episode.
    final later = showAt(progressSeconds: 900);
    store.add({later.titleKey: later});
    await tester.pump();
    await tester.pump();
    await tester.longPress(find.byType(BackdropCard));
    await tester.pumpAndSettle();

    expect(find.text(l10n.menuCancelRewatch), findsOneWidget);
    verify(() => repo.getHighestLoggedEpisode('user-a', 2)).called(1);
  });
}
