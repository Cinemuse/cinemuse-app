import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:mocktail/mocktail.dart';
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
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/live_tv_guide_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

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
    overrides: [
      playerControllerProvider.overrideWith(
        (ref, params) => FakeLivePlayerController(),
      ),
      ...overrides,
    ],
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
  });

  group('LiveTvViewMode and D-Pad Navigation Integration', () {
    testWidgets(
      'tapping the playing channel keeps the split layout (REV-132)',
      (tester) async {
        final channel = createMockChannel();
        final container = ProviderContainer(
          overrides: [
            channelsProvider.overrideWith((ref) => Future.value([channel])),
          ],
        );
        addTearDown(container.dispose);

        // Set current channel as selected
        container.read(selectedChannelProvider.notifier).select(channel);
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

        // fullWindow hid the navbar on wide screens and showed nothing on
        // phones.
        expect(container.read(liveTvViewModeProvider), LiveTvViewMode.split);
        expect(container.read(selectedChannelProvider), same(channel));
      },
    );

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

    testWidgets(
      'renders channels drawer button in TV row when onOpenChannelGuide is provided',
      (tester) async {
        final channel = createMockChannel();
        final playerState = createTestPlayerState();

        await tester.pumpWidget(
          buildTestWidget(
            overrides: [
              liveTvViewModeProvider.overrideWith(
                (ref) => LiveTvViewMode.fullWindow,
              ),
            ],
            child: CustomVideoControls(
              playerState: playerState,
              channel: channel,
              videoState: FakeLiveVideoState(),
              params: const PlayerParams('livetv_session', 'livetv'),
              isLive: true,
              onSettingsPressed: () {},
              onOpenChannelGuide: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Channel guide button is shown
        expect(find.byIcon(Icons.list_rounded), findsOneWidget);
      },
      // TODO: check the TV layout. Either the guide button was
      // moved or re-iconed (update this test) or the player refactor lost it
      // (real regression). See audit/08-testing.md.
      skip: true,
    );
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
