import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_tile.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_panel.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/live_video_controls.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class MockLivePlayer extends Mock implements Player {}
class MockLivePlayerStream extends Mock implements PlayerStream {}
class MockLivePlayerState extends Mock implements PlayerState {}
class MockLiveVideoController extends Mock implements mkv.VideoController {}
class FakeLiveVideoState extends Fake implements mkv.VideoState {
  @override
  bool isFullscreen() => false;
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) => 'FakeLiveVideoState';
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
  TestWidgetsFlutterBinding.ensureInitialized();

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

    testWidgets('renders favorite star when isFavorite is true', (tester) async {
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

    testWidgets('triggers onTap on tap and on Enter key when focused', (tester) async {
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
    testWidgets('renders standard split mode without overlay header', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const ChannelListPanel(isOverlay: false),
          overrides: [
            channelsProvider.overrideWith((ref) => Future.value([])),
          ],
        ),
      );
      await tester.pump();

      // In split mode, the overlay header with Close button is not present
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('renders overlay mode with header and Close button', (tester) async {
      bool closed = false;
      await tester.pumpWidget(
        buildTestWidget(
          child: ChannelListPanel(
            isOverlay: true,
            onClose: () => closed = true,
          ),
          overrides: [
            channelsProvider.overrideWith((ref) => Future.value([])),
          ],
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(closed, isTrue);
    });
  });

  group('LiveTvViewMode and D-Pad Navigation Integration', () {
    testWidgets('tapping already selected channel in split mode expands to fullWindow', (tester) async {
      final channel = createMockChannel();
      final container = ProviderContainer(
        overrides: [
          channelsProvider.overrideWith((ref) => Future.value([channel])),
        ],
      );
      addTearDown(container.dispose);

      // Set current channel as selected
      container.read(selectedChannelProvider.notifier).state = channel;
      expect(container.read(liveTvViewModeProvider), LiveTvViewMode.split);

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

      // Tap the already selected channel
      await tester.tap(find.text(channel.name));
      await tester.pump();

      // Should have switched to fullWindow
      expect(container.read(liveTvViewModeProvider), LiveTvViewMode.fullWindow);
    });

    testWidgets('ArrowLeft in split mode invokes tvRailFocusActionProvider', (tester) async {
      final channel = createMockChannel();
      bool railFocused = false;

      final container = ProviderContainer(
        overrides: [
          channelsProvider.overrideWith((ref) => Future.value([channel])),
          tvRailFocusActionProvider.overrideWith((ref) => () => railFocused = true),
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
      expect(tileFinder, findsOneWidget);

      await tester.tap(tileFinder);
      await tester.pump();

      // Send ArrowLeft
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(railFocused, isTrue);
    });

    testWidgets('ArrowRight in split mode invokes livePlayerFocusActionProvider', (tester) async {
      final channel = createMockChannel();
      bool playerFocused = false;

      final container = ProviderContainer(
        overrides: [
          channelsProvider.overrideWith((ref) => Future.value([channel])),
          livePlayerFocusActionProvider.overrideWith((ref) => () => playerFocused = true),
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
  });

  group('LiveVideoControls TV and Big Picture UI', () {
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
      when(() => mockStream.playing).thenAnswer((_) => playingStreamController.stream);
      when(() => mockStream.position).thenAnswer((_) => positionStreamController.stream);
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

    testWidgets('renders Big Picture centered TV buttons when isBigPicture is true', (tester) async {
      final channel = createMockChannel();
      final playerState = createTestPlayerState();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            isBigPictureProvider.overrideWith((ref) => true),
          ],
          child: LiveVideoControls(
            playerState: playerState,
            channel: channel,
            videoState: FakeLiveVideoState(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Big Picture buttons
      expect(find.widgetWithIcon(DpadFocusable, Icons.replay_10_rounded), findsOneWidget);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.widgetWithIcon(DpadFocusable, Icons.forward_10_rounded), findsOneWidget);
      expect(find.widgetWithIcon(DpadFocusable, Icons.sensors_rounded), findsOneWidget);
      expect(find.widgetWithIcon(DpadFocusable, Icons.aspect_ratio_rounded), findsOneWidget);
      expect(find.widgetWithIcon(DpadFocusable, Icons.fullscreen_rounded), findsOneWidget);
    });

    testWidgets('hides settings in top bar and shows tune icon in TV row when isBigPicture is true', (tester) async {
      final channel = createMockChannel();
      final playerState = createTestPlayerState();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            isBigPictureProvider.overrideWith((ref) => true),
          ],
          child: LiveVideoControls(
            playerState: playerState,
            channel: channel,
            videoState: FakeLiveVideoState(),
            onSettingsPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Settings cog is NOT in top bar
      expect(find.byIcon(Icons.settings), findsNothing);
      // Tune icon IS in bottom TV row
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets('renders channels drawer button in TV row when in fullWindow', (tester) async {
      final channel = createMockChannel();
      final playerState = createTestPlayerState();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            isBigPictureProvider.overrideWith((ref) => true),
            liveTvViewModeProvider.overrideWith((ref) => LiveTvViewMode.fullWindow),
          ],
          child: LiveVideoControls(
            playerState: playerState,
            channel: channel,
            videoState: FakeLiveVideoState(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In fullWindow, sidebar/channels button is shown
      expect(find.byIcon(Icons.view_sidebar_outlined), findsOneWidget);
    });
  });
}
