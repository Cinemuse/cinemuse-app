import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/application/minute_clock_provider.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/live_tv_guide_screen.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_channel_column.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_details_banner.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_program_block.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_program_row.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_timeline_grid.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_time_ruler.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';

import '../../../helpers/focus_helpers.dart';
import 'package:cinemuse_app/core/application/settable_notifier.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

/// The guide's minute clock, moved by the test.
class _FakeMinuteClock extends MinuteClockNotifier {
  _FakeMinuteClock(this._start);

  final DateTime _start;

  @override
  DateTime build() {
    // Kept for the whole test: the test moves this one object, and a
    // disposed clock can't be moved any more.
    ref.keepAlive();
    return _start;
  }

  void set(DateTime time) => state = time;
}

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
    retry: noProviderRetry,
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
          child: EpgDetailsBanner(channel: channel, program: program),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rai 1 HD'), findsWidgets);
      expect(find.text('TG1 Sera'), findsOneWidget);
      expect(find.text(program.timeRange), findsOneWidget);
      expect(find.text(program.description!), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('the star works with a click, and the arrows never stop on '
        'the banner', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: EpgDetailsBanner(
            channel: createMockChannel(),
            program: createMockProgram(),
            onToggleFavorite: () => toggled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(isFocused(find.byIcon(Icons.star_outline_rounded)), isFalse);

      await tester.tap(find.byTooltip('Add to favorites'));
      await tester.pump();
      expect(toggled, isTrue);
    });
  });

  group('The guide under the mouse', () {
    Future<TestGesture> mouseOver(WidgetTester tester, Finder target) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(target));
      await tester.pump();
      return mouse;
    }

    for (final (name, selected, fill) in [
      (
        'the channel playing: the selected purple, under the mouse too',
        'Rai 1 HD',
        AppTheme.accentSelectedBg,
      ),
      (
        'another channel under the mouse: the faint purple',
        'Rai 2 HD',
        AppTheme.accentHoverBg,
      ),
    ]) {
      testWidgets(name, (tester) async {
        final hovered = createMockChannel();
        await tester.pumpWidget(
          buildTestWidget(
            child: EpgChannelColumn(
              channels: [hovered],
              selectedChannel: createMockChannel(name: selected),
              rowHeight: 80,
              columnWidth: 240,
            ),
          ),
        );
        await tester.pump();
        await mouseOver(tester, find.text('Rai 1 HD'));

        // One frame after the mouse arrives: a fade would still show the old
        // fill.
        final row = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Rai 1 HD'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect((row.decoration! as BoxDecoration).color, fill);
      });
    }

    testWidgets('a programme: its purple comes at once, with no fade', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([createMockChannel()]),
            ),
            epgDataProvider.overrideWith(
              (ref) => Future.value({
                'rai 1 hd': [createMockProgram()],
              }),
            ),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();
      final block = find.descendant(
        of: find.byType(EpgProgramBlock),
        matching: find.text('TG1 Sera'),
      );
      await mouseOver(tester, block);

      final box = tester.widget<Container>(
        find.ancestor(of: block, matching: find.byType(Container)).first,
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        AppTheme.accent.withValues(alpha: 0.28),
      );
    });

    testWidgets('Jump to Live: the faint purple', (tester) async {
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
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await mouseOver(tester, find.text('Jump to Live'));

      final fills = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('Jump to Live'),
              matching: find.byType(Container),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.color);
      expect(fills.first, AppTheme.accentHoverBg);
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
            // The real ones read the Supabase URL from `.env`.
            cinemuseGuideUrlProvider.overrideWithValue(
              'https://example.com/epg',
            ),
            cinemusePlaylistUrlProvider.overrideWithValue(
              'https://example.com/cinemuse.m3u',
            ),
            // Nothing failed: the channels above skip the real loads.
            playlistFailuresProvider.overrideWithValue(const {}),
            guideFailuresProvider.overrideWithValue(const {}),
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
          isFocused(find.text('Playlists & EPGs'));
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
      expect(isFocused(find.text('Playlists & EPGs')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Free-to-air channels'), findsOneWidget);
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
            cinemuseGuideUrlProvider.overrideWithValue(
              'https://example.com/epg',
            ),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppBottomSheet)).width, 600);
    });

    testWidgets('banner star and channel long-press save the favourites '
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
      // Found by the number the guide sends (EpgParser.numberKey).
      (const Channel(lcn: 7, name: 'La Sette', logo: ''), 'lcn:7'),
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
      container.read(channelSearchQueryProvider.notifier).set('Sky Sport');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Sky Sport'), findsOneWidget);
      expect(find.text('Rai 1 HD'), findsNothing);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Rai 1 HD'), findsOneWidget);
      expect(find.byTooltip('Close'), findsNothing);

      var searches = 0;
      container.listen(channelSearchQueryProvider, (_, _) => searches++);
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

    testWidgets('a focused channel whose playlist goes off leaves the banner '
        '(REV-271)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final kept = createMockChannel(lcn: 1, name: 'Kept Channel');
      final gone = createMockChannel(lcn: 2, name: 'Gone Channel');
      // The channels of the playlists that are on.
      final shown =
          NotifierProvider<SettableNotifier<List<Channel>>, List<Channel>>(
            () => SettableNotifier([kept, gone]),
          );
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith((ref) async => ref.watch(shown)),
            epgDataProvider.overrideWith(
              (ref) => Future.value({
                'kept channel': [createMockProgram(name: 'Kept Show')],
                'gone channel': [createMockProgram(name: 'Gone Show')],
              }),
            ),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tabTo(tester, find.text('Gone Show'));
      // Banner + program block.
      expect(find.text('Gone Show'), findsNWidgets(2));

      ProviderScope.containerOf(
        tester.element(find.byType(LiveTvGuideScreen)),
      ).read(shown.notifier).state = [
        kept,
      ];
      await tester.pumpAndSettle();
      expect(find.text('Gone Channel'), findsNothing);
      expect(find.text('Gone Show'), findsNothing);
    });

    testWidgets('two same-name programs in a row: → changes the banner '
        'times (REV-139)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      // Later programs: the one on air now shows in the banner anyway.
      final first = createMockProgram(
        name: 'News',
        startTime: now.add(const Duration(minutes: 30)),
        endTime: now.add(const Duration(minutes: 90)),
      );
      final second = createMockProgram(
        name: 'News',
        startTime: now.add(const Duration(minutes: 90)),
        endTime: now.add(const Duration(minutes: 150)),
      );
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([createMockChannel()]),
            ),
            epgDataProvider.overrideWith(
              (ref) => Future.value({
                'rai 1 hd': [createMockProgram(name: 'On Air'), first, second],
              }),
            ),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();
      Finder bannerText(String text) => find.descendant(
        of: find.byType(EpgDetailsBanner),
        matching: find.text(text),
      );

      await tabTo(tester, find.text('On Air').last);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(bannerText(first.timeRange), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(bannerText(second.timeRange), findsOneWidget);
      expect(bannerText(first.timeRange), findsNothing);
    });

    testWidgets('overlapping programs: the later one starts where the '
        'earlier one ends, and the row fits', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      // The guide starts the film while the news still runs for 70 minutes.
      final news = createMockProgram(
        name: 'News',
        startTime: now.subtract(const Duration(minutes: 15)),
        endTime: now.add(const Duration(minutes: 60)),
      );
      final film = createMockProgram(
        name: 'Film',
        startTime: now.subtract(const Duration(minutes: 10)),
        endTime: now.add(const Duration(minutes: 120)),
      );
      final inside = createMockProgram(
        name: 'Inside',
        startTime: now.add(const Duration(minutes: 70)),
        endTime: now.add(const Duration(minutes: 100)),
      );
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([createMockChannel()]),
            ),
            epgDataProvider.overrideWith(
              (ref) => Future.value({
                'rai 1 hd': [news, film, inside],
              }),
            ),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final filmBlock = tester.widget<EpgProgramBlock>(
        find.ancestor(
          of: find.text('Film'),
          matching: find.byType(EpgProgramBlock),
        ),
      );
      // One hour, from the news' end: 300 px at the default 300 px per hour.
      expect(filmBlock.width, 300);
      // Entirely inside the film's hour: nothing left to draw.
      expect(find.text('Inside'), findsNothing);
    });

    testWidgets('the banner moves on when the focused program ends, but '
        'stays on a later program (REV-278)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      DateTime at(int minutes) => now.add(Duration(minutes: minutes));
      final clock = _FakeMinuteClock(now);
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            minuteClockProvider.overrideWith(() => clock),
            channelsProvider.overrideWith(
              (ref) => Future.value([createMockChannel()]),
            ),
            epgDataProvider.overrideWith(
              (ref) => Future.value({
                'rai 1 hd': [
                  createMockProgram(
                    name: 'Ending Show',
                    startTime: at(-15),
                    endTime: at(5),
                  ),
                  createMockProgram(
                    name: 'Next Show',
                    startTime: at(5),
                    endTime: at(60),
                  ),
                  createMockProgram(
                    name: 'Later Show',
                    startTime: at(60),
                    endTime: at(120),
                  ),
                ],
              }),
            ),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();
      Finder inBanner(String text) => find.descendant(
        of: find.byType(EpgDetailsBanner),
        matching: find.text(text),
      );

      await tabTo(tester, find.text('Ending Show').last);
      expect(inBanner('Ending Show'), findsOneWidget);
      clock.set(at(6));
      await tester.pumpAndSettle();
      expect(inBanner('Next Show'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(inBanner('Later Show'), findsOneWidget);
      clock.set(at(30));
      await tester.pumpAndSettle();
      expect(inBanner('Later Show'), findsOneWidget);
    });

    testWidgets('two categories: the guide rows are in number order '
        '(REV-279)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'live_tv_selected_categories': ['Sport', 'DTT'],
      });
      // Later tests in this file expect no category.
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value(const [
                Channel(lcn: 1, name: 'Rai 1', logo: '', group: 'DTT'),
                Channel(lcn: 3, name: 'Sky Sport', logo: '', group: 'Sport'),
                Channel(lcn: 4, name: 'Tg24', logo: '', group: 'News'),
                Channel(lcn: 5, name: 'Canale 5', logo: '', group: 'DTT'),
              ]),
            ),
            epgDataProvider.overrideWith((ref) => Future.value({})),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tg24'), findsNothing);
      double top(String name) => tester.getTopLeft(find.text(name).last).dy;
      expect(top('Rai 1'), lessThan(top('Sky Sport')));
      expect(top('Sky Sport'), lessThan(top('Canale 5')));
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

    testWidgets('a row scrolled far off throws its focus nodes away', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([
                for (var i = 1; i <= 60; i++)
                  createMockChannel(lcn: i, name: 'Channel $i'),
              ]),
            ),
            epgDataProvider.overrideWith(
              (ref) => Future.value({
                'channel 1': [createMockProgram(name: 'First Show')],
              }),
            ),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();
      final node = tester
          .widget<EpgProgramBlock>(find.byType(EpgProgramBlock))
          .focusNode!;

      await tester.dragUntilVisible(
        find.text('Channel 60'),
        find.byType(EpgChannelColumn),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('First Show'), findsNothing);
      expect(
        () => ChangeNotifier.debugAssertNotDisposed(node),
        throwsFlutterError,
      );
    });

    testWidgets('far down the list, → from a channel focuses its program', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([
                for (var i = 1; i <= 60; i++)
                  createMockChannel(lcn: i, name: 'Channel $i'),
              ]),
            ),
            epgDataProvider.overrideWith(
              (ref) => Future.value({
                'channel 50': [createMockProgram(name: 'Evening Film')],
              }),
            ),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();
      final tile = find.descendant(
        of: find.byType(EpgChannelColumn),
        matching: find.text('Channel 50'),
      );
      await tester.dragUntilVisible(
        tile,
        find.byType(EpgChannelColumn),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      Focus.of(tester.element(tile)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(isFocused(find.text('Evening Film')), isTrue);
    });

    group('a long list', () {
      final column = find.byType(EpgChannelColumn);
      Finder tile(int n) =>
          find.descendant(of: column, matching: find.text('Channel $n'));
      double listOffset(WidgetTester tester) => tester
          .state<ScrollableState>(
            find.descendant(of: column, matching: find.byType(Scrollable)),
          )
          .position
          .pixels;

      Future<ProviderContainer> pumpLongGuide(WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          buildTestWidget(
            overrides: [
              channelsProvider.overrideWith(
                (ref) => Future.value([
                  for (var i = 1; i <= 60; i++)
                    createMockChannel(lcn: i, name: 'Channel $i'),
                ]),
              ),
              epgDataProvider.overrideWith((ref) => Future.value({})),
            ],
            child: const LiveTvGuideScreen(),
          ),
        );
        await tester.pumpAndSettle();
        return ProviderScope.containerOf(
          tester.element(find.byType(LiveTvGuideScreen)),
        );
      }

      Future<void> focusChannel40(WidgetTester tester) async {
        await tester.dragUntilVisible(tile(40), column, const Offset(0, -300));
        await tester.pumpAndSettle();
        Focus.of(tester.element(tile(40))).requestFocus();
        await tester.pumpAndSettle();
      }

      Future<void> downFromTopBar(WidgetTester tester) async {
        Focus.of(
          tester.element(find.byIcon(Icons.grid_view_rounded)),
        ).requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }

      testWidgets('a held Down that runs ahead of the scrolling brings the '
          'row in at the bottom edge, not thrown to the top', (tester) async {
        await pumpLongGuide(tester);
        Focus.of(tester.element(tile(1))).requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        // Faster than the screen redraws: rows not built yet are reached.
        for (var i = 0; i < 25; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        }
        await tester.pumpAndSettle();

        final row = FocusManager.instance.primaryFocus!.context!;
        expect(listOffset(tester), greaterThan(0));
        expect(
          tester.getCenter(find.byElementPredicate((e) => e == row)).dy,
          greaterThan(tester.getCenter(column).dy),
        );
      });

      testWidgets('scrolled back to the top: Down from the top bar lands on '
          'the first channel, not back down on the one left', (tester) async {
        await pumpLongGuide(tester);
        await focusChannel40(tester);
        await tester.drag(column, const Offset(0, 5000));
        await tester.pumpAndSettle();
        expect(listOffset(tester), 0);
        expect(tile(40), findsNothing);

        await downFromTopBar(tester);

        expect(isFocused(tile(1)), isTrue);
        expect(listOffset(tester), 0);
      });

      testWidgets('scrolled partway: Down from the top bar lands on the top '
          'channel on screen and the guide stays still', (tester) async {
        await pumpLongGuide(tester);
        await focusChannel40(tester);
        await tester.drag(column, const Offset(0, 1200));
        await tester.pumpAndSettle();
        expect(tile(40), findsNothing);
        final offset = listOffset(tester);
        expect(offset, greaterThan(0));

        await downFromTopBar(tester);

        expect(listOffset(tester), offset);
        final focused = FocusManager.instance.primaryFocus!.context!;
        final focusedTop = tester.getTopLeft(
          find.byElementPredicate((e) => e == focused),
        );
        // The highest row clear of the top edge by the focus margin (24):
        // no other row starts between it and that margin.
        final listTop = tester.getTopLeft(column).dy;
        expect(focusedTop.dy, greaterThanOrEqualTo(listTop + 24 - 0.5));
        expect(focusedTop.dy, lessThan(listTop + 24 + 64));
      });

      testWidgets('a search, then cleared: Down from the top bar lands on '
          'the first channel, not on the old row number', (tester) async {
        final container = await pumpLongGuide(tester);
        await focusChannel40(tester);

        container.read(channelSearchQueryProvider.notifier).set('Channel 5');
        await tester.pumpAndSettle();
        container.read(channelSearchQueryProvider.notifier).set('');
        await tester.pumpAndSettle();
        expect(tile(40), findsNothing);
        final offset = listOffset(tester);

        await downFromTopBar(tester);

        expect(listOffset(tester), offset);
        expect(isFocused(tile(40)), isFalse);
        expect(isFocused(tile(1)), offset == 0 ? isTrue : isFalse);
      });

      testWidgets('the channel left is still on screen: Down from the top '
          'bar goes back to it', (tester) async {
        await pumpLongGuide(tester);
        await focusChannel40(tester);

        await downFromTopBar(tester);

        expect(isFocused(tile(40)), isTrue);
      });

      group('Page up and Page down', () {
        /// The whole rows the programs' area shows, measured once something
        /// has the focus (the details banner above then takes its place).
        int rowsOnScreen(WidgetTester tester) {
          final programs = tester
              .stateList<ScrollableState>(
                find.ancestor(
                  of: find.byType(EpgProgramRow).first,
                  matching: find.byType(Scrollable),
                ),
              )
              .firstWhere((s) => s.position.axis == Axis.vertical);
          return (programs.position.viewportDimension / 64).floor();
        }

        Future<void> focusChannel1(WidgetTester tester) async {
          Focus.of(tester.element(tile(1))).requestFocus();
          await tester.pumpAndSettle();
        }

        Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();
        }

        /// The channel of the guide row the focus is in.
        String focusedRowChannel() {
          final row = FocusManager.instance.primaryFocus!.context!
              .findAncestorWidgetOfExactType<EpgProgramRow>()!;
          return row.channel.name;
        }

        testWidgets('on a channel: one screen of channels down, then back '
            'up', (tester) async {
          await pumpLongGuide(tester);
          await focusChannel1(tester);
          final rows = rowsOnScreen(tester);
          expect(rows, greaterThan(1));

          await press(tester, LogicalKeyboardKey.pageDown);
          expect(isFocused(tile(1 + rows)), isTrue);
          expect(listOffset(tester), greaterThan(0));

          await press(tester, LogicalKeyboardKey.pageUp);
          expect(isFocused(tile(1)), isTrue);
        });

        testWidgets('on a program: the same, staying in the programs', (
          tester,
        ) async {
          await pumpLongGuide(tester);
          await focusChannel1(tester);
          await press(tester, LogicalKeyboardKey.arrowRight);
          expect(focusedRowChannel(), 'Channel 1');
          final rows = rowsOnScreen(tester);

          await press(tester, LogicalKeyboardKey.pageDown);
          expect(focusedRowChannel(), 'Channel ${1 + rows}');

          await press(tester, LogicalKeyboardKey.pageUp);
          expect(focusedRowChannel(), 'Channel 1');
        });

        testWidgets('a held key turns one page only', (tester) async {
          await pumpLongGuide(tester);
          await focusChannel1(tester);
          final rows = rowsOnScreen(tester);

          await tester.sendKeyDownEvent(LogicalKeyboardKey.pageDown);
          for (var i = 0; i < 10; i++) {
            await tester.sendKeyRepeatEvent(LogicalKeyboardKey.pageDown);
          }
          await tester.sendKeyUpEvent(LogicalKeyboardKey.pageDown);
          await tester.pumpAndSettle();

          expect(isFocused(tile(1 + rows)), isTrue);
        });

        testWidgets('the ends: Page up on the first channel stays there, '
            'Page down near the end lands on the last', (tester) async {
          await pumpLongGuide(tester);
          await focusChannel1(tester);
          await press(tester, LogicalKeyboardKey.pageUp);
          expect(isFocused(tile(1)), isTrue);

          for (var i = 0; i < 10; i++) {
            await press(tester, LogicalKeyboardKey.pageDown);
          }
          expect(isFocused(tile(60)), isTrue);
        });
      });
    });

    testWidgets('left open overnight: the guide moves on to the morning and '
        'back to the live line', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final evening = DateTime(2026, 10, 24, 22, 30);
      final morning = DateTime(2026, 10, 25, 10, 45);
      final clock = _FakeMinuteClock(evening);
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            minuteClockProvider.overrideWith(() => clock),
            channelsProvider.overrideWith(
              (ref) => Future.value([createMockChannel()]),
            ),
            epgDataProvider.overrideWith(
              (ref) => Future.value({
                'rai 1 hd': [
                  createMockProgram(
                    name: 'Late News',
                    startTime: DateTime(2026, 10, 24, 22),
                    endTime: DateTime(2026, 10, 24, 23),
                  ),
                  createMockProgram(
                    name: 'Morning Show',
                    startTime: DateTime(2026, 10, 25, 10, 15),
                    endTime: DateTime(2026, 10, 25, 11, 5),
                  ),
                ],
              }),
            ),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Late News'), findsOneWidget);

      clock.set(morning);
      await tester.pumpAndSettle();

      final show = tester.getRect(find.text('Morning Show'));
      expect(show.left, lessThan(1280));
      expect(show.right, greaterThan(200));
    });

    testWidgets('Favorites with no favourites says how to add one', (
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
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();

      expect(
        find.text(AppLocalizationsEn().liveTvNoFavoritesHint),
        findsOneWidget,
      );
    });
  });

  // The guide's layers, top to bottom: the top row, the guide. Up and Down
  // move one layer; the banner is never a stop.
  group('LiveTvGuideScreen arrows', () {
    final now = DateTime.now();
    DateTime at(int minutes) => now.add(Duration(minutes: minutes));
    EpgProgram program(String name, int from, int to) =>
        EpgProgram(name: name, startTime: at(from), endTime: at(to));

    Future<void> pumpGuide(
      WidgetTester tester, {
      Map<String, List<EpgProgram>> epg = const {},
      List<String> pickedCategories = const [],
    }) async {
      SharedPreferences.setMockInitialValues({
        if (pickedCategories.isNotEmpty)
          'live_tv_selected_categories': pickedCategories,
      });
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value(const [
                Channel(lcn: 1, name: 'Ch A', logo: '', group: 'News'),
                Channel(lcn: 2, name: 'Ch B', logo: '', group: 'News'),
                Channel(lcn: 3, name: 'Ch C', logo: '', group: 'Sport'),
              ]),
            ),
            epgDataProvider.overrideWith((ref) => Future.value(epg)),
            playlistFailuresProvider.overrideWithValue(const {}),
            guideFailuresProvider.overrideWithValue(const {}),
          ],
          child: const LiveTvGuideScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    Future<void> focus(WidgetTester tester, Finder target) async {
      Focus.of(tester.element(target)).requestFocus();
      await tester.pumpAndSettle();
    }

    Finder channel(String name) => find.descendant(
      of: find.byType(EpgChannelColumn),
      matching: find.text(name),
    );
    final allTab = find.byIcon(Icons.grid_view_rounded);

    testWidgets('Down: top row, then the guide; Up comes back to the start '
        'of the row', (tester) async {
      await pumpGuide(tester, pickedCategories: ['Sport']);

      await focus(tester, find.text('Recents'));
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(isFocused(channel('Ch C')), isTrue);

      await press(tester, LogicalKeyboardKey.arrowUp);
      // The row's start, not what happens to be above the channel.
      expect(isFocused(find.byType(TextField)), isTrue);
    });

    testWidgets('the options button is lit while a category is picked', (
      tester,
    ) async {
      Color? iconColor() =>
          tester.widget<Icon>(find.byIcon(Icons.tune_rounded)).color;

      await pumpGuide(tester, pickedCategories: ['Sport']);
      expect(iconColor(), Colors.white);

      await ProviderScope.containerOf(
        tester.element(find.byType(LiveTvGuideScreen)),
      ).read(channelFilterProvider.notifier).clear();
      await tester.pumpAndSettle();
      expect(iconColor(), Colors.white70);
    });

    testWidgets('Down from the top row lands on the channel of the row the '
        'focus was on, never on a program; Up from the first row reaches '
        'the search box', (tester) async {
      await pumpGuide(
        tester,
        epg: {
          'ch a': [program('A now', -20, 40)],
          'ch b': [program('First', -20, 40), program('Second', 40, 100)],
        },
      );

      await focus(tester, channel('Ch B'));
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(isFocused(find.text('Second')), isTrue);

      // Straight up to the top row (a click), from the second row.
      await focus(tester, allTab);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(isFocused(channel('Ch B')), isTrue);

      // Up from the first row's program.
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(isFocused(find.text('A now')), isTrue);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(isFocused(find.byType(TextField)), isTrue);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(isFocused(channel('Ch A')), isTrue);

      // → is the way into the programs.
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(isFocused(find.text('A now')), isTrue);
    });

    testWidgets('the rows stop at their ends', (tester) async {
      await pumpGuide(tester);

      await focus(tester, find.byIcon(Icons.tune_rounded));
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(isFocused(find.byIcon(Icons.tune_rounded)), isTrue);
    });

    testWidgets('the search box is a stop in the top row: Left from "All" '
        'lands on it with no keyboard, Right goes back, Left stays', (
      tester,
    ) async {
      await pumpGuide(tester);
      final searchBox = find.byType(TextField);

      await focus(tester, allTab);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(isFocused(searchBox), isTrue);
      expect(tester.testTextInput.isVisible, isFalse);

      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(isFocused(searchBox), isTrue);

      // With text in the box too: the arrows don't move inside it.
      ProviderScope.containerOf(
        tester.element(find.byType(LiveTvGuideScreen)),
      ).read(channelSearchQueryProvider.notifier).set('Ch');
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(isFocused(allTab), isTrue);
    });

    testWidgets('→ from a channel lands on the program on air now, not the '
        'one at the left edge', (tester) async {
      await pumpGuide(
        tester,
        epg: {
          // The guide opens with 40 minutes of the past in view.
          'ch a': [program('Old news', -60, -20), program('On now', -20, 40)],
        },
      );

      await focus(tester, channel('Ch A'));
      await press(tester, LogicalKeyboardKey.arrowRight);

      expect(isFocused(find.text('On now')), isTrue);
    });

    testWidgets('Up and Down keep the time picked with Left and Right', (
      tester,
    ) async {
      await pumpGuide(
        tester,
        epg: {
          'ch a': [program('A now', -20, 60), program('A film', 60, 120)],
          // Long: its middle is hours after the film starts.
          'ch b': [program('B long', -30, 600)],
          'ch c': [
            program('C before', -30, 50),
            program('C at', 50, 90),
            program('C late', 90, 700),
          ],
        },
      );

      await focus(tester, channel('Ch A'));
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(isFocused(find.text('A film')), isTrue);

      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(isFocused(find.text('B long')), isTrue);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(isFocused(find.text('C at')), isTrue);

      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(isFocused(find.text('A film')), isTrue);
    });

    testWidgets('a move changes the banner but redraws no row or channel '
        'list: the guide lagged on every arrow', (tester) async {
      await pumpGuide(
        tester,
        epg: {
          'ch a': [program('A now', -20, 40)],
          'ch b': [program('B now', -90, 60)],
        },
      );
      List<Widget> drawn() => [
        ...tester.widgetList(find.byType(EpgProgramRow)),
        tester.widget(find.byType(EpgChannelColumn)),
      ];
      Finder inBanner(String text) => find.descendant(
        of: find.byType(EpgDetailsBanner),
        matching: find.text(text),
      );

      await focus(tester, channel('Ch A'));
      await press(tester, LogicalKeyboardKey.arrowRight);
      final before = drawn();

      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(isFocused(find.text('B now')), isTrue);
      expect(inBanner('B now'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(isFocused(channel('Ch B')), isTrue);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(inBanner('A now'), findsOneWidget);

      final after = drawn();
      expect(after.length, before.length);
      for (var i = 0; i < before.length; i++) {
        expect(identical(after[i], before[i]), isTrue);
      }
    });
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
            cinemuseGuideUrlProvider.overrideWithValue(
              'https://example.com/epg',
            ),
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

  testWidgets('the day on the time bar is in the app language', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        locale: const Locale('it'),
        child: EpgTimeRuler(
          // Midnight on a Monday falls in this window.
          windowStart: DateTime(2026, 11, 1, 23),
          totalWidth: 600,
          pixelsPerHour: 300,
          totalHours: 2,
        ),
      ),
    );

    expect(find.textContaining('LUN'), findsOneWidget);
    expect(find.textContaining('MON'), findsNothing);
  });
}
