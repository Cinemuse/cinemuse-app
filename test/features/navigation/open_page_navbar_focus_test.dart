import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/person_providers.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/navigation/presentation/app_shell.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/presentation/watch_history_screen.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_screen.dart';
import 'package:cinemuse_app/features/streaming/anime/anime_mapping_sync_service.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/app_font.dart';
import '../../helpers/focus_helpers.dart';
import '../../helpers/offline_lists.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

class _MockResolver extends Mock implements UnifiedStreamResolver {}

class _NoUpdateCheck extends UpdateNotifier {
  @override
  UpdateState build() => UpdateState(status: UpdateStatus.upToDate);

  @override
  Future<void> checkForUpdates() async {}
}

class _NoAnimeSync implements AnimeMappingSyncService {
  @override
  Future<void> checkAndSync() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A tab whose only button is the target of the tab's own Down action.
class _Tab extends ConsumerStatefulWidget {
  final String label;

  /// A long tab, like Home: a last row far below the button.
  final bool hasLastRow;

  const _Tab(this.label, {this.hasLastRow = false});

  @override
  ConsumerState<_Tab> createState() => _TabState();
}

class _TabState extends ConsumerState<_Tab> {
  final _node = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.label != 'Home tab') return;
      final actions = ref.read(pageContentFocusActionsProvider);
      ref.read(pageContentFocusActionsProvider.notifier).set({
        ...actions,
        NavTab.home: _node.requestFocus,
      });
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      focusNode: _node,
      onPressed: () {},
      child: Text(widget.label),
    );
    if (!widget.hasLastRow) return Center(child: button);
    return SingleChildScrollView(
      child: Column(
        children: [
          button,
          const SizedBox(height: 3000),
          TextButton(onPressed: () {}, child: const Text('Last row')),
        ],
      ),
    );
  }
}

/// A page opened over the tabs, like a title page: two rows of buttons.
class _OpenPage extends StatelessWidget {
  const _OpenPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(onPressed: () {}, child: const Text('Top button')),
        const SizedBox(height: 40),
        TextButton(onPressed: () {}, child: const Text('Lower button')),
      ],
    ),
  );
}

// Flutter's test keys have no Android scan code for the remote's Back button:
// it is sent as the web names it, and the app sees the same Back key.
Future<bool> pressRemoteBack() => simulateKeyDownEvent(
  LogicalKeyboardKey.goBack,
  physicalKey: PhysicalKeyboardKey.browserBack,
  platform: 'web',
);

/// A long page opened over the tabs, with the round ← at its top.
class _LongPage extends StatelessWidget {
  const _LongPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      child: Column(
        children: [
          AppBackButton(onTap: () {}),
          const SizedBox(height: 700),
          TextButton(onPressed: () {}, child: const Text('Top button')),
          const SizedBox(height: 1500),
          TextButton(onPressed: () {}, child: const Text('Lower button')),
        ],
      ),
    ),
  );
}

/// TMDB's details answer [tmdb] as the app reads it.
MediaItem _details(String type, Map<String, dynamic> tmdb) =>
    MediaItem.fromTmdbDetails(tmdb, MediaItem.fromString(type));

void main() {
  setUpAll(loadAppFont);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<NavigatorState> pumpShell(
    WidgetTester tester, {
    List<Override> overrides = const [],
    bool homeHasLastRow = false,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late NavigatorState Function() shellNavigator;
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          updateProvider.overrideWith(_NoUpdateCheck.new),
          animeMappingSyncServiceProvider.overrideWithValue(_NoAnimeSync()),
          ...overrides,
        ],
        child: Consumer(
          builder: (context, ref, _) {
            shellNavigator = () =>
                ref.read(shellNavigatorKeyProvider).currentState!;
            return MaterialApp(
              theme: AppTheme.darkTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: AppShell(
                tabsForTesting: [
                  _Tab('Home tab', hasLastRow: homeHasLastRow),
                  const _Tab('Explore tab'),
                  const _Tab('Live TV tab'),
                  const _Tab('Library tab'),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return shellNavigator();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  testWidgets('Up from the top of an open page reaches the navbar, and Down '
      'goes back to the same button', (tester) async {
    final navigator = await pumpShell(tester);
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const _OpenPage()),
      ),
    );
    await tester.pumpAndSettle();

    // First Down from the navbar lands on the page's top button.
    await tabTo(tester, find.text('Home'));
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(isFocused(find.text('Top button')), isTrue);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(isFocused(find.text('Lower button')), isTrue);

    // Up moves on the page first, then to the navbar's active tab.
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(isFocused(find.text('Top button')), isTrue);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(isFocused(find.text('Home')), isTrue);

    // Down goes back to where the focus was, not to the hidden tab.
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(isFocused(find.text('Top button')), isTrue);
    expect(isFocused(find.text('Home tab')), isFalse);
  });

  testWidgets('Up just after the app opens, with nothing focused yet, goes '
      "to the tab's top item, not its last row", (tester) async {
    await pumpShell(tester, homeHasLastRow: true);
    final tab = tester.state<ScrollableState>(find.byType(Scrollable).last);

    await press(tester, LogicalKeyboardKey.arrowUp);

    expect(isFocused(find.text('Home tab')), isTrue);
    expect(isFocused(find.text('Last row')), isFalse);
    expect(tab.position.pixels, 0);
  });

  testWidgets('Down from the navbar still goes to the tab when no page is '
      'open', (tester) async {
    await pumpShell(tester);

    await tabTo(tester, find.text('Home'));
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(isFocused(find.text('Home tab')), isTrue);
  });

  testWidgets('Settings opened from the navbar: Up from its top reaches the '
      'navbar', (tester) async {
    await pumpShell(tester);

    await tabTo(tester, find.byIcon(Icons.settings_outlined));
    await press(tester, LogicalKeyboardKey.enter);

    await tabTo(tester, find.text('Home'));
    await press(tester, LogicalKeyboardKey.arrowDown);
    final onPage = FocusManager.instance.primaryFocus;
    expect(onPage, isNotNull);
    expect(isFocused(find.text('Home')), isFalse);

    await press(tester, LogicalKeyboardKey.arrowUp);
    // Settings may need a few presses to reach its top row.
    for (var i = 0; i < 10 && !isFocused(find.text('Home')); i++) {
      await press(tester, LogicalKeyboardKey.arrowUp);
    }
    expect(isFocused(find.text('Home')), isTrue);
  });

  testWidgets('Up to the navbar shows the top of a page scrolled down', (
    tester,
  ) async {
    final navigator = await pumpShell(tester);
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const _LongPage()),
      ),
    );
    await tester.pumpAndSettle();
    final page = tester.state<ScrollableState>(find.byType(Scrollable).last);

    await tabTo(tester, find.text('Home'));
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(isFocused(find.text('Top button')), isTrue);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(isFocused(find.text('Lower button')), isTrue);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(isFocused(find.text('Top button')), isTrue);
    expect(page.position.pixels, greaterThan(0));

    await press(tester, LogicalKeyboardKey.arrowUp);

    expect(isFocused(find.text('Home')), isTrue);
    expect(page.position.pixels, 0);
  });

  group('with the round ← hidden, on the keys', () {
    List<Override> pageOverrides() {
      final resolver = _MockResolver();
      when(
        () => resolver.hasCachedStream(
          any(),
          any(),
          season: any(named: 'season'),
          episode: any(named: 'episode'),
        ),
      ).thenReturn(false);
      return [
        ...offlineListsOverrides(),
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        connectivityProvider.overrideWith(
          (ref) => Stream.value(ConnectivityResult.wifi),
        ),
        // The title page.
        unifiedStreamResolverProvider.overrideWithValue(resolver),
        mediaDetailsProvider.overrideWith(
          (ref, args) async =>
              _details(args.type, {'id': 1, 'title': 'Some Movie'}),
        ),
        movieWatchCountProvider.overrideWith((ref, id) => 0),
        watchHistoryStoreProvider.overrideWith((ref) => Stream.value(const {})),
        // The person page.
        personDetailsProvider.overrideWith(
          (ref, id) async => const PersonDetails(id: 1, name: 'Someone'),
        ),
        // Watch history.
        watchLogsProvider.overrideWith((ref) async => []),
        watchHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
      ];
    }

    final pages = <String, Widget>{
      'title page': const MediaDetailsScreen(mediaId: '1', mediaType: 'movie'),
      'person page': const PersonDetailsScreen(personId: 1),
      'watch history': const WatchHistoryScreen(),
      'Settings': const SettingsScreen(),
    };

    Future<void> openPage(WidgetTester tester, Widget page) async {
      final navigator = await pumpShell(tester, overrides: pageOverrides());
      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => page)));
      await tester.pumpAndSettle();
      expect(find.byWidget(page), findsOneWidget);
    }

    pages.forEach((name, page) {
      for (final (keyName, pressKey) in [
        ('Esc', (WidgetTester t) => t.sendKeyEvent(LogicalKeyboardKey.escape)),
        (
          "the gamepad's B",
          (WidgetTester t) => t.sendKeyEvent(LogicalKeyboardKey.gameButtonB),
        ),
        ("the remote's Back", (WidgetTester _) => pressRemoteBack()),
      ]) {
        testWidgets('$keyName closes the $name', (tester) async {
          await openPage(tester, page);

          await pressKey(tester);
          await tester.pumpAndSettle();

          expect(find.byWidget(page), findsNothing);
          expect(find.text('Home tab'), findsOneWidget);
        });
      }

      testWidgets('the $name: the arrows never land on the ←, and Up gets '
          'back to the navbar', (tester) async {
        await openPage(tester, page);

        await tabTo(tester, find.text('Home'));
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(isFocused(find.byIcon(Icons.arrow_back)), isFalse);

        for (var i = 0; i < 10 && !isFocused(find.text('Home')); i++) {
          await press(tester, LogicalKeyboardKey.arrowUp);
          expect(isFocused(find.byIcon(Icons.arrow_back)), isFalse);
        }
        expect(isFocused(find.text('Home')), isTrue);
      });
    });
  });
}
