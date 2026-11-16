import 'dart:async';

import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/continue_watching_row.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/watch_progress_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_logs_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/backdrop_card.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class MockWatchProgressRepository extends Mock
    implements WatchProgressRepository {}

class MockWatchLogsRepository extends Mock implements WatchLogsRepository {}

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
  late MockWatchProgressRepository repo;
  late MockWatchLogsRepository logs;

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

  SupabaseClient signedIn() {
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
    return client;
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
      retry: noProviderRetry,
      overrides: [
        supabaseClientProvider.overrideWithValue(signedIn()),
        watchProgressRepositoryProvider.overrideWithValue(repo),
        watchLogsRepositoryProvider.overrideWithValue(logs),
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
    repo = MockWatchProgressRepository();
    logs = MockWatchLogsRepository();
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

  // Opens the movie card's menu and picks [action].
  Future<void> pickFromMenu(WidgetTester tester, String action) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump();

    await tester.longPress(find.byType(BackdropCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pump();
  }

  testWidgets('offline "Stop Watching": error message, the card comes back', (
    tester,
  ) async {
    await pickFromMenu(tester, l10n.menuStopWatching);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text(l10n.failureNetwork), findsOneWidget);
    expect(find.byType(BackdropCard), findsOneWidget);
  });

  group('"Clear Progress"', () {
    Future<void> clearCalled() => repo.clearProgress(
      userId: any(named: 'userId'),
      tmdbId: any(named: 'tmdbId'),
      mediaType: any(named: 'mediaType'),
    );

    testWidgets('the movie leaves at once with an Undo message; Undo brings '
        'it back and sends nothing', (tester) async {
      await pickFromMenu(tester, l10n.menuClearProgress);

      expect(find.byType(BackdropCard), findsNothing);
      expect(
        find.textContaining(l10n.progressCleared('Some Movie')),
        findsOneWidget,
      );

      // Once the card menu has closed.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(l10n.commonUndo));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropCard), findsOneWidget);
      verifyNever(clearCalled);
    });

    testWidgets('offline, once the message closes: error message, the card '
        'comes back', (tester) async {
      await pickFromMenu(tester, l10n.menuClearProgress);
      verifyNever(clearCalled);

      await tester.pump(AppSnackBar.undoDuration);
      await tester.pumpAndSettle();

      verify(clearCalled).called(1);
      expect(find.text(l10n.failureNetwork), findsOneWidget);
      expect(find.byType(BackdropCard), findsOneWidget);
    });
  });

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

  // Continue Watching with the real rewatch check.
  Future<void> pumpRow(
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
        retry: noProviderRetry,
        overrides: [
          supabaseClientProvider.overrideWithValue(signedIn()),
          watchProgressRepositoryProvider.overrideWithValue(repo),
          watchLogsRepositoryProvider.overrideWithValue(logs),
          listsRepositoryProvider.overrideWithValue(lists),
          watchHistoryStoreProvider.overrideWith((ref) => store),
          movieWatchCountProvider.overrideWith((ref, id) => 0),
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
  }

  // Continue Watching with one show, then the card menu open.
  Future<void> pumpShowCard(
    WidgetTester tester,
    Stream<Map<String, WatchHistory>> store,
  ) async {
    await pumpRow(tester, store);
    await tester.longPress(find.byType(BackdropCard));
    await tester.pumpAndSettle();
  }

  testWidgets('a show with a later episode logged is a rewatch: the card '
      'menu offers "Cancel rewatch" (REV-191)', (tester) async {
    when(
      () => logs.getHighestLoggedEpisode('user-a', 2),
    ).thenAnswer((_) async => (season: 1, episode: 5));
    final show = showAt();
    await pumpShowCard(tester, Stream.value({show.titleKey: show}));

    expect(find.text(l10n.menuCancelRewatch), findsOneWidget);
    expect(find.text(l10n.menuStopWatching), findsNothing);
  });

  testWidgets('"Cancel rewatch": an Undo message at once; Undo sends '
      'nothing', (tester) async {
    when(
      () => logs.getHighestLoggedEpisode('user-a', 2),
    ).thenAnswer((_) async => (season: 1, episode: 5));
    when(
      () => repo.rewatchEnd('user-a', 2),
    ).thenAnswer((_) async => (season: 1, episode: 6, finished: false));
    final show = showAt();
    await pumpShowCard(tester, Stream.value({show.titleKey: show}));
    await tester.tap(find.text(l10n.menuCancelRewatch));
    await tester.pump();

    expect(
      find.textContaining(l10n.rewatchCancelled('Some Show')),
      findsOneWidget,
    );

    // Once the card menu has closed.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();

    expect(find.byType(BackdropCard), findsOneWidget);
    verifyNever(
      () => repo.cancelRewatch(any(), any(), any(), end: any(named: 'end')),
    );
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
        () => logs.getHighestLoggedEpisode('user-a', 2),
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
      () => logs.getHighestLoggedEpisode('user-a', 2),
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
    verify(() => logs.getHighestLoggedEpisode('user-a', 2)).called(1);
  });

  testWidgets('a movie and a show with the same id: both cards (REV-195)', (
    tester,
  ) async {
    when(
      () => logs.getHighestLoggedEpisode('user-a', 1399),
    ).thenAnswer((_) async => null);
    WatchHistory row(MediaKind type, String title, int day) => WatchHistory(
      userId: 'user-a',
      tmdbId: 1399,
      mediaType: type,
      season: type == MediaKind.tv ? 1 : null,
      episode: type == MediaKind.tv ? 1 : null,
      status: WatchStatus.watching,
      progressSeconds: 600,
      totalDuration: 6000,
      lastWatchedAt: DateTime.utc(2026, 10, day),
      media: MediaItem(
        tmdbId: 1399,
        mediaType: type,
        titleEn: title,
        titleIt: title,
        updatedAt: DateTime.utc(2026),
      ),
    );
    final movie = row(MediaKind.movie, 'Some Movie', 1);
    final show = row(MediaKind.tv, 'Some Show', 2);
    await pumpRow(
      tester,
      Stream.value({movie.titleKey: movie, show.titleKey: show}),
    );

    expect(find.byType(BackdropCard), findsNWidgets(2));
    expect(find.text('Some Movie'), findsWidgets);
    expect(find.text('Some Show'), findsWidgets);
  });
}
