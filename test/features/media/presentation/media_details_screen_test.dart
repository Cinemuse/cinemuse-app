import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/details_tab_nav.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/app_font.dart';
import '../../../helpers/offline_lists.dart';

class MockUnifiedStreamResolver extends Mock implements UnifiedStreamResolver {}

class MockTmdbService extends Mock implements TmdbService {}

class MockMediaRepository extends Mock implements MediaRepository {}

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

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

  Widget app({required List<Override> overrides}) {
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
      overrides: [
        ...offlineListsOverrides(),
        unifiedStreamResolverProvider.overrideWithValue(resolver),
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
        watchHistoryStoreProvider.overrideWith(
          (ref) => Stream.value({history.titleKey: history}),
        ),
        movieWatchCountProvider.overrideWith((ref, id) => 0),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MediaDetailsScreen(mediaId: '1', mediaType: 'movie'),
      ),
    );
  }

  final loaded = [
    connectivityProvider.overrideWith(
      (ref) => Stream.value(ConnectivityResult.wifi),
    ),
    mediaDetailsProvider.overrideWith(
      (ref, args) async => {'id': 1, 'title': 'Some Movie'},
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

      expect(find.text(l10n.failureNetwork), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
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
            seasonDetailsProvider.overrideWith((ref, args) async {
              loadedSeasons.add(args.seasonNumber);
              return null;
            }),
            connectivityProvider.overrideWith(
              (ref) => Stream.value(ConnectivityResult.wifi),
            ),
            mediaDetailsProvider.overrideWith(
              (ref, args) async => args.type == 'tv'
                  ? {
                      'id': 1,
                      'name': 'Some Show',
                      'number_of_seasons': 2,
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
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
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
        return {'id': 1, 'title': 'Some Movie'};
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
      when(
        () => tmdb.getMediaDetails('1', 'movie'),
      ).thenAnswer((_) async => {'id': 1, 'title': 'Some Movie'});
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
