import 'dart:async';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_tile.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_panel.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/custom_video_controls.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/live_tv/presentation/live_tv_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/live_tv_guide_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

import '../../../helpers/app_font.dart';
import '../../../helpers/focus_helpers.dart';
import '../../../helpers/menu_helpers.dart';

class MockLivePlayer extends Mock implements Player {}

class MockLivePlayerStream extends Mock implements PlayerStream {}

class MockLivePlayerState extends Mock implements PlayerState {}

class MockLiveVideoController extends Mock implements mkv.VideoController {}

class FakeLiveVideoState extends Fake implements mkv.VideoState {
  @override
  bool isFullscreen() => false;
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'FakeLiveVideoState';
}

class FakeLivePlayerController
    extends StateNotifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  FakeLivePlayerController() : super(const AsyncValue.loading());

  @override
  Future<void> seek(Duration position) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The small player on the Live TV tab tunes to the channel it shows.
class TuningLivePlayerController extends FakeLivePlayerController {
  @override
  Future<void> changeChannel(
    Channel channel, {
    bool isFailover = false,
  }) async {}
}

Channel createMockChannel({
  String name = 'Test Channel',
  int lcn = 1,
  StreamQuality quality = StreamQuality.fhd,
}) {
  return Channel(
    lcn: lcn,
    name: name,
    logo: 'https://example.com/logo.png',
    group: 'Entertainment',
    links: [
      StreamLink(url: 'https://example.com/stream.m3u8', quality: quality),
    ],
  );
}

Widget buildTestWidget({
  required Widget child,
  List<Override> overrides = const [],
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      playerControllerProvider.overrideWith(
        (ref, params) => FakeLivePlayerController(),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFont);

  group('ChannelListTile Widget Tests', () {
    testWidgets('renders channel details correctly', (tester) async {
      final channel = createMockChannel(name: 'Rai 1 HD', lcn: 1);
      await tester.pumpWidget(
        buildTestWidget(
          child: ChannelListTile(
            channel: channel,
            isSelected: false,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rai 1 HD'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('FHD'), findsOneWidget);
    });

    testWidgets('renders favorite star when isFavorite is true', (
      tester,
    ) async {
      final channel = createMockChannel();
      await tester.pumpWidget(
        buildTestWidget(
          child: ChannelListTile(
            channel: channel,
            isSelected: false,
            isFavorite: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('triggers onTap on tap and on Enter key when focused', (
      tester,
    ) async {
      int tapCount = 0;
      final channel = createMockChannel();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        buildTestWidget(
          child: ChannelListTile(
            channel: channel,
            isSelected: false,
            focusNode: focusNode,
            autofocus: true,
            onTap: () => tapCount++,
          ),
        ),
      );
      await tester.pump();

      // Tap triggers onTap
      await tester.tap(find.text('Test Channel'));
      await tester.pump();
      expect(tapCount, 1);

      // Enter key triggers onTap
      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tapCount, 2);

      focusNode.dispose();
    });
  });

  group('ChannelListPanel Split vs Overlay Presentation Tests', () {
    testWidgets('right-click the options button: the menu opens at the '
        'pointer (REV-248)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestWidget(
          child: const ChannelListPanel(isOverlay: false),
          overrides: [channelsProvider.overrideWith((ref) => Future.value([]))],
        ),
      );
      await tester.pump();

      final at = tester.getCenter(find.byIcon(Icons.tune_rounded));
      await rightClickAt(tester, at);
      expect(menuItems, findsWidgets);
      expectMenuAt(tester, at);
    });

    testWidgets('renders standard split mode without overlay header', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const ChannelListPanel(isOverlay: false),
          overrides: [channelsProvider.overrideWith((ref) => Future.value([]))],
        ),
      );
      await tester.pump();

      // In split mode, the overlay header with Close button is not present
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('renders overlay mode with header and Close button', (
      tester,
    ) async {
      bool closed = false;
      await tester.pumpWidget(
        buildTestWidget(
          child: ChannelListPanel(
            isOverlay: true,
            onClose: () => closed = true,
          ),
          overrides: [channelsProvider.overrideWith((ref) => Future.value([]))],
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('two chips: channels in number order, no headings '
        '(REV-279)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'live_tv_selected_categories': ['Sport', 'DTT'],
      });
      // Later tests in this file expect no chip.
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      tester.view.physicalSize = const Size(400, 800);
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
                Channel(lcn: 6, name: 'Eurosport', logo: '', group: 'Sport'),
              ]),
            ),
          ],
          child: const ChannelListPanel(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tg24'), findsNothing);
      final tops = [
        for (final name in ['Rai 1', 'Sky Sport', 'Canale 5', 'Eurosport'])
          tester.getTopLeft(find.text(name)).dy,
      ];
      // Each row right under the one before: no heading in between.
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i] - tops[i - 1], 58.0);
      }
    });

    testWidgets('two chips: the drawer reopens on a far-down channel '
        '(REV-279)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'live_tv_selected_categories': ['Sport', 'DTT'],
      });
      // Later tests in this file expect no chip.
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final channels = [
        for (var i = 1; i <= 60; i++)
          Channel(
            lcn: i,
            name: 'Channel $i',
            logo: '',
            group: const ['News', 'DTT', 'Sport'][i % 3],
          ),
      ];
      final container = ProviderContainer(
        overrides: [
          playerControllerProvider.overrideWith(
            (ref, params) => FakeLivePlayerController(),
          ),
          channelsProvider.overrideWith((ref) => Future.value(channels)),
        ],
      );
      addTearDown(container.dispose);
      // The chips were picked earlier; the user is now on channel 59.
      container.listen(filteredChannelsProvider, (_, __) {});
      await container.read(channelsProvider.future);
      await tester.pump();
      container.read(selectedChannelProvider.notifier).select(channels[58]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ChannelListPanel(isOverlay: true, onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Channel 59'), findsOneWidget);
      final row = tester.getRect(find.text('Channel 59'));
      expect(row.top, greaterThanOrEqualTo(0));
      expect(row.bottom, lessThanOrEqualTo(800));
      expect(isFocused(find.text('Channel 59')), isTrue);
    });
  });

  group('D-Pad Navigation Integration', () {
    testWidgets('tapping the playing channel opens the big player (REV-132)', (
      tester,
    ) async {
      final channel = createMockChannel();
      final container = ProviderContainer(
        overrides: [
          channelsProvider.overrideWith((ref) => Future.value([channel])),
        ],
      );
      addTearDown(container.dispose);

      // Set current channel as selected
      container.read(selectedChannelProvider.notifier).select(channel);
      Channel? opened;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ChannelListPanel(onOpenPlayer: (c) => opened = c),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the already selected channel
      await tester.tap(find.text(channel.name));
      await tester.pump();

      expect(container.read(selectedChannelProvider), same(channel));
      expect(opened, same(channel));
    });

    testWidgets(
      'ArrowRight in split mode invokes livePlayerFocusActionProvider',
      (tester) async {
        final channel = createMockChannel();
        bool playerFocused = false;

        final container = ProviderContainer(
          overrides: [
            channelsProvider.overrideWith((ref) => Future.value([channel])),
            livePlayerFocusActionProvider.overrideWith(
              (ref) =>
                  () => playerFocused = true,
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: ChannelListPanel(isOverlay: false)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Focus the channel tile
        final tileFinder = find.byType(ChannelListTile);
        await tester.tap(tileFinder);
        await tester.pump();

        // Send ArrowRight
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        expect(playerFocused, isTrue);
      },
    );

    testWidgets('the menu key on a channel adds it to favourites (REV-134)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([createMockChannel()]),
            ),
          ],
          child: const ChannelListPanel(isOverlay: false),
        ),
      );
      await tester.pumpAndSettle();

      await tabTo(tester, find.text('Test Channel'));
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pump();

      expect(find.text('Added to favorites'), findsOneWidget);
    });

    testWidgets('phone: Right from a channel focuses the small player, '
        'Enter opens the big one (REV-135)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([createMockChannel()]),
            ),
          ],
          // Another tab is active, so the small player shows its
          // placeholder instead of playing.
          child: const LiveTvScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tabTo(tester, find.text('Test Channel'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        isFocused(find.text('Select a channel to start watching')),
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(VideoPlayerScreen), findsOneWidget);
    });

    // REV-132: after tapping the playing channel on a phone, a wider window
    // showed Live TV in a full-window mode with no navbar.
    testWidgets('phone: tap the playing channel, Back, widen: the guide on '
        'the Live TV tab', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // The small player's spinner never stops: no pumpAndSettle.
      Future<void> wait(WidgetTester tester) async {
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      final container = ProviderContainer(
        overrides: [
          playerControllerProvider.overrideWith(
            (ref, params) => TuningLivePlayerController(),
          ),
          channelsProvider.overrideWith(
            (ref) => Future.value([createMockChannel()]),
          ),
          epgDataProvider.overrideWith((ref) => Future.value({})),
          navIndexProvider.overrideWith((ref) => NavTab.liveTv),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            // The app's font and theme: the guide's top bar is measured.
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: LiveTvScreen()),
          ),
        ),
      );
      await wait(tester);

      // The first channel plays by itself; tapping it opens the big player.
      await tester.tap(find.text('Test Channel'));
      await wait(tester);
      expect(find.byType(VideoPlayerScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await wait(tester);
      expect(find.byType(VideoPlayerScreen), findsNothing);

      tester.view.physicalSize = const Size(1280, 800);
      await wait(tester);
      expect(find.byType(LiveTvGuideScreen), findsOneWidget);
      expect(container.read(navIndexProvider), NavTab.liveTv);
    });

    testWidgets('phone: playlist off stops the channel, back on picks the '
        'first one again (REV-271)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      Future<void> wait(WidgetTester tester) async {
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      final first = createMockChannel(name: 'First', lcn: 1);
      final second = createMockChannel(name: 'Second', lcn: 2);
      // The playlist's channels; empty = the playlist is off.
      final shown = StateProvider<List<Channel>>((ref) => [first, second]);
      final container = ProviderContainer(
        overrides: [
          playerControllerProvider.overrideWith(
            (ref, params) => TuningLivePlayerController(),
          ),
          channelsProvider.overrideWith((ref) async => ref.watch(shown)),
          epgDataProvider.overrideWith((ref) => Future.value({})),
          navIndexProvider.overrideWith((ref) => NavTab.liveTv),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: LiveTvScreen()),
          ),
        ),
      );
      await wait(tester);
      container.read(selectedChannelProvider.notifier).select(second);
      await wait(tester);
      expect(find.text('Select a channel to start watching'), findsNothing);

      container.read(shown.notifier).state = [];
      await wait(tester);
      expect(container.read(selectedChannelProvider), isNull);
      expect(find.text('Select a channel to start watching'), findsOneWidget);

      container.read(shown.notifier).state = [first, second];
      await wait(tester);
      expect(container.read(selectedChannelProvider), first);
      expect(find.text('Select a channel to start watching'), findsNothing);
    });

    testWidgets('phone: typing a far channel number scrolls the list to it '
        '(REV-139)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          playerControllerProvider.overrideWith(
            (ref, params) => TuningLivePlayerController(),
          ),
          channelsProvider.overrideWith(
            (ref) async => [
              for (var i = 1; i <= 60; i++)
                createMockChannel(name: 'Channel $i', lcn: i),
            ],
          ),
          epgDataProvider.overrideWith((ref) => Future.value({})),
          navIndexProvider.overrideWith((ref) => NavTab.liveTv),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: LiveTvScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Channel 50'), findsNothing);

      await tabTo(tester, find.text('Channel 1'));
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      // The number tunes by itself after 1.5 s.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(seconds: 1));

      expect(container.read(selectedChannelProvider)?.lcn, 50);
      expect(find.text('Channel 50'), findsOneWidget);
      final row = tester.getRect(find.text('Channel 50'));
      expect(row.top, greaterThanOrEqualTo(0));
      expect(row.bottom, lessThanOrEqualTo(800));
    });

    testWidgets('ArrowLeft in overlay mode invokes onClose', (tester) async {
      final channel = createMockChannel();
      bool overlayClosed = false;

      final container = ProviderContainer(
        overrides: [
          channelsProvider.overrideWith((ref) => Future.value([channel])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ChannelListPanel(
                isOverlay: true,
                onClose: () => overlayClosed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tileFinder = find.byType(ChannelListTile);
      await tester.tap(tileFinder);
      await tester.pump();

      // Send ArrowLeft in overlay mode
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(overlayClosed, isTrue);
    });

    testWidgets('ArrowRight in overlay mode invokes onClose', (tester) async {
      final channel = createMockChannel();
      bool overlayClosed = false;

      final container = ProviderContainer(
        overrides: [
          channelsProvider.overrideWith((ref) => Future.value([channel])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ChannelListPanel(
                isOverlay: true,
                onClose: () => overlayClosed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tileFinder = find.byType(ChannelListTile);
      await tester.tap(tileFinder);
      await tester.pump();

      // Send ArrowRight in overlay mode
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(overlayClosed, isTrue);
    });

    testWidgets('drawer: Up into the search box turns its border accent '
        '(REV-139)', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([createMockChannel()]),
            ),
          ],
          child: ChannelListPanel(isOverlay: true, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // The look is the check here, so read the search box's border.
      Color borderColor() {
        final box = tester.widget<Container>(
          find
              .ancestor(
                of: find.byType(TextField),
                matching: find.byWidgetPredicate(
                  (w) => w is Container && w.decoration is BoxDecoration,
                ),
              )
              .first,
        );
        return ((box.decoration! as BoxDecoration).border! as Border).top.color;
      }

      expect(borderColor(), isNot(AppTheme.accent));
      await tabTo(tester, find.text('Test Channel'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      // The field's focus sits inside it, so isFocused can't see it.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasPrimaryFocus, isTrue);
      expect(borderColor(), AppTheme.accent);
    });

    testWidgets('does not render category filter chips in overlay mode', (
      tester,
    ) async {
      final channel = createMockChannel();

      final container = ProviderContainer(
        overrides: [
          channelsProvider.overrideWith((ref) => Future.value([channel])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ChannelListPanel(isOverlay: true, onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Category filter chips ("All", etc.) are removed from overlay drawer
      expect(find.text('All'), findsNothing);
    });
  });

  group('LiveVideoControls TV UI', () {
    late MockLivePlayer mockPlayer;
    late MockLivePlayerStream mockStream;
    late MockLivePlayerState mockState;
    late MockLiveVideoController mockController;
    late StreamController<bool> playingStreamController;
    late StreamController<Duration> positionStreamController;

    setUp(() {
      mockPlayer = MockLivePlayer();
      mockStream = MockLivePlayerStream();
      mockState = MockLivePlayerState();
      mockController = MockLiveVideoController();
      playingStreamController = StreamController<bool>.broadcast();
      positionStreamController = StreamController<Duration>.broadcast();

      when(() => mockPlayer.stream).thenReturn(mockStream);
      when(() => mockPlayer.state).thenReturn(mockState);
      when(
        () => mockStream.playing,
      ).thenAnswer((_) => playingStreamController.stream);
      when(
        () => mockStream.position,
      ).thenAnswer((_) => positionStreamController.stream);
      when(() => mockStream.buffering).thenAnswer((_) => const Stream.empty());
      when(() => mockState.playing).thenReturn(true);
      when(() => mockState.buffering).thenReturn(false);
      when(() => mockState.position).thenReturn(const Duration(seconds: 100));
      when(() => mockState.duration).thenReturn(const Duration(seconds: 120));
      when(() => mockState.volume).thenReturn(100.0);
      when(() => mockController.player).thenReturn(mockPlayer);
    });

    tearDown(() {
      playingStreamController.close();
      positionStreamController.close();
    });

    CinemaPlayerState createTestPlayerState() {
      return CinemaPlayerState(
        controller: mockController,
        availableStreams: const [],
        currentStream: null,
        title: 'Test Live Channel',
      );
    }

    testWidgets('renders the live TV buttons', (tester) async {
      final channel = createMockChannel();
      final playerState = createTestPlayerState();

      await tester.pumpWidget(
        buildTestWidget(
          child: CustomVideoControls(
            playerState: playerState,
            channel: channel,
            videoState: FakeLiveVideoState(),
            params: const PlayerParams('livetv_session', 'livetv'),
            isLive: true,
            onSettingsPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Live TV buttons: Stop button is present to exit player
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      // No back arrow: the Stop button replaces it
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Test Channel'), findsOneWidget);
      expect(find.text('LIVE'), findsWidgets);
    });

    testWidgets('shows settings only as the tune icon in the bottom row', (
      tester,
    ) async {
      final channel = createMockChannel();
      final playerState = createTestPlayerState();

      await tester.pumpWidget(
        buildTestWidget(
          child: CustomVideoControls(
            playerState: playerState,
            channel: channel,
            videoState: FakeLiveVideoState(),
            params: const PlayerParams('livetv_session', 'livetv'),
            isLive: true,
            onSettingsPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No settings cog in the top bar
      expect(find.byIcon(Icons.settings), findsNothing);
      // Tune icon IS in bottom TV row
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets('a tap runs onTap instead of play/pause (REV-156)', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        buildTestWidget(
          child: CustomVideoControls(
            playerState: createTestPlayerState(),
            channel: createMockChannel(),
            videoState: FakeLiveVideoState(),
            params: const PlayerParams('livetv_session', 'livetv'),
            isLive: true,
            onSettingsPressed: () {},
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty video area, away from the centre play button.
      final box = tester.getRect(find.byType(CustomVideoControls));
      await tester.tapAt(Offset(box.left + 20, box.center.dy));
      // Wait out the double-tap window so the single tap fires.
      await tester.pump(kDoubleTapTimeout);

      expect(taps, 1);
      verifyNever(() => mockPlayer.pause());
    });

    testWidgets('the channel list button opens the drawer (REV-160)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [channelsProvider.overrideWith((ref) => Future.value([]))],
          child: CustomVideoControls(
            playerState: createTestPlayerState(),
            channel: createMockChannel(),
            videoState: FakeLiveVideoState(),
            params: const PlayerParams('livetv_session', 'livetv'),
            isLive: true,
            onSettingsPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.list_rounded), findsOneWidget);
      // Right of the channel buttons.
      expect(
        tester.getCenter(find.byIcon(Icons.list_rounded)).dx,
        greaterThan(tester.getCenter(find.byIcon(Icons.skip_next_rounded)).dx),
      );
      await tester.tap(find.byIcon(Icons.list_rounded));
      await tester.pump(kDoubleTapTimeout);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomVideoControls)),
      );
      expect(container.read(liveTvChannelOverlayProvider), isTrue);
    });

    testWidgets('the channel list button works by keys and picks a channel '
        '(REV-160)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final playing = createMockChannel();
      final other = createMockChannel(name: 'Other Channel', lcn: 2);
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith(
              (ref) => Future.value([playing, other]),
            ),
          ],
          child: CustomVideoControls(
            playerState: createTestPlayerState(),
            channel: playing,
            videoState: FakeLiveVideoState(),
            params: const PlayerParams('livetv_session', 'livetv'),
            isLive: true,
            onSettingsPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomVideoControls)),
      );
      // The big player selects the channel it opens with.
      container.read(selectedChannelProvider.notifier).select(playing);

      await tabTo(tester, find.byIcon(Icons.list_rounded));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(isFocused(find.text('Test Channel')), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(isFocused(find.text('Other Channel')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // The big player plays whatever channel is selected.
      expect(container.read(selectedChannelProvider), same(other));
    });

    testWidgets('the mini-player has no channel list button (REV-160)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: CustomVideoControls(
            playerState: createTestPlayerState(),
            channel: createMockChannel(),
            videoState: FakeLiveVideoState(),
            params: const PlayerParams('livetv_session', 'livetv'),
            isLive: true,
            onSettingsPressed: () {},
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.list_rounded), findsNothing);
    });
  });

  group('Channel Guide Browser & VideoPlayerScreen Navigation Tests', () {
    testWidgets('tapping a channel selects it', (tester) async {
      final channel = createMockChannel(name: 'Canale 5 HD', lcn: 5);

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            channelsProvider.overrideWith((ref) => Future.value([channel])),
          ],
          child: const ChannelListPanel(isOverlay: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Canale 5 HD'));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChannelListPanel)),
      );
      final selectedChannel = container.read(selectedChannelProvider);
      expect(selectedChannel?.uniqueId, equals(channel.uniqueId));
    });

    testWidgets(
      'renders empty state with Manage Playlists button when no channels exist',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            overrides: [
              channelsProvider.overrideWith((ref) => Future.value([])),
            ],
            child: const ChannelListPanel(isOverlay: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.tv_off_rounded), findsOneWidget);
        expect(find.byIcon(Icons.playlist_add_rounded), findsOneWidget);
        expect(find.text('Manage Playlists'), findsOneWidget);
      },
    );

    // REV-20: below 600 px a small player over the channel list, from 600 px
    // the guide.
    for (final (width, isPhone) in const [(599.0, true), (600.0, false)]) {
      testWidgets('${width}px: ${isPhone ? 'small player + list' : 'guide'}', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 800);
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
            // The app's font and theme: the guide's top bar is measured.
            theme: AppTheme.darkTheme,
            // Another tab is active, so the small player shows its
            // placeholder instead of playing.
            child: const LiveTvScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final phoneOnly = isPhone ? findsOneWidget : findsNothing;
        expect(find.text('Select a channel to start watching'), phoneOnly);
        expect(find.byType(ChannelListPanel), phoneOnly);
        expect(
          find.byType(LiveTvGuideScreen),
          isPhone ? findsNothing : findsOneWidget,
        );
      });
    }
  });

  group('Top Navbar to LiveTvScreen Navigation Integration', () {
    testWidgets(
      'pageContentFocusActionsProvider[2] focuses LiveTvGuideScreen from navbar',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final channel = createMockChannel(name: 'Rai 1 HD', lcn: 1);
        final container = ProviderContainer(
          overrides: [
            channelsProvider.overrideWith((ref) => Future.value([channel])),
            epgDataProvider.overrideWith((ref) => Future.value({})),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: LiveTvScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Retrieve registered action for Live TV tab (index 2)
        final actions = container.read(pageContentFocusActionsProvider);
        expect(actions[2], isNotNull);

        // Invoke action (as AppNavbar does on ArrowDown)
        actions[2]!();
        await tester.pumpAndSettle();

        // Focus should be in LiveTvGuideScreen on the "All" tab button
        expect(find.byType(LiveTvGuideScreen), findsOneWidget);
        expect(find.text('All'), findsWidgets);
      },
    );

    testWidgets('ArrowUp on All tab invokes topNavbarFocusActionProvider', (
      tester,
    ) async {
      final channel = createMockChannel(name: 'Rai 1 HD', lcn: 1);
      bool navbarFocused = false;

      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final container = ProviderContainer(
        overrides: [
          channelsProvider.overrideWith((ref) => Future.value([channel])),
          epgDataProvider.overrideWith((ref) => Future.value({})),
        ],
      );
      addTearDown(container.dispose);

      container.read(topNavbarFocusActionProvider.notifier).state = () {
        navbarFocused = true;
      };

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LiveTvGuideScreen(focusNode: focusNode)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Request focus on the All tab
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Send ArrowUp key
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      // Top navbar focus action should have been triggered
      expect(navbarFocused, isTrue);
    });
  });
}
