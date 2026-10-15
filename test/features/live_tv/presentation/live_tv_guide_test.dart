import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:cinemuse_app/features/live_tv/application/custom_epg_url_notifier.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/live_tv_guide_screen.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_details_banner.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_timeline_grid.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';

import '../../../helpers/focus_helpers.dart';

Channel createMockChannel({int lcn = 1, String name = 'Rai 1 HD'}) {
  return Channel(lcn: lcn, name: name, logo: 'rai1.png', group: 'National');
}

EpgProgram createMockProgram({
  String name = 'TG1 Sera',
  DateTime? startTime,
  DateTime? endTime,
  String? description,
}) {
  final now = DateTime.now();
  return EpgProgram(
    name: name,
    startTime: startTime ?? now.subtract(const Duration(minutes: 15)),
    endTime: endTime ?? now.add(const Duration(minutes: 30)),
    description:
        description ??
        'Telegiornale delle ore 20:00 con le principali notizie.',
  );
}

Widget buildTestWidget({
  required Widget child,
  List<Override> overrides = const [],
  Locale? locale,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('EpgDetailsBanner Widget Tests', () {
    testWidgets('renders channel name, program title, time and synopsis', (
      tester,
    ) async {
      final channel = createMockChannel();
      final program = createMockProgram();

      await tester.pumpWidget(
        buildTestWidget(
          child: EpgDetailsBanner(
            channel: channel,
            program: program,
            onWatch: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rai 1 HD'), findsWidgets);
      expect(find.text('TG1 Sera'), findsOneWidget);
      expect(find.text(program.timeRange), findsOneWidget);
      expect(find.text(program.description!), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('triggers onWatch when Watch Channel button is tapped', (
      tester,
    ) async {
      final channel = createMockChannel();
      final program = createMockProgram();
      var watched = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: EpgDetailsBanner(
            channel: channel,
            program: program,
            onWatch: () => watched = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Watch Channel'));
      await tester.pump();

      expect(watched, isTrue);
    });
  });

  group('LiveTvGuideScreen Integration Tests', () {
    testWidgets('renders full timeline grid with channels and search bar', (
      tester,
    ) async {
      final channel1 = createMockChannel(lcn: 1, name: 'Rai 1 HD');
      final channel2 = createMockChannel(lcn: 2, name: 'Rai 2 HD');
      final program1 = createMockProgram(name: 'TG1 Sera');
      final program2 = createMockProgram(name: 'TG2 Notte');

      final epgMap = {
        'rai 1 hd': [program1],
        'rai 2 hd': [program2],
      };

      Channel? selectedChannel;

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([channel1, channel2]),
            ),
            epgDataProvider.overrideWith((ref) => Future.value(epgMap)),
          ],
          child: LiveTvGuideScreen(
            onChannelSelected: (ch) => selectedChannel = ch,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top search bar and filters
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Jump to Live'), findsOneWidget);
      expect(find.text('All'), findsWidgets);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Recents'), findsOneWidget);

      // Grid channels
      expect(find.byType(EpgTimelineGrid), findsOneWidget);
      expect(find.text('Rai 1 HD'), findsWidgets);
      expect(find.text('Rai 2 HD'), findsWidgets);

      // Program blocks
      expect(find.text('TG1 Sera'), findsWidgets);
      expect(find.text('TG2 Notte'), findsWidgets);

      // Tapping channel1 in the guide invokes onChannelSelected
      await tester.tap(find.text('Rai 1 HD').last);
      await tester.pump();

      expect(selectedChannel?.name, equals('Rai 1 HD'));
    });

    testWidgets('the options sheet and its switch work with keys (REV-134)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([createMockChannel()]),
            ),
            epgDataProvider.overrideWith((ref) => Future.value({})),
            // The real one reads the Supabase URL from `.env`.
            defaultEpgUrlProvider.overrideWithValue('https://example.com/epg'),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tabTo(tester, find.byIcon(Icons.tune_rounded));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Filter Channels'), findsOneWidget);

      // Up from the list reaches the Categories / Playlists switch.
      bool onSwitch() =>
          isFocused(find.text('Categories')) ||
          isFocused(find.text('Playlists'));
      for (var i = 0; i < 5 && !onSwitch(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
      }
      expect(onSwitch(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(isFocused(find.text('Categories')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(isFocused(find.text('Playlists')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Custom Playlists'), findsOneWidget);
    });

    // REV-20: on a wide window the options sheet is as wide as the phone
    // layout (600 px), not the whole window.
    testWidgets('wide window: the options sheet is 600 px wide', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([createMockChannel()]),
            ),
            epgDataProvider.overrideWith((ref) => Future.value({})),
            defaultEpgUrlProvider.overrideWithValue('https://example.com/epg'),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppBottomSheet)).width, 600);
    });

    testWidgets('banner star, channel long-press and chips save the choices '
        '(REV-122)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final rai = Channel(lcn: 1, name: 'Rai 1 HD', logo: '', group: 'DTT');
      final sky = Channel(lcn: 2, name: 'Sky Sport', logo: '', group: 'Sport');
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith((ref) => Future.value([rai, sky])),
            epgDataProvider.overrideWith((ref) => Future.value({})),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LiveTvGuideScreen)),
      );
      container.read(selectedChannelProvider.notifier).select(rai);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();

      // The banner's star.
      await tester.tap(find.byTooltip('Add to favorites'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);

      // A long press on a channel in the grid adds it, a second removes it.
      await tester.longPress(find.text('Sky Sport'));
      await tester.pumpAndSettle();
      expect(prefs.getStringList('live_tv_favorites'), [
        rai.uniqueId,
        sky.uniqueId,
      ]);
      await tester.longPress(find.text('Sky Sport'));
      await tester.pumpAndSettle();
      expect(prefs.getStringList('live_tv_favorites'), [rai.uniqueId]);

      // The chips: two selected, then "All" = none.
      await tester.tap(find.text('Sport'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DTT'));
      await tester.pumpAndSettle();
      expect(
        prefs.getStringList('live_tv_selected_categories'),
        unorderedEquals(['Sport', 'DTT']),
      );
      // The tab and the first chip are both "All": the chip is below.
      await tester.tap(find.text('All').last);
      await tester.pumpAndSettle();
      expect(prefs.getStringList('live_tv_selected_categories'), isNull);
    });

    // REV-128: the grid finds a channel's programs the way the banner does.
    for (final (channel, epgKey) in [
      (
        const Channel(lcn: 0, name: 'Rai Uno', logo: '', epgId: 'Rai1.it'),
        'Rai1.it',
      ),
      (
        const Channel(lcn: 0, name: 'Sky Italia News', logo: ''),
        'sky italia news',
      ),
      (const Channel(lcn: 0, name: 'Rai 2 HD', logo: ''), 'rai2'),
      (const Channel(lcn: 7, name: 'La Sette', logo: ''), 'la7'),
    ]) {
      testWidgets('${channel.name}: the banner\'s program is in the guide row, '
          '→ lands on it (REV-128)', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          buildTestWidget(
            overrides: [
              channelsProvider.overrideWith((ref) => Future.value([channel])),
              epgDataProvider.overrideWith(
                (ref) => Future.value({
                  epgKey: [createMockProgram(name: 'On Air')],
                }),
              ),
            ],
            child: const LiveTvGuideScreen(),
          ),
        );
        await tester.pumpAndSettle();
        ProviderScope.containerOf(
          tester.element(find.byType(LiveTvGuideScreen)),
        ).read(selectedChannelProvider.notifier).select(channel);
        await tester.pumpAndSettle();

        // Banner + program block.
        expect(find.text('On Air'), findsNWidgets(2));
        expect(find.text('No program information available'), findsNothing);

        await tabTo(tester, find.text(channel.name));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(isFocused(find.text('On Air')), isTrue);
      });
    }

    testWidgets('a search set elsewhere shows in the box with ×, × clears it, '
        'typing filters once (REV-129)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([
                createMockChannel(lcn: 1, name: 'Rai 1 HD'),
                createMockChannel(lcn: 2, name: 'Sky Sport'),
              ]),
            ),
            epgDataProvider.overrideWith((ref) => Future.value({})),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LiveTvGuideScreen)),
      );

      // A sport card on Home sets the search.
      container.read(channelSearchQueryProvider.notifier).state = 'Sky Sport';
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Sky Sport'), findsOneWidget);
      expect(find.text('Rai 1 HD'), findsNothing);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Rai 1 HD'), findsOneWidget);
      expect(find.byTooltip('Close'), findsNothing);

      var searches = 0;
      container.listen(channelSearchQueryProvider, (_, __) => searches++);
      for (final text in ['R', 'Ra', 'Rai']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(searches, 0);
      expect(find.text('Sky Sport'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(searches, 1);
      expect(find.text('Sky Sport'), findsNothing);
    });

    testWidgets('renders empty state when channel list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith((ref) => Future.value([])),
            epgDataProvider.overrideWith((ref) => Future.value({})),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No channels found'), findsOneWidget);
      expect(find.text('Manage Playlists'), findsOneWidget);
    });

    testWidgets(
      'virtualizes channel list and program rows with ListView.builder',
      (tester) async {
        final channels = List.generate(
          30,
          (i) => createMockChannel(lcn: i + 1, name: 'Channel ${i + 1}'),
        );

        await tester.pumpWidget(
          buildTestWidget(
            overrides: [
              channelsProvider.overrideWith((ref) => Future.value(channels)),
              epgDataProvider.overrideWith((ref) => Future.value({})),
            ],
            child: const LiveTvGuideScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // First few channels are rendered
        expect(find.text('Channel 1'), findsWidgets);
        expect(find.text('Channel 2'), findsWidgets);

        // Distant channel 30 is virtualized (not in widget tree until scrolled)
        expect(find.text('Channel 30'), findsNothing);
      },
    );
  });

  // REV-253: the guide's filter button and the banner star have tooltips in
  // the app's language; the star's follows its state.
  for (final (locale, l10n) in [
    (const Locale('en'), AppLocalizationsEn()),
    (const Locale('it'), AppLocalizationsIt()),
  ]) {
    testWidgets('filter button tooltip in ${locale.languageCode}', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        buildTestWidget(
          locale: locale,
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([createMockChannel()]),
            ),
            epgDataProvider.overrideWith((ref) => Future.value({})),
            defaultEpgUrlProvider.overrideWithValue('https://example.com/epg'),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.liveTvFilterAndPlaylists), findsOneWidget);
    });

    for (final isFavorite in [false, true]) {
      testWidgets('banner star tooltip in ${locale.languageCode}, '
          'favourite: $isFavorite', (tester) async {
        // A desktop window: the test font is wider than the app's.
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          buildTestWidget(
            locale: locale,
            child: EpgDetailsBanner(
              channel: createMockChannel(),
              program: createMockProgram(),
              onWatch: () {},
              isFavorite: isFavorite,
              onToggleFavorite: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byTooltip(
            isFavorite
                ? l10n.liveTvRemoveFromFavorites
                : l10n.liveTvAddToFavorites,
          ),
          findsOneWidget,
        );
      });
    }
  }
}
