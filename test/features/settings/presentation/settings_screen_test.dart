import 'dart:async';
import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';

import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/phone_orientation.dart';
import 'package:cinemuse_app/features/navigation/application/back_navigation_notifier.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_guide.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_source.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/application/watch_region_providers.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_screen.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_choice.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:cinemuse_app/shared/widgets/dpad_text_box.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/app_font.dart';
import '../../../helpers/cursor_helpers.dart';
import '../../../helpers/focus_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

/// Both debrid services on: Integrations shows the preferred-debrid choice.
class _BothDebridSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() =>
      const UserSettings(enableRealDebrid: true, enableTorBox: true);
}

/// Saves straight into its state: the row tests check what a tap saved.
class _SavingSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();

  @override
  Future<void> updateSettings(
    UserSettings Function(UserSettings current) change,
  ) async => state = change(state);
}

/// The Live TV page's playlists and guides, without a server.
class _EmptyLiveTvRepository extends LiveTvRepository {
  _EmptyLiveTvRepository() : super(Dio());

  @override
  Future<LiveTvLoad<List<Channel>>> fetchChannels({
    List<LiveTvPlaylist>? playlists,
  }) async => const LiveTvLoad([]);

  @override
  Future<LiveTvLoad<Map<String, List<EpgProgram>>>> fetchEpg({
    required List<LiveTvGuide> guides,
    bool forceRefresh = false,
  }) async => const LiveTvLoad({});
}

/// Version 1.9.3 is out.
class _UpdateOutNotifier extends UpdateNotifier {
  @override
  UpdateState build() =>
      UpdateState(status: UpdateStatus.available, latestVersion: 'v1.9.3');
}

/// The "Streaming country" list, without TMDB.
final _fakeRegions = watchRegionsProvider.overrideWith(
  (ref) async => const [
    (code: 'IT', name: 'Italy'),
    (code: 'US', name: 'United States'),
  ],
);

void main() {
  setUpAll(loadAppFont);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Back on a phone (REV-86)', () {
    late GlobalKey<NavigatorState> shellNavigator;

    /// The app shell's Back wiring: pages open in the shell navigator, and
    /// the phone's Back button goes to the one Back handler.
    Future<void> pumpShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            settingsProvider.overrideWith(_FakeSettingsNotifier.new),
            _fakeRegions,
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                shellNavigator = ref.watch(shellNavigatorKeyProvider);
                return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) {
                    if (didPop) return;
                    ref
                        .read(backNavigationProvider.notifier)
                        .handleBack(canExitApp: true);
                  },
                  child: Navigator(
                    key: shellNavigator,
                    onGenerateRoute: (settings) => MaterialPageRoute(
                      settings: settings,
                      builder: (_) => const Scaffold(body: Text('Home tab')),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    Future<void> pressBack(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    Future<void> open(
      WidgetTester tester,
      NavigatorState navigator,
      Widget page,
    ) async {
      // Done only when the page closes.
      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => page)));
      await tester.pumpAndSettle();
    }

    testWidgets('in a category, Back shows the category list; Back again '
        'closes Settings', (tester) async {
      await pumpShell(tester);
      await open(tester, shellNavigator.currentState!, const SettingsScreen());
      await tester.tap(find.text('App Customization'));
      await tester.pumpAndSettle();
      expect(find.text('Show Subtitles'), findsOneWidget);
      expect(find.text('Live TV'), findsNothing);

      await pressBack(tester);

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Show Subtitles'), findsNothing);
      expect(find.text('Live TV'), findsOneWidget);

      await pressBack(tester);

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('Home tab'), findsOneWidget);
    });

    testWidgets('Back still closes a page in the shell (details)', (
      tester,
    ) async {
      await pumpShell(tester);
      await open(
        tester,
        shellNavigator.currentState!,
        const Scaffold(body: Text('Details page')),
      );

      await pressBack(tester);

      expect(find.text('Details page'), findsNothing);
      expect(find.text('Home tab'), findsOneWidget);
    });

    testWidgets('Back still closes a page over the shell (player)', (
      tester,
    ) async {
      await pumpShell(tester);
      await open(
        tester,
        tester.state<NavigatorState>(find.byType(Navigator).first),
        const Scaffold(body: Text('Player page')),
      );

      await pressBack(tester);

      expect(find.text('Player page'), findsNothing);
      expect(find.text('Home tab'), findsOneWidget);
    });
  });

  // REV-246: the Settings rows showed the arrow cursor.
  testWidgets('every Settings category row: the hand', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final categories = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(InkWell),
    );
    // Identity, Customization, Live TV, Integrations, Info & updates.
    expect(categories, findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      await expectHandOver(tester, categories.at(i));
    }
  });

  testWidgets('the open category row: the selected purple in bold, the others '
      'clear', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [settingsProvider.overrideWith(_FakeSettingsNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rows = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(InkWell),
    );
    Color? fill(int row) => tester
        .widget<Material>(
          find
              .ancestor(of: rows.at(row), matching: find.byType(Material))
              .first,
        )
        .color;
    expect(fill(0), AppTheme.accentSelectedBg);
    expect(fill(1), Colors.transparent);

    FontWeight? labelWeight(int row) => tester
        .widget<Text>(
          find.descendant(of: rows.at(row), matching: find.byType(Text)).first,
        )
        .style
        ?.fontWeight;
    expect(labelWeight(0), FontWeight.bold);
    expect(labelWeight(1), FontWeight.w500);
  });

  for (final hasUpdate in [false, true]) {
    testWidgets('a dot on Info & updates only when a new version is out '
        '(new version: $hasUpdate)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            settingsProvider.overrideWith(_FakeSettingsNotifier.new),
            updatesShownProvider.overrideWithValue(true),
            if (hasUpdate) updateProvider.overrideWith(_UpdateOutNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      bool showsDot(IconData icon) => tester
          .widget<Badge>(
            find.ancestor(of: find.byIcon(icon), matching: find.byType(Badge)),
          )
          .isLabelVisible;
      expect(showsDot(Icons.info_outline), hasUpdate);
      expect(showsDot(Icons.link), isFalse);
    });
  }

  // REV-302: the menus and their choices showed the arrow cursor.
  final l10n = AppLocalizationsEn();
  for (final c in [
    (
      category: l10n.settingsCustomization,
      shown: l10n.settingsEnglish,
      option: l10n.settingsItalian,
    ),
    (
      category: l10n.settingsIntegrations,
      shown: 'Real-Debrid',
      option: 'TorBox',
    ),
  ]) {
    testWidgets('${c.category}: the rows with a list and their choices show '
        'the hand', (tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            settingsProvider.overrideWith(_BothDebridSettingsNotifier.new),
            _fakeRegions,
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(c.category).first);
      await tester.pumpAndSettle();

      final rows = find.byWidgetPredicate(
        (w) => w is SettingsChoiceTile,
        skipOffstage: false,
      );
      expect(rows, findsWidgets);
      for (var i = 0; i < rows.evaluate().length; i++) {
        await tester.ensureVisible(rows.at(i));
        await tester.pumpAndSettle();
        await expectHandOver(tester, rows.at(i));
      }
      await tester.ensureVisible(find.text(c.shown).first);
      await tester.tap(find.text(c.shown).first);
      await tester.pumpAndSettle();
      await expectHandOver(tester, find.text(c.option).last);
    });
  }

  group('settings rows (REV-84b, REV-263)', () {
    late ProviderContainer container;

    Future<void> openCategory(
      WidgetTester tester,
      String category, {
      Locale? locale,
    }) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FocusRing.debugWatchKeys();
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          settingsProvider.overrideWith(_SavingSettingsNotifier.new),
          _fakeRegions,
          liveTvRepositoryProvider.overrideWithValue(_EmptyLiveTvRepository()),
          cinemuseGuideUrlProvider.overrideWithValue(
            'https://example.com/cinemuse.json',
          ),
          cinemusePlaylistUrlProvider.overrideWithValue(
            'https://example.com/cinemuse.m3u',
          ),
          serverAddressesProvider.overrideWith(
            (ref) async => ServerAddresses.fromRows([
              for (final (site, name) in [
                (ServerAddress.movieSite, 'Movie Site'),
                (ServerAddress.animeSite, 'Anime Site'),
                (ServerAddress.animeTorrents, 'Torrent Feed'),
              ])
                {
                  'key': site.key,
                  'address': 'https://${site.name}.example',
                  'display_name': name,
                },
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(category).first);
      await tester.pumpAndSettle();
    }

    bool isRingShownAround(WidgetTester tester, Finder target) => tester
        .widgetList<FocusRing>(
          find.ancestor(of: target, matching: find.byType(FocusRing)),
        )
        .any((ring) => ring.isVisible);

    /// Tab until the focus is inside a [T] (a slider or a text box keeps
    /// its focus inside, so `isFocused` can't see it).
    Future<void> tabInto<T extends Widget>(WidgetTester tester) async {
      bool isIn() =>
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<T>() !=
          null;
      for (var i = 0; i < 40 && !isIn(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(isIn(), isTrue, reason: 'Tab never reached a $T');
    }

    final l10n = AppLocalizationsEn();

    // The pages shared one scroll: a page opened as far down as the last.
    testWidgets(
      'Start in full screen: a click turns it on for this device',
      (tester) async {
        await openCategory(tester, l10n.settingsCustomization);
        expect(container.read(localSettingsProvider).startFullScreen, isFalse);

        await tester.tap(find.text(l10n.settingsStartFullScreen));
        await tester.pumpAndSettle();

        expect(container.read(localSettingsProvider).startFullScreen, isTrue);
        expect(await LocalSettingsNotifier.readStartFullScreen(), isTrue);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets('a phone: no Screen size row, Undo time is the last row', (
      tester,
    ) async {
      PhoneOrientation.setUpForTesting(isPhone: true);
      addTearDown(() => PhoneOrientation.setUpForTesting(isPhone: false));
      await openCategory(tester, l10n.settingsCustomization);

      expect(find.text(l10n.settingsScreenSize), findsNothing);
      expect(
        tester
            .widget<SettingsChoiceTile<Duration>>(
              find.byType(SettingsChoiceTile<Duration>),
            )
            .showDivider,
        isFalse,
      );
    });

    testWidgets('not a phone: the Screen size row is there', (tester) async {
      await openCategory(tester, l10n.settingsCustomization);

      expect(find.text(l10n.settingsScreenSize), findsOneWidget);
    });

    testWidgets(
      'Android: no Start in full screen row',
      (tester) async {
        await openCategory(tester, l10n.settingsCustomization);

        expect(find.text(l10n.settingsStartFullScreen), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('each page opens at its top', (tester) async {
      await openCategory(tester, l10n.settingsCustomization);
      tester.view.physicalSize = const Size(1280, 600);
      await tester.pumpAndSettle();

      ScrollPosition pageScroll(String row) => tester
          .state<ScrollableState>(
            find
                .ancestor(of: find.text(row), matching: find.byType(Scrollable))
                .first,
          )
          .position;
      final customization = pageScroll(l10n.settingsCustomizationDesc);
      expect(customization.maxScrollExtent, greaterThan(200));
      customization.jumpTo(200);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.settingsIntegrations).first);
      await tester.pumpAndSettle();
      expect(pageScroll(l10n.settingsIntegrationsDesc).pixels, 0);
    });

    // REV-77: the streaming country was fixed to Italy.
    testWidgets('Streaming country lists the countries and saves the one '
        'picked', (tester) async {
      await openCategory(tester, l10n.settingsCustomization);
      expect(find.text(l10n.settingsWatchRegion), findsOneWidget);

      await tester.tap(find.text('Italy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('United States').last);
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).watchRegion, 'US');
      expect(find.text('United States'), findsOneWidget);
    });

    testWidgets("the built-in sources are named from the server's list", (
      tester,
    ) async {
      await openCategory(tester, l10n.settingsIntegrations);

      for (final name in ['Movie Site', 'Anime Site', 'Torrent Feed']) {
        expect(find.text(l10n.settingsEnableSource(name)), findsOneWidget);
      }
      expect(
        find.text(l10n.settingsAnimeTorrentsNeedDebrid('Torrent Feed')),
        findsOneWidget,
      );
    });

    testWidgets('in Italian, the built-in sources are described in Italian', (
      tester,
    ) async {
      final it = AppLocalizationsIt();
      await openCategory(
        tester,
        it.settingsIntegrations,
        locale: const Locale('it'),
      );

      expect(find.text(it.settingsAnimeTorrentsDesc), findsOneWidget);
      expect(find.text(it.settingsMovieSiteDesc), findsOneWidget);
      expect(find.textContaining('Native'), findsNothing);
    });

    testWidgets('in Italian, the highest quality "any" is "Qualsiasi"', (
      tester,
    ) async {
      final it = AppLocalizationsIt();
      await openCategory(
        tester,
        it.settingsCustomization,
        locale: const Locale('it'),
      );

      expect(find.text('Qualsiasi'), findsOneWidget);
      expect(find.text('Any'), findsNothing);
    });

    for (final c in [
      (
        category: l10n.settingsCustomization,
        row: l10n.settingsShowSubtitles,
        value: (UserSettings s) => s.showSubtitles,
      ),
      (
        category: l10n.settingsIntegrations,
        row: l10n.settingsEnableSource('Movie Site'),
        value: (UserSettings s) => s.enableMovieSite,
      ),
    ]) {
      testWidgets('${c.row}: a click on the label flips the switch', (
        tester,
      ) async {
        await openCategory(tester, c.category);
        final before = c.value(container.read(settingsProvider));

        await tester.tap(find.text(c.row));
        await tester.pumpAndSettle();

        expect(c.value(container.read(settingsProvider)), !before);
      });

      testWidgets('${c.row}: Tab stops on the row, shows the ring, and '
          'Enter flips the switch', (tester) async {
        await openCategory(tester, c.category);
        final before = c.value(container.read(settingsProvider));

        await tabTo(tester, find.text(c.row));
        await tester.pumpAndSettle();
        expect(isRingShownAround(tester, find.text(c.row)), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(c.value(container.read(settingsProvider)), !before);
        // Still on the row: the switch is not a stop of its own.
        expect(isFocused(find.text(c.row)), isTrue);
      });
    }

    for (final c in [
      (
        name: 'slider',
        category: l10n.settingsCustomization,
        tabIn: (WidgetTester t) => tabInto<Slider>(t),
        target: find.byType(Slider),
      ),
      (
        name: 'text box',
        category: l10n.settingsIdentity,
        // Tab stops on the box; typing waits for Enter.
        tabIn: (WidgetTester t) => tabInto<DpadTextBox>(t),
        target: find.byType(TextField),
      ),
    ]) {
      testWidgets('a ${c.name} reached with Tab shows the ring', (
        tester,
      ) async {
        await openCategory(tester, c.category);

        await c.tabIn(tester);
        await tester.pumpAndSettle();

        final focused = FocusManager.instance.primaryFocus!.context!;
        expect(
          find
              .ancestor(
                of: find.byElementPredicate((e) => e == focused),
                matching: find.byWidgetPredicate(
                  (w) => w is FocusRing && w.isVisible,
                ),
              )
              .evaluate(),
          isNotEmpty,
        );
        expect(c.target, findsWidgets);
      });
    }

    // On the TV some buttons only changed colour: no ring showed where the
    // remote was.
    for (final category in [
      l10n.settingsIdentity,
      l10n.settingsCustomization,
      l10n.settingsLiveTv,
      l10n.settingsIntegrations,
      l10n.settingsInfoUpdates,
    ]) {
      testWidgets('$category: every stop Tab reaches shows the ring', (
        tester,
      ) async {
        await openCategory(tester, category);

        expect(await stopsWithoutRing(tester), isEmpty);
      });
    }
  });
}
