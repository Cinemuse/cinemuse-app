import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/profile/application/agenda_providers.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/application/pinned_list_ids_provider.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:cinemuse_app/features/profile/domain/profile_stats.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_collections.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_hub.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_overview.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/profile_hero.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/profile_tab_bar.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/shared/widgets/carousels/poster_carousel_row.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app_font.dart';
import '../../../helpers/focus_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

class _FakeUserListsNotifier extends UserListsNotifier {
  // Enough lists for a Collections tab taller than the screen.
  @override
  Stream<List<UserList>> build() => Stream.value([
    for (var i = 0; i < 20; i++)
      UserList(
        id: 'l$i',
        userId: 'user-a',
        name: 'List $i',
        type: ListType.custom,
        createdAt: DateTime(2026),
      ),
  ]);
}

class _FakePinnedListIdsNotifier extends PinnedListIdsNotifier {
  @override
  Set<String> build() => {};
}

/// A film or series watched [hoursAgo], for the "Recent" rows.
WatchHistory _watched(int id, MediaKind kind, String title, int hoursAgo) =>
    WatchHistory(
      userId: 'user-a',
      tmdbId: id,
      mediaType: kind,
      status: WatchStatus.completed,
      progressSeconds: 0,
      watchCount: 1,
      lastWatchedAt: DateTime(2026, 11, 1).subtract(Duration(hours: hoursAgo)),
      media: MediaItem.fromTmdbMap({
        'id': id,
        'media_type': kind.name,
        if (kind == MediaKind.movie) 'title': title else 'name': title,
      }),
    );

final _someHistory = [
  _watched(1, MediaKind.movie, 'Film A', 1),
  _watched(2, MediaKind.movie, 'Film B', 2),
  _watched(3, MediaKind.tv, 'Series A', 3),
];

AgendaEvent _event(int id, String title) => AgendaEvent(
  id: 'movie_$id',
  tmdbId: id,
  title: title,
  releaseDate: DateTime.now(),
  type: MediaKind.movie,
);

// REV-239: Profile is one page: hero, tab names, then the chosen tab, in one
// scroll view (a TabBarView in a NestedScrollView made the desktop scrollbar
// assert on the Collections tab).
void main() {
  final l10n = AppLocalizationsEn();
  setUpAll(loadAppFont);

  const phone = Size(400, 800);
  const desktop = Size(1280, 700);

  Future<void> pumpHub(
    WidgetTester tester, {
    required Size size,
    List<WatchHistory> history = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityResult.wifi),
          ),
          profileStreamProvider.overrideWith((ref) => Stream.value(null)),
          recentlyWatchedStreamProvider.overrideWithValue(AsyncData(history)),
          // The posters' marks read it.
          watchHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
          profileStatsProvider.overrideWith(
            (ref) => Stream.value(ProfileStats.empty()),
          ),
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          // Released items above Today: the agenda opens scrolled to Today.
          agendaProvider.overrideWith(
            (ref) async => {
              AgendaGroup.recentlyReleased: [
                for (var i = 0; i < 8; i++) _event(i, 'Old $i'),
              ],
              AgendaGroup.today: [_event(100, 'Today Movie')],
            },
          ),
          userListsProvider.overrideWith(_FakeUserListsNotifier.new),
          droppedListProvider.overrideWith((ref) async => null),
          pinnedListIdsProvider.overrideWith(_FakePinnedListIdsNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProfileHub(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double heroTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(ProfileHero)).dy;
  // Also once scrolled far off the screen.
  final tabNames = find.byType(ProfileTabBar, skipOffstage: false);
  double tabNamesTop(WidgetTester tester) => tester.getTopLeft(tabNames).dy;

  /// A quick sideways swipe on the content: just under the tab names, or
  /// mid-screen once they are scrolled away.
  Future<void> swipe(
    WidgetTester tester,
    double dx, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    final y = tabNamesTop(tester) > 0
        ? tester.getBottomLeft(tabNames).dy + 12
        : 400.0;
    await tester.flingFrom(
      Offset(200, y),
      Offset(dx, 0),
      1000,
      deviceKind: kind,
    );
    await tester.pumpAndSettle();
  }

  Future<void> wheel(WidgetTester tester, double dy) async {
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    mouse.hover(tester.getCenter(find.byType(ProfileHub)));
    await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
    await tester.pumpAndSettle();
  }

  // REV-322: each tab name filled the whole width, so the two stacked, each
  // centred on its own line.
  for (final size in [phone, desktop]) {
    testWidgets('$size: the tab names sit side by side, on the left', (
      tester,
    ) async {
      await pumpHub(tester, size: size);
      final overview = tester.getRect(find.text(l10n.profileOverview));
      final collections = tester.getRect(find.text(l10n.profileCollections));
      expect(collections.top, overview.top);
      expect(collections.left, greaterThan(overview.right));
      // Lined up with the picture, like the old Material tab row.
      final left = tester.getTopLeft(find.byType(ProfileHero)).dx;
      expect(overview.left, lessThan(left + 40));
    });
  }

  testWidgets(
    'desktop: switch tab under the mouse and scroll, no error',
    (tester) async {
      await pumpHub(tester, size: desktop);

      await tester.tap(find.text(l10n.profileCollections));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileCollections), findsOneWidget);
      expect(find.byType(ProfileOverview), findsNothing);

      // The header scrolls away with the content: one page, one scroll.
      final contentTop = tester.getTopLeft(find.byType(ProfileCollections)).dy;
      await wheel(tester, 400);
      expect(
        tester.getTopLeft(find.byType(ProfileCollections)).dy,
        contentTop - 400,
      );

      await wheel(tester, -400);
      await tester.tap(find.text(l10n.profileOverview));
      await tester.pumpAndSettle();
      await wheel(tester, 200);
      expect(tester.takeException(), isNull);
      // On Windows the scroll behaviour adds the desktop scrollbar.
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('phone: a quick swipe switches tab; a mouse drag does not', (
    tester,
  ) async {
    await pumpHub(tester, size: phone);

    await swipe(tester, -300);
    await tester.pumpAndSettle();
    expect(find.byType(ProfileCollections), findsOneWidget);

    await swipe(tester, 300, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.byType(ProfileCollections), findsOneWidget);

    await swipe(tester, 300);
    await tester.pumpAndSettle();
    expect(find.byType(ProfileOverview), findsOneWidget);
  });

  testWidgets('switching while scrolled past the tab names puts them on top', (
    tester,
  ) async {
    await pumpHub(tester, size: phone);
    await swipe(tester, -300);
    await tester.pumpAndSettle();

    // Scrolled a little: the tab names are still on screen, nothing jumps.
    await tester.dragFrom(const Offset(200, 400), const Offset(0, -100));
    await tester.pumpAndSettle();
    final names = tabNamesTop(tester);
    expect(names, greaterThan(0));
    await swipe(tester, 300);
    await tester.pumpAndSettle();
    expect(tabNamesTop(tester), names);

    // Back to the long Collections tab, scrolled far down: the switch to
    // Overview brings the tab names to the top of the screen.
    await swipe(tester, -300);
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(200, 400), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tabNamesTop(tester), lessThan(0));
    await swipe(tester, 300);
    await tester.pumpAndSettle();
    expect(find.byType(ProfileOverview), findsOneWidget);
    expect(tabNamesTop(tester), closeTo(0, 1));
  });

  // REV-317: the agenda's first scroll to Today scrolled the whole page down
  // to the agenda.
  testWidgets('phone: the agenda opens on Today without moving the page', (
    tester,
  ) async {
    await pumpHub(tester, size: phone);
    expect(heroTop(tester), 60);
  });

  group('dragging over the agenda', () {
    final hero = find.byType(ProfileHero, skipOffstage: false);
    double pageTop(WidgetTester tester) => tester.getTopLeft(hero).dy;
    // The agenda opens at its end here: Today Movie is its last row.
    final lastRow = find.text('Today Movie');
    final firstRow = find.text('Old 0', skipOffstage: false);

    Future<void> pan(WidgetTester tester, Offset at, double dy) async {
      final fingers = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await fingers.panZoomStart(at);
      for (var moved = 0.0; moved.abs() < dy.abs(); moved += dy.sign * 20) {
        await fingers.panZoomUpdate(at, pan: Offset(0, moved + dy.sign * 20));
        await tester.pump();
      }
      await fingers.panZoomEnd();
      await tester.pumpAndSettle();
    }

    Future<void> pumpScrolledToAgenda(WidgetTester tester) async {
      await pumpHub(tester, size: const Size(1280, 500));
      await wheel(tester, 250);
    }

    final windowsOnly = TargetPlatformVariant.only(TargetPlatform.windows);

    testWidgets(
      'at the agenda\'s end the page moves; inside it only the agenda does',
      (tester) async {
        await pumpScrolledToAgenda(tester);
        final startTop = pageTop(tester);

        // Already at the bottom: pushing on moves the page.
        await pan(tester, tester.getCenter(lastRow), -100);
        final afterPush = pageTop(tester);
        expect(afterPush, lessThan(startTop));

        // Back up, inside the list: the page stays. (The page moved, so the
        // row is looked up again: the pointer has to stay over the agenda.)
        final at = tester.getCenter(lastRow);
        final rowTop = tester.getTopLeft(lastRow).dy;
        await pan(tester, at, 50);
        expect(pageTop(tester), afterPush);
        expect(tester.getTopLeft(lastRow).dy, greaterThan(rowTop));

        // Past the list's top: the page follows, all the way to its own top.
        await pan(tester, at, 1500);
        expect(tester.getTopLeft(firstRow).dy, greaterThan(0));
        expect(pageTop(tester), 60);
      },
      variant: windowsOnly,
    );

    testWidgets(
      'fingers lifted while the page moves: the page glides on',
      (tester) async {
        await pumpScrolledToAgenda(tester);
        final startTop = pageTop(tester);

        await tester.trackpadFling(lastRow, const Offset(0, -60), 800);
        await tester.pumpAndSettle();

        expect(startTop - pageTop(tester), greaterThan(60));
      },
      variant: windowsOnly,
    );

    testWidgets('phone: a finger past the agenda\'s top moves the page, and '
        'the agenda does not stretch', (tester) async {
      await pumpHub(tester, size: phone);
      await wheel(tester, 5000);
      final startTop = pageTop(tester);

      final finger = await tester.startGesture(tester.getCenter(lastRow));
      for (var i = 0; i < 60 && pageTop(tester) == startTop; i++) {
        await finger.moveBy(const Offset(0, 50));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(pageTop(tester), greaterThan(startTop));

      // The list stays at its normal size: its rows move with the page.
      double rowInPage() => tester.getTopLeft(firstRow).dy - pageTop(tester);
      final before = rowInPage();
      final topBefore = pageTop(tester);
      await finger.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 200));
      expect(pageTop(tester), greaterThan(topBefore));
      expect(rowInPage(), closeTo(before, 0.01));

      await finger.up();
      await tester.pumpAndSettle();
    });
  });

  group('keyboard (REV-239)', () {
    testWidgets('Tab finishes the left column before the agenda', (
      tester,
    ) async {
      await pumpHub(tester, size: desktop, history: _someHistory);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileHub)),
      );
      container.read(pageContentFocusActionsProvider)[NavTab.profile]!();
      await tester.pump();
      expect(isFocused(find.text(l10n.profileOverview)), isTrue);

      // The left column ends with the "Recent series" row's See all.
      final seriesSeeAll = find.descendant(
        of: find.ancestor(
          of: find.text('Series A'),
          matching: find.byType(PosterCarouselRow),
        ),
        matching: find.text(l10n.carouselSeeAll),
      );
      final agendaRows = find.textContaining(RegExp(r'^(Old \d|Today Movie)$'));
      var reachedAgenda = false;
      for (var i = 0; i < 30 && !isFocused(seriesSeeAll); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        if (isFocused(agendaRows)) reachedAgenda = true;
      }
      expect(isFocused(seriesSeeAll), isTrue);
      expect(reachedAgenda, isFalse, reason: 'agenda before the left column');
      // Then on into the agenda.
      await tabTo(tester, find.text('Today Movie'), max: 30);
    });

    testWidgets('Enter on a tab name switches tab; Up goes to the navbar', (
      tester,
    ) async {
      await pumpHub(tester, size: desktop);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileHub)),
      );
      var navbarFocused = false;
      container
          .read(topNavbarFocusActionProvider.notifier)
          .set(() => navbarFocused = true);

      await tabTo(tester, find.text(l10n.profileCollections));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileCollections), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(navbarFocused, isTrue);
    });

    Future<void> focusOverviewTab(WidgetTester tester) async {
      ProviderScope.containerOf(
        tester.element(find.byType(ProfileHub)),
      ).read(pageContentFocusActionsProvider)[NavTab.profile]!();
      await tester.pump();
      expect(isFocused(find.text(l10n.profileOverview)), isTrue);
    }

    // Up from the films row went to the row's title, then to Collections:
    // Flutter picked the nearest tab name, not the one being shown.
    testWidgets('Up from the first row goes to the tab being shown', (
      tester,
    ) async {
      await pumpHub(tester, size: desktop, history: _someHistory);
      await focusOverviewTab(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(find.text('Film A')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(isFocused(find.text('Film B')), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isFocused(find.text(l10n.profileOverview)), isTrue);

      // Rows below still move up to the row above.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(find.text('Series A')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isFocused(find.textContaining(RegExp(r'^Film [AB]$'))), isTrue);
    });

    // Right from Collections jumped to an agenda entry, often off the screen.
    testWidgets('Right past the last tab name and Left past the first stay', (
      tester,
    ) async {
      await pumpHub(tester, size: desktop, history: _someHistory);
      await focusOverviewTab(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(isFocused(find.text(l10n.profileOverview)), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(isFocused(find.text(l10n.profileCollections)), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(isFocused(find.text(l10n.profileCollections)), isTrue);
    });
  });
}
