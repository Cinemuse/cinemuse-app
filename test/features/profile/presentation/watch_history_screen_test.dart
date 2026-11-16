import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/application/user_data_sync_service.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_filter.dart';
import 'package:cinemuse_app/features/profile/presentation/watch_history_screen.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app_font.dart';
import '../../../helpers/cursor_helpers.dart';
import '../../../helpers/focus_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

/// A sync that fails as if offline.
class OfflineSyncService extends UserDataSyncService {
  OfflineSyncService(super.ref);

  @override
  Future<void> syncNow() async => throw const NetworkFailure('offline');
}

// REV-108: pull to refresh called the repository with no try/catch: offline,
// nothing told the user it failed.
void main() {
  final l10n = AppLocalizationsEn();

  final watched = WatchHistory(
    userId: 'user-a',
    tmdbId: 1,
    mediaType: MediaKind.movie,
    status: WatchStatus.completed,
    lastWatchedAt: DateTime.utc(2026, 10, 1),
    media: MediaItem(
      tmdbId: 1,
      mediaType: MediaKind.movie,
      titleEn: 'Some Movie',
      titleIt: 'Some Movie',
      updatedAt: DateTime.utc(2026),
    ),
  );

  final now = DateTime.now();
  WatchHistory episode(int number) => WatchHistory(
    userId: 'user-a',
    tmdbId: 2,
    mediaType: MediaKind.tv,
    status: WatchStatus.completed,
    lastWatchedAt: now.subtract(Duration(minutes: number)),
    season: 1,
    episode: number,
    media: MediaItem(
      tmdbId: 2,
      mediaType: MediaKind.tv,
      titleEn: 'Some Show',
      updatedAt: DateTime.utc(2026),
    ),
  );

  Widget app({
    List<WatchHistory>? logs,
    Future<Map<String, OwnReview>> Function()? reviews,
    Locale? locale,
  }) => ProviderScope(
    retry: noProviderRetry,
    overrides: [
      allOwnReviewsProvider.overrideWith(
        (ref) => reviews == null ? Future.value(const {}) : reviews(),
      ),
      userDataSyncServiceProvider.overrideWith(OfflineSyncService.new),
      watchLogsProvider.overrideWith((ref) async => logs ?? [watched]),
      watchHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
      settingsProvider.overrideWith(FakeSettingsNotifier.new),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const WatchHistoryScreen(),
    ),
  );

  testWidgets('pull to refresh offline: "no connection", the list stays', (
    tester,
  ) async {
    // A desktop window: the wide test font overflows the filter pills at 800.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Some Movie'), findsWidgets);

    await tester.fling(
      find.text('Some Movie').first,
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(l10n.failureNetwork), findsOneWidget);
    expect(find.text('Some Movie'), findsWidgets);
  });

  // REV-246: the phone's filters and order button showed the arrow cursor.
  testWidgets('phone: the filters and order button shows the hand', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(590, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await expectHandOver(tester, find.text(l10n.watchHistoryFiltersTitle));
  });

  // REV-302: the wide window's sort drop-down showed the arrow cursor.
  testWidgets('wide: the sort drop-down and its options show the hand', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final sort = find.byType(DropdownButton<HistorySortOption>);
    await expectHandOver(tester, sort);
    await tester.tap(sort);
    await tester.pumpAndSettle();
    await expectHandOver(tester, find.text(l10n.searchHighestRated).last);
  });

  void wideWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets("timeline: a header per day; one card for a show's episodes", (
    tester,
  ) async {
    wideWindow(tester);
    await tester.pumpWidget(app(logs: [watched, episode(1), episode(2)]));
    await tester.pumpAndSettle();
    expect(find.text('Some Show'), findsOneWidget);
    expect(find.text(l10n.watchHistoryDateToday), findsNothing);

    await tester.tap(find.text(l10n.watchHistoryViewTimeline));
    await tester.pumpAndSettle();

    expect(find.text(l10n.watchHistoryDateToday), findsOneWidget);
    expect(
      find.text('2 • ${l10n.watchHistoryEpisodeRange(1, 1, 2)}'),
      findsOneWidget,
    );
    expect(find.text('Some Show'), findsOneWidget);
    expect(find.text('Some Movie'), findsWidgets);
  });

  testWidgets('search keeps only the matching titles and the count follows', (
    tester,
  ) async {
    wideWindow(tester);
    await tester.pumpWidget(app(logs: [watched, episode(1)]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'show');
    await tester.pumpAndSettle();

    expect(find.text('Some Show'), findsOneWidget);
    expect(find.text('Some Movie'), findsNothing);
    expect(find.text(l10n.watchHistoryFilteredCount(1, 2)), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.commonClearSearch));
    await tester.pumpAndSettle();
    expect(find.text('Some Movie'), findsWidgets);
  });

  group('the Ratings view', () {
    setUpAll(loadAppFont);

    OwnReview rating(WatchHistory title, int score) => OwnReview(
      tmdbId: title.tmdbId,
      mediaType: title.mediaType,
      rating: score,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    Future<Map<String, OwnReview>> ratings() async => {
      'movie-1': rating(watched, 9),
      'tv-2': rating(episode(1), 4),
    };

    Future<void> openRatings(WidgetTester tester) async {
      await tester.tap(find.text(l10n.watchHistoryViewRatings));
      await tester.pumpAndSettle();
    }

    testWidgets('posters under their wreath and number, highest first', (
      tester,
    ) async {
      wideWindow(tester);
      await tester.pumpWidget(
        app(logs: [watched, episode(1)], reviews: ratings),
      );
      await tester.pumpAndSettle();
      await openRatings(tester);

      final wreaths = tester.widgetList<Wreath>(find.byType(Wreath)).toList();
      expect(wreaths.map((w) => w.score), [9, 4]);
      expect(wreaths.map((w) => w.size), [36, 36]);
      expect(
        tester.getTopLeft(find.text('Some Movie').first).dy,
        lessThan(tester.getTopLeft(find.text('Some Show').first).dy),
      );
      expect(find.text(l10n.watchHistoryRatedCount(2, 2)), findsOneWidget);
    });

    testWidgets('the count says how many of the titles are rated', (
      tester,
    ) async {
      wideWindow(tester);
      await tester.pumpWidget(
        app(
          logs: [watched, episode(1)],
          reviews: () async => {'movie-1': rating(watched, 9)},
        ),
      );
      await tester.pumpAndSettle();
      await openRatings(tester);

      expect(find.text(l10n.watchHistoryRatedCount(1, 2)), findsOneWidget);
      expect(find.text('Some Show'), findsNothing);
    });

    testWidgets('nothing rated: says so, under the header', (tester) async {
      wideWindow(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await openRatings(tester);

      expect(find.text(l10n.watchHistoryRatingsEmpty), findsOneWidget);
      expect(find.text(l10n.watchHistoryTitle), findsOneWidget);
    });

    testWidgets('the other views never read the ratings', (tester) async {
      var reads = 0;
      wideWindow(tester);
      await tester.pumpWidget(
        app(
          reviews: () async {
            reads++;
            return const {};
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.watchHistoryViewTimeline));
      await tester.pumpAndSettle();
      expect(reads, 0);

      await openRatings(tester);
      expect(reads, 1);
    });

    testWidgets(
      'a failed read shows where the posters go; the view can change',
      (tester) async {
        wideWindow(tester);
        await tester.pumpWidget(
          app(reviews: () async => throw const NetworkFailure('offline')),
        );
        await tester.pumpAndSettle();
        await openRatings(tester);

        expect(find.byType(ErrorCard), findsOneWidget);
        expect(find.text(l10n.watchHistoryTitle), findsOneWidget);
        expect(find.text('Some Movie'), findsNothing);

        await tester.tap(find.text(l10n.watchHistoryViewGrid));
        await tester.pumpAndSettle();
        expect(find.byType(ErrorCard), findsNothing);
        expect(find.text('Some Movie'), findsWidgets);
      },
    );

    testWidgets('the remote: Right to Ratings, Enter, Down to the posters', (
      tester,
    ) async {
      wideWindow(tester);
      await tester.pumpWidget(app(reviews: ratings));
      await tester.pumpAndSettle();

      await tabTo(tester, find.text(l10n.watchHistoryViewTimeline));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(Wreath), findsOneWidget);

      MediaCard? focusedCard() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<MediaCard>();
      for (var i = 0; i < 4 && focusedCard() == null; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(focusedCard()?.title, 'Some Movie');
    });

    group('the choices and Filters on a phone', () {
      void phone(WidgetTester tester, double width) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }

      Rect filtersOf(WidgetTester tester, String label) =>
          tester.getRect(find.text(label));

      final cases = [
        (locale: const Locale('en'), filters: 'Filters', ratings: 'Ratings'),
        (locale: const Locale('it'), filters: 'Filtri', ratings: 'Voti'),
      ];
      for (final c in cases) {
        for (final width in [320.0, 360.0, 390.0, 412.0]) {
          testWidgets(
            '${c.locale.languageCode} at $width: nothing runs off the screen',
            (tester) async {
              phone(tester, width);
              await tester.pumpWidget(app(locale: c.locale));
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
              expect(find.text(c.ratings), findsOneWidget);
              expect(
                filtersOf(tester, c.filters).right,
                lessThanOrEqualTo(width),
              );
            },
          );
        }
      }

      testWidgets('narrow: Filters goes below the choices, at the right', (
        tester,
      ) async {
        phone(tester, 360);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        final filters = filtersOf(tester, l10n.watchHistoryFiltersTitle);
        final ratingsPill = tester.getRect(
          find.text(l10n.watchHistoryViewRatings),
        );
        expect(filters.top, greaterThan(ratingsPill.bottom));
        expect(filters.left, greaterThan(360 / 2));
      });

      testWidgets('wide enough: Filters stays on the line of the choices', (
        tester,
      ) async {
        phone(tester, 412);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        expect(
          filtersOf(tester, l10n.watchHistoryFiltersTitle).center.dy,
          closeTo(
            tester.getCenter(find.text(l10n.watchHistoryViewRatings)).dy,
            2,
          ),
        );
      });

      testWidgets('below the choices it still opens, by tap and by remote', (
        tester,
      ) async {
        phone(tester, 360);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.watchHistoryFiltersTitle));
        await tester.pumpAndSettle();
        expect(find.text(l10n.watchHistoryApplyFilters), findsOneWidget);
        await tester.tapAt(const Offset(180, 10));
        await tester.pumpAndSettle();

        await tabTo(tester, find.text(l10n.watchHistoryViewRatings));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text(l10n.watchHistoryApplyFilters), findsOneWidget);
      });
    });
  });

  testWidgets('phone: Series in the filter sheet hides the movies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(590, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(logs: [watched, episode(1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.watchHistoryFiltersTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.searchSeries).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.watchHistoryApplyFilters));
    await tester.pumpAndSettle();

    expect(find.text('Some Show'), findsOneWidget);
    expect(find.text('Some Movie'), findsNothing);
    // The Filters button counts the active filter.
    expect(find.text('1'), findsOneWidget);
  });
}
