import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_logs_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/details_tab_nav.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/app_font.dart';
import '../../../helpers/offline_lists.dart';
import '../../../helpers/override_helpers.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class MockUnifiedStreamResolver extends Mock implements UnifiedStreamResolver {}

class MockTmdbService extends Mock implements TmdbService {}

class MockMediaRepository extends Mock implements MediaRepository {}

class MockWatchHistoryRepository extends Mock
    implements WatchHistoryRepository {}

class MockWatchLogsRepository extends Mock implements WatchLogsRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

/// TMDB's details answer [tmdb] as the app reads it.
MediaItem _details(String type, Map<String, dynamic> tmdb) =>
    MediaItem.fromTmdbDetails(tmdb, MediaItem.fromString(type));

void main() {
  setUpAll(loadAppFont);

  final l10n = AppLocalizationsEn();

  // A movie half watched.
  final history = WatchHistory(
    userId: 'user-a',
    tmdbId: 1,
    mediaType: MediaKind.movie,
    status: WatchStatus.watching,
    progressSeconds: 600,
    totalDuration: 6000,
    lastWatchedAt: DateTime.utc(2026, 10, 1),
  );

  Widget app({required List<Override> overrides, String mediaType = 'movie'}) {
    final resolver = MockUnifiedStreamResolver();
    when(
      () => resolver.hasCachedStream(
        any(),
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenReturn(false);
    return ProviderScope(
      retry: noProviderRetry,
      overrides: withOwnOverrides([
        ...offlineListsOverrides(),
        unifiedStreamResolverProvider.overrideWithValue(resolver),
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
        watchHistoryStoreProvider.overrideWith(
          (ref) => Stream.value({history.titleKey: history}),
        ),
        movieWatchCountProvider.overrideWith((ref, id) => 0),
      ], overrides),
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaDetailsScreen(mediaId: '1', mediaType: mediaType),
      ),
    );
  }

  final loaded = [
    connectivityProvider.overrideWith(
      (ref) => Stream.value(ConnectivityResult.wifi),
    ),
    mediaDetailsProvider.overrideWith(
      (ref, args) async =>
          _details(args.type, {'id': 1, 'title': 'Some Movie'}),
    ),
  ];

  // REV-205: Drop and Clear progress from the Play menu showed "Exception".
  for (final action in [l10n.menuStopWatching, l10n.menuClearProgress]) {
    testWidgets('offline, Play menu → "$action": a red translated message', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(overrides: loaded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      // The menu takes taps only once it is fully open.
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      if (action == l10n.menuClearProgress) {
        // Sent only once its Undo message closes.
        expect(
          find.textContaining(l10n.progressCleared('Some Movie')),
          findsOneWidget,
        );
        await tester.pump(AppSnackBar.undoDuration);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.text(l10n.failureNetwork), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });
  }

  // REV-299, REV-305: the Track menu saved without awaiting, so offline the
  // change was undone with no message.
  // A movie watched twice offers every action; the show is up to date.
  final showOverrides = [
    mediaDetailsProvider.overrideWith(
      (ref, args) async =>
          _details(args.type, {'id': 1, 'name': 'Some Show', 'seasons': []}),
    ),
    seriesWatchStatusProvider.overrideWith(
      (ref, args) =>
          (isFullyWatched: true, isPartiallyWatched: false, minWatchCount: 1),
    ),
    watchedEpisodesMapProvider.overrideWith((ref, id) => const {}),
    episodeProgressMapProvider.overrideWith(
      (ref, id) => Stream.value(const {}),
    ),
    seasonEpisodesProvider.overrideWith((ref, args) async => null),
  ];
  for (final (type, button, action, isUndoOff) in [
    ('movie', l10n.detailsWatchedCount(2), l10n.detailsMarkRewatch, false),
    ('movie', l10n.detailsWatchedCount(2), l10n.detailsRemoveOneWatch, false),
    ('movie', l10n.detailsWatchedCount(2), l10n.detailsRemoveOneWatch, true),
    ('movie', l10n.detailsWatchedCount(2), l10n.detailsRemoveAll, false),
    ('tv', l10n.detailsUpToDate, l10n.detailsRemoveAll, false),
  ]) {
    testWidgets('offline $type, Track menu → "$action"'
        '${isUndoOff ? ' with Undo off' : ''}: a red message', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (isUndoOff) {
        AppSnackBar.undoDuration = Duration.zero;
        addTearDown(
          () => AppSnackBar.undoDuration = AppSnackBar.defaultUndoDuration,
        );
      }
      final auth = MockGoTrueClient();
      when(() => auth.currentUser).thenReturn(
        User(
          id: 'user-a',
          appMetadata: {},
          userMetadata: {},
          aud: '',
          createdAt: '',
        ),
      );
      final client = MockSupabaseClient();
      when(() => client.auth).thenReturn(auth);
      const offline = NetworkFailure('offline');
      final history = MockWatchHistoryRepository();
      when(() => history.getDroppedItems(any())).thenAnswer((_) async => []);
      final repository = MockWatchLogsRepository();
      when(
        () => repository.watchTitleLogs(any(), any(), any()),
      ).thenAnswer((_) => Stream.value([]));
      when(
        () => repository.logMovieWatch(
          userId: any(named: 'userId'),
          tmdbId: any(named: 'tmdbId'),
          loggedAt: any(named: 'loggedAt'),
          isNow: any(named: 'isNow'),
        ),
      ).thenThrow(offline);
      when(
        () => repository.deleteLatestMovieLog(
          userId: any(named: 'userId'),
          tmdbId: any(named: 'tmdbId'),
        ),
      ).thenThrow(offline);
      when(
        () => repository.deleteAllMovieLogs(
          userId: any(named: 'userId'),
          tmdbId: any(named: 'tmdbId'),
        ),
      ).thenThrow(offline);
      when(
        () => repository.deleteAllSeriesLogs(
          userId: any(named: 'userId'),
          tmdbId: any(named: 'tmdbId'),
        ),
      ).thenThrow(offline);
      await tester.pumpWidget(
        app(
          mediaType: type,
          overrides: [
            ...loaded,
            if (type == 'tv') ...showOverrides,
            supabaseClientProvider.overrideWithValue(client),
            watchHistoryRepositoryProvider.overrideWithValue(history),
            watchLogsRepositoryProvider.overrideWithValue(repository),
            movieWatchCountProvider.overrideWith((ref, id) => 2),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      if (action != l10n.detailsMarkRewatch && !isUndoOff) {
        // A removal is sent only once its Undo message closes.
        expect(
          find.textContaining(
            action == l10n.detailsRemoveOneWatch
                ? l10n.oneWatchRemoved('')
                : l10n.watchHistoryRemoved(''),
          ),
          findsOneWidget,
        );
        await tester.pump(AppSnackBar.undoDuration);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.text(l10n.failureNetwork), findsOneWidget);
    });
  }

  // REV-20: below 600 px the page and its hero buttons use the phone layout.
  // REV-301: from 600 to ~650 px the wide hero buttons overflowed.
  for (final (width, isPhone) in const [(599.0, true), (600.0, false)]) {
    testWidgets('${width}px wide: ${isPhone ? 'phone' : 'wide'} layout', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(overrides: loaded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Phone: the sections are tabs.
      expect(
        find.byType(DetailsTabNav),
        isPhone ? findsOneWidget : findsNothing,
      );
      // Phone: the bookmark sits under the Play button; wide: beside it
      // (Track may wrap to a second line).
      final playMenu = tester.getCenter(find.byIcon(Icons.keyboard_arrow_down));
      final bookmark = tester.getCenter(
        find.byTooltip(l10n.menuAddToWatchlist),
      );
      if (isPhone) {
        expect(bookmark.dy, greaterThan(playMenu.dy + 20));
      } else {
        expect(bookmark.dy, moreOrLessEquals(playMenu.dy, epsilon: 4));
        expect(bookmark.dx, greaterThan(playMenu.dx));
      }
    });
  }

  // On the TV the synopsis was never fully on screen: the focus went from
  // the hero buttons straight to the cast row, each showing only part of it.
  testWidgets('the remote stops on the synopsis and shows all of it', (
    tester,
  ) async {
    // A TV at its starting screen size (2/3 of 960 × 540).
    tester.view.physicalSize = const Size(1440, 810);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final overview = 'A long synopsis that runs over many lines. ' * 30;
    await tester.pumpWidget(
      app(
        overrides: [
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityResult.wifi),
          ),
          mediaDetailsProvider.overrideWith(
            (ref, args) async => _details(args.type, {
              'id': 1,
              'title': 'Some Movie',
              'overview': overview,
              'credits': {
                'cast': [
                  {'id': 10, 'name': 'Actor One', 'character': 'Hero'},
                  {'id': 11, 'name': 'Actor Two', 'character': 'Villain'},
                ],
              },
            }),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    bool hasFocus(Finder item) {
      final target = tester.element(
        find.ancestor(of: item, matching: find.byType(DpadFocusable)).first,
      );
      var isInside = false;
      FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
        isInside = e == target;
        return !isInside;
      });
      return isInside;
    }

    Rect synopsis() => tester.getRect(
      find.ancestor(of: find.text(overview), matching: find.byType(BentoBox)),
    );

    // Play has the focus; the synopsis runs off the bottom of the screen.
    expect(synopsis().bottom, greaterThan(810));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(hasFocus(find.text(overview)), isTrue);
    expect(synopsis().top, greaterThanOrEqualTo(0));
    expect(synopsis().bottom, lessThanOrEqualTo(810));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(hasFocus(find.text('Actor One')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(hasFocus(find.text(overview)), isTrue);
  });

  // REV-195: a movie and a show can share a TMDB id; each page uses its own
  // history row. The other title's newer row is finished, so mixing them up
  // would show "Play".
  group('a movie and a show share id 1 (REV-195)', () {
    WatchHistory row(
      MediaKind type, {
      required WatchStatus status,
      required int day,
      int progress = 600,
    }) => WatchHistory(
      userId: 'user-a',
      tmdbId: 1,
      mediaType: type,
      status: status,
      season: type == MediaKind.tv ? 2 : null,
      episode: type == MediaKind.tv ? 4 : null,
      progressSeconds: progress,
      totalDuration: 6000,
      lastWatchedAt: DateTime.utc(2026, 10, day),
    );

    // The seasons the episode list asked TMDB for.
    late List<int> loadedSeasons;

    Future<void> pumpPage(
      WidgetTester tester, {
      required String type,
      required List<WatchHistory> rows,
      Locale? locale,
    }) async {
      loadedSeasons = [];
      // Tall, so the episode list is built too.
      tester.view.physicalSize = const Size(1280, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final resolver = MockUnifiedStreamResolver();
      when(
        () => resolver.hasCachedStream(
          any(),
          any(),
          season: any(named: 'season'),
          episode: any(named: 'episode'),
        ),
      ).thenReturn(false);
      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            ...offlineListsOverrides(),
            unifiedStreamResolverProvider.overrideWithValue(resolver),
            settingsProvider.overrideWith(FakeSettingsNotifier.new),
            watchHistoryStoreProvider.overrideWith(
              (ref) => Stream.value({for (final r in rows) r.titleKey: r}),
            ),
            movieWatchCountProvider.overrideWith((ref, id) => 0),
            watchedEpisodesMapProvider.overrideWith((ref, id) => const {}),
            episodeProgressMapProvider.overrideWith(
              (ref, id) => Stream.value(const {}),
            ),
            seasonEpisodesProvider.overrideWith((ref, args) async {
              loadedSeasons.add(args.seasonNumber);
              return null;
            }),
            connectivityProvider.overrideWith(
              (ref) => Stream.value(ConnectivityResult.wifi),
            ),
            mediaDetailsProvider.overrideWith(
              (ref, args) async => _details(
                args.type,
                args.type == 'tv'
                    ? {
                        'id': 1,
                        'name': 'Some Show',
                        'number_of_seasons': 2,
                        'status': 'Ended',
                        // Typed like decoded JSON.
                        'seasons': <dynamic>[
                          <String, dynamic>{
                            'season_number': 1,
                            'episode_count': 5,
                          },
                          <String, dynamic>{
                            'season_number': 2,
                            'episode_count': 5,
                          },
                        ],
                      }
                    : {'id': 1, 'title': 'Some Movie'},
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaDetailsScreen(mediaId: '1', mediaType: type),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('the movie page resumes the movie', (tester) async {
      await pumpPage(
        tester,
        type: 'movie',
        rows: [
          row(MediaKind.movie, status: WatchStatus.watching, day: 1),
          row(MediaKind.tv, status: WatchStatus.completed, day: 2),
        ],
      );

      expect(find.text(l10n.detailsResume), findsOneWidget);
      expect(find.text(l10n.detailsPlayNow), findsNothing);
    });

    // REV-290: the label once read "Play S4 E2" for season 2, episode 4.
    for (final (progress, label) in const [
      (600, 'Resume S2 E4'),
      (0, 'Play S2 E4'),
    ]) {
      testWidgets('the show page opens on its season and shows "$label"', (
        tester,
      ) async {
        await pumpPage(
          tester,
          type: 'tv',
          rows: [
            row(
              MediaKind.tv,
              status: WatchStatus.watching,
              day: 1,
              progress: progress,
            ),
            row(MediaKind.movie, status: WatchStatus.completed, day: 2),
          ],
        );

        expect(find.text(label), findsOneWidget);
        expect(loadedSeasons.last, 2);
      });
    }

    // TMDB sends the status in English whatever the language.
    testWidgets('an ended show says "Conclusa" in Italian', (tester) async {
      await pumpPage(tester, type: 'tv', rows: [], locale: const Locale('it'));

      expect(find.text('Conclusa'), findsOneWidget);
      expect(find.text('Ended'), findsNothing);
    });
  });

  // REV-206: a failed load showed an endless spinner or "not found".
  group('the page fails to load', () {
    late MockTmdbService tmdb;
    late bool isOnline;

    // The real details provider, with TMDB and the connection faked.
    List<Override> loading() {
      final cache = MockMediaRepository();
      registerFallbackValue(
        MediaItem(
          tmdbId: 0,
          mediaType: MediaKind.movie,
          updatedAt: DateTime(0),
        ),
      );
      when(() => cache.saveMediaItem(any())).thenAnswer((_) async {});
      return [
        tmdbServiceProvider.overrideWithValue(tmdb),
        mediaRepositoryProvider.overrideWithValue(cache),
        connectivityProvider.overrideWith(
          (ref) => Stream.value(
            isOnline ? ConnectivityResult.wifi : ConnectivityResult.none,
          ),
        ),
      ];
    }

    setUp(() {
      tmdb = MockTmdbService();
      isOnline = true;
    });

    // The connection, then the details, each arrive a frame later.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('online: "Error", a translated message, Retry reloads', (
      tester,
    ) async {
      var isTmdbDown = true;
      when(() => tmdb.getMediaDetails('1', 'movie')).thenAnswer((_) async {
        if (isTmdbDown) throw const ServerFailure('TMDB is down');
        return _details('movie', {'id': 1, 'title': 'Some Movie'});
      });
      await tester.pumpWidget(app(overrides: loading()));
      await settle(tester);

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text(l10n.commonError), findsOneWidget);
      expect(find.text(l10n.failureUnknown), findsOneWidget);

      isTmdbDown = false;
      await tester.tap(find.text(l10n.commonRetry));
      await settle(tester);
      expect(find.text('Some Movie'), findsWidgets);
    });

    testWidgets('offline: "Connection Required"; back online, Retry loads', (
      tester,
    ) async {
      when(() => tmdb.getMediaDetails('1', 'movie')).thenAnswer(
        (_) async => _details('movie', {'id': 1, 'title': 'Some Movie'}),
      );
      isOnline = false;
      await tester.pumpWidget(app(overrides: loading()));
      await settle(tester);

      expect(find.text(l10n.offlineScreenTitle), findsOneWidget);

      isOnline = true;
      await tester.tap(find.text(l10n.commonRetry));
      await settle(tester);
      expect(find.text(l10n.offlineScreenTitle), findsNothing);
      expect(find.text('Some Movie'), findsWidgets);
    });
  });
}
