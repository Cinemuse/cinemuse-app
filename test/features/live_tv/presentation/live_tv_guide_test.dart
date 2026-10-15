import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/custom_epg_url_notifier.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/live_tv_guide_screen.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_details_banner.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_timeline_grid.dart';

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
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
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
}
