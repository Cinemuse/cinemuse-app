/// Opens every main screen at every device size, in Italian (its words are
/// the longest), and fails when something doesn't fit, an error shows, or a
/// screen comes up without its content.
///
/// On demand only (`dart_test.yaml` skips it in the everyday run), before a
/// release, after a Flutter upgrade and after a screen redesign:
///   fvm flutter test --run-skipped -t screen-sizes
@Tags(['screen-sizes'])
library;

import 'dart:math' as math;

import 'package:cinemuse_app/core/application/locale_service.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/core/services/system/app_full_screen.dart';
import 'package:cinemuse_app/core/utils/platform_info.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/navigation/presentation/app_shell.dart';
import 'package:cinemuse_app/features/profile/presentation/watch_history_screen.dart';
import 'package:cinemuse_app/features/search/presentation/search_overlay.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_category.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_screen.dart';
import 'package:cinemuse_app/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_font.dart';
import '../helpers/fake_app_window.dart';
import '../helpers/override_helpers.dart';
import 'made_up_account.dart';
import 'made_up_player.dart';
import 'made_up_tmdb.dart';

/// A device: its screen in real pixels, and what the app is told it is.
class _Device {
  final String name;
  final Size pixels;
  final double pixelRatio;
  final TargetPlatform platform;
  final bool isTv;

  const _Device(
    this.name,
    this.pixels, {
    this.pixelRatio = 1,
    this.platform = TargetPlatform.android,
    this.isTv = false,
  });
}

const _devices = [
  // A narrow Android phone.
  _Device('phone', Size(360, 800)),
  // The same phone turned: as wide as a small window, less than half as tall.
  _Device('phone sideways', Size(800, 360)),
  _Device('tablet upright', Size(800, 1280)),
  // A Fire Stick: Android counts its 1920 x 1080 as 960 x 540, the tightest
  // a TV gets (Screen size 100%; it starts at 67%, which is roomier).
  _Device('TV at 100%', Size(1920, 1080), pixelRatio: 2, isTv: true),
  // The smallest the window gets on Windows and Linux (main.dart).
  _Device('smallest window', Size(900, 600), platform: TargetPlatform.windows),
];

/// A screen: how to open it, and what it shows once loaded.
class _Screen {
  final String name;
  final Future<void> Function(WidgetTester tester) open;
  final Finder Function() shows;

  const _Screen(this.name, this.open, this.shows);
}

NavigatorState _shellNavigator(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    ).read(shellNavigatorKeyProvider).currentState!;

Future<void> _openTab(WidgetTester tester, int tab) async {
  ProviderScope.containerOf(
    tester.element(find.byType(AppShell)),
  ).read(navIndexProvider.notifier).set(tab);
  await _settle(tester);
}

Future<void> _openPage(WidgetTester tester, Widget page) async {
  // Not awaited: the page's Future ends only when it closes.
  _shellNavigator(
    tester,
  ).push(MaterialPageRoute<void>(builder: (_) => page)).ignore();
  await _settle(tester);
}

Future<void> _openSettings(
  WidgetTester tester,
  SettingsCategory section,
) async {
  await _openPage(tester, const SettingsScreen());
  // The side menu can be taller than a sideways phone.
  final item = find.byIcon(section.icon);
  await tester.scrollUntilVisible(
    item,
    50,
    scrollable: find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(item.first);
  await tester.pump();
  await tester.tap(item.first);
  await _settle(tester);
}

Future<void> _openSearch(WidgetTester tester) async {
  SearchOverlay.show(
    tester.element(find.byType(AppShell)),
    navigator: _shellNavigator(tester),
  ).ignore();
  await _settle(tester);
  await tester.enterText(
    find.descendant(
      of: find.byType(SearchOverlay),
      matching: find.byType(TextField),
    ),
    'Amélie',
  );
  await _settle(tester, seconds: 2);
}

Future<void> _openPlayer(WidgetTester tester, {required bool isLive}) async {
  CinemuseApp.navigatorKey.currentState!
      .push(
        MaterialPageRoute<void>(
          builder: (_) => MadeUpPlayerControls(isLive: isLive),
        ),
      )
      .ignore();
  await _settle(tester);
}

final _screens = [
  _Screen('Home', (t) => _openTab(t, NavTab.home), () => find.text(filmTitle)),
  _Screen(
    'Explore',
    (t) => _openTab(t, NavTab.explore),
    () => find.text(filmTitle),
  ),
  _Screen(
    'Live TV',
    (t) => _openTab(t, NavTab.liveTv),
    () => find.text('Rai 1'),
  ),
  _Screen(
    'Library',
    (t) => _openTab(t, NavTab.profile),
    () => find.text(filmTitle),
  ),
  _Screen(
    'Search',
    _openSearch,
    () => find.descendant(
      of: find.byType(SearchOverlay),
      matching: find.text(filmTitle),
    ),
  ),
  _Screen(
    'Film page',
    (t) => _openPage(
      t,
      const MediaDetailsScreen(mediaId: '$filmId', mediaType: 'movie'),
    ),
    () => find.text(filmTitle),
  ),
  _Screen(
    'Series page',
    (t) => _openPage(
      t,
      const MediaDetailsScreen(mediaId: '$seriesId', mediaType: 'tv'),
    ),
    // Also just below the edge: the long title's top part can fill the
    // first screen.
    () => find.textContaining(episodeTitle, skipOffstage: false),
  ),
  _Screen(
    'Person page',
    (t) => _openPage(t, const PersonDetailsScreen(personId: personId)),
    () => find.text(personName),
  ),
  _Screen(
    'Watch history',
    (t) => _openPage(t, const WatchHistoryScreen()),
    () => find.text(filmTitle),
  ),
  for (final section in SettingsCategory.values)
    _Screen(
      'Settings: ${section.name}',
      (t) => _openSettings(t, section),
      () => find.byWidgetPredicate(
        (w) => w.runtimeType == section.content.runtimeType,
      ),
    ),
  _Screen(
    'Player: film',
    (t) => _openPlayer(t, isLive: false),
    () => find.textContaining(filmTitle),
  ),
  _Screen(
    'Player: live TV',
    (t) => _openPlayer(t, isLive: true),
    () => find.textContaining('Canale 5'),
  ),
];

/// Lets loading, the made-up answers and the page animations finish. Not
/// `pumpAndSettle`: loading spinners and clocks never settle.
Future<void> _settle(WidgetTester tester, {int seconds = 1}) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls the screen's main list down to its end, a screenful at a time,
/// so the rows built only once they come near the screen are checked too.
Future<void> _scrollToEnd(WidgetTester tester) async {
  for (var step = 0; step < 40; step++) {
    final lists = find
        .byType(Scrollable)
        .evaluate()
        .map((e) => (e as StatefulElement).state as ScrollableState)
        .where(
          (s) =>
              s.position.axis == Axis.vertical &&
              s.position.hasContentDimensions &&
              s.position.maxScrollExtent > 0,
        )
        .toList();
    if (lists.isEmpty) return;
    final main = lists
        .reduce(
          (a, b) => a.position.viewportDimension >= b.position.viewportDimension
              ? a
              : b,
        )
        .position;
    if (main.pixels >= main.maxScrollExtent) return;
    main.jumpTo(
      math.min(
        main.pixels + main.viewportDimension * 0.8,
        main.maxScrollExtent,
      ),
    );
    await _settle(tester);
  }
}

/// What went wrong, with the app's code line that drew it when known.
String _describe(FlutterErrorDetails details) {
  final what = details.exceptionAsString().split('\n').first;
  final where = RegExp(
    r'lib/[\w/]+\.dart:\d+',
  ).firstMatch(details.toString())?.group(0);
  return where == null ? what : '$what ($where)';
}

/// Notes every piece of data that fails to load: a screen showing an error
/// instead of its content, or made-up data that no longer covers it.
final class _FailWatcher extends ProviderObserver {
  final Set<String> problems;

  _FailWatcher(this.problems);

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final name = context.provider.name ?? context.provider.runtimeType;
    problems.add('$name failed: ${error.toString().split('\n').first}');
  }
}

/// Notes a screen that came up without [content], with the first words it
/// shows instead (an error message, a loading screen…).
void _checkShows(Finder content, Set<String> problems) {
  if (content.evaluate().isNotEmpty) return;
  final words = find
      .byType(Text)
      .hitTestable()
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .nonNulls
      .take(20)
      .join(' | ');
  problems.add('its content is not on screen; it shows: $words');
}

class _Italian extends LocaleNotifier {
  @override
  Locale build() => const Locale('it');
}

Future<void> _startApp(
  WidgetTester tester,
  _Device device,
  Set<String> problems, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = device.pixels;
  tester.view.devicePixelRatio = device.pixelRatio;
  debugDefaultTargetPlatformOverride = device.platform;
  PlatformInfo.setTvForTesting(device.isTv);
  // A TV starts at 67%; this checks it at its tightest.
  SharedPreferences.setMockInitialValues({
    if (device.isTv) 'screen_percent': 100,
  });

  await tester.pumpWidget(
    ProviderScope(
      retry: noProviderRetry,
      observers: [_FailWatcher(problems)],
      overrides: withOwnOverrides([
        ...madeUpAccountOverrides(),
        localeProvider.overrideWith(_Italian.new),
        appWindowProvider.overrideWithValue(FakeAppWindow()),
        appFullScreenProvider.overrideWith(
          () => AppFullScreenNotifier(startsOn: false),
        ),
      ], overrides),
      child: const CinemuseApp(),
    ),
  );
  await _settle(tester);
}

/// Runs [body] with every error noted in [problems] instead of failing at
/// the first, then puts the test setup back.
Future<void> _collectingProblems(
  WidgetTester tester,
  Set<String> problems,
  Future<void> Function() body,
) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) => problems.add(_describe(details));
  try {
    await body();
    // Closes the app, so its timers stop before the test ends.
    await tester.pumpWidget(const SizedBox());
  } finally {
    FlutterError.onError = original;
    debugDefaultTargetPlatformOverride = null;
    PlatformInfo.setTvForTesting(null);
    tester.view.reset();
  }
}

/// Problems already known and waiting for the user's choice, so a run shows
/// only new ones. Delete a line once its problem is fixed.
String? _knownProblem(_Device device, _Screen screen) {
  // 800 wide (a tablet upright, a phone sideways) gets the computer layout,
  // whose top bar needs 900: waits for the decision about the phone held
  // sideways. The Library's agenda rows and a stats line don't fit there
  // either.
  if (device.pixels.width == 800) return 'top bar at 800 wide';
  return null;
}

void main() {
  setUpAll(loadAppFont);

  for (final device in _devices) {
    group(device.name, () {
      testWidgets('Login', (tester) async {
        final problems = <String>{};
        await _collectingProblems(tester, problems, () async {
          await _startApp(
            tester,
            device,
            problems,
            overrides: [
              authProvider.overrideWithBuild(
                (ref, notifier) => const AsyncData(null),
              ),
            ],
          );
          _checkShows(find.byType(TextField), problems);
          await _scrollToEnd(tester);
        });
        expect(problems, isEmpty);
      });

      for (final screen in _screens) {
        final known = _knownProblem(device, screen);
        testWidgets(screen.name, (tester) async {
          // Skipped from inside: the on-demand command runs skipped tests.
          if (known != null) return markTestSkipped('Known: $known');
          final problems = <String>{};
          await _collectingProblems(tester, problems, () async {
            await _startApp(tester, device, problems);
            await screen.open(tester);
            _checkShows(screen.shows(), problems);
            await _scrollToEnd(tester);
          });
          expect(problems, isEmpty);
        });
      }
    });
  }
}
