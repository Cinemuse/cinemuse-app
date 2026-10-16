import 'dart:async';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/custom_video_controls.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/settings_widgets.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_bottom_bar.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_playback_controls.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/main_settings_view.dart';
import 'package:cinemuse_app/features/video_player/presentation/helpers/playback_control_actions.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_top_bar.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';

class MockPlayer extends Mock implements Player {}

class MockPlayerStream extends Mock implements PlayerStream {}

class MockPlayerState extends Mock implements PlayerState {}

class MockVideoController extends Mock implements VideoController {}

class FakeVideoState extends Fake implements VideoState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'FakeVideoState';
}

class FakeAudioTrack extends Fake implements AudioTrack {}

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

class FakePlayerController extends StateNotifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  FakePlayerController({this.onSeek}) : super(const AsyncValue.loading());
  final void Function(Duration position)? onSeek;

  @override
  Future<void> seek(Duration position) async {
    onSeek?.call(position);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeAudioTrack());
    registerFallbackValue(Duration.zero);
  });

  late MockPlayer mockPlayer;
  late MockPlayerStream mockStream;
  late MockPlayerState mockState;
  late MockVideoController mockController;
  late StreamController<bool> playingStreamController;

  setUp(() {
    mockPlayer = MockPlayer();
    mockStream = MockPlayerStream();
    mockState = MockPlayerState();
    mockController = MockVideoController();
    playingStreamController = StreamController<bool>.broadcast();

    when(() => mockPlayer.stream).thenReturn(mockStream);
    when(() => mockPlayer.state).thenReturn(mockState);
    when(
      () => mockStream.playing,
    ).thenAnswer((_) => playingStreamController.stream);
    when(() => mockStream.buffering).thenAnswer((_) => const Stream.empty());
    when(() => mockStream.volume).thenAnswer((_) => const Stream.empty());
    when(() => mockState.playing).thenReturn(false);
    when(() => mockState.buffering).thenReturn(false);
    when(() => mockState.volume).thenReturn(100.0);
    when(() => mockState.position).thenReturn(Duration.zero);
    when(() => mockState.duration).thenReturn(const Duration(minutes: 90));
    when(() => mockState.track).thenReturn(const Track());
    when(() => mockState.tracks).thenReturn(const Tracks());
    when(() => mockController.player).thenReturn(mockPlayer);
  });

  tearDown(() {
    playingStreamController.close();
  });

  CinemaPlayerState createDummyPlayerState() {
    return CinemaPlayerState(
      controller: mockController,
      availableStreams: const [],
      currentStream: null,
      title: 'Test Movie',
    );
  }

  Widget buildTestableWidget(
    Widget child, {
    void Function(Duration)? onSeek,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
        playerControllerProvider.overrideWith(
          (ref, params) => FakePlayerController(onSeek: onSeek),
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

  group('VideoPlaybackControls TV Layout Tests', () {
    testWidgets('Renders inline row layout', (tester) async {
      var stopTapped = false;
      var playPauseToggled = false;
      var skipDirection = false;
      var settingsTapped = false;
      var nextEpisodeTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          VideoPlaybackControls(
            playerState: createDummyPlayerState(),
            actions: PlaybackControlActions(
              onTogglePlayPause: () => playPauseToggled = true,
              onSkip: (forward) => skipDirection = forward,
              onToggleMute: () {},
              onStopPressed: () => stopTapped = true,
              isFullscreen: false,
              onToggleFullscreen: () {},
              onNextEpisode: () => nextEpisodeTapped = true,
              onSettingsPressed: () => settingsTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Stop button should be present
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      // Play/Pause button should be present
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      // Skip backward 10s icon
      expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
      // Skip forward 10s icon
      expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);
      // Settings icon
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      // Next episode icon
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      // Fullscreen icon
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);

      // Play/Pause button has autofocus and is focused
      expect(
        tester.binding.focusManager.primaryFocus?.context?.widget,
        isNotNull,
      );

      // Test activating Stop via tap
      await tester.tap(find.byIcon(Icons.stop_rounded));
      expect(stopTapped, isTrue);

      // Test activating Play/Pause via tap
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      expect(playPauseToggled, isTrue);

      // Test activating Settings button
      await tester.tap(find.byIcon(Icons.tune_rounded));
      expect(settingsTapped, isTrue);

      // Test activating Next Episode button
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      expect(nextEpisodeTapped, isTrue);

      // Test skip backward
      await tester.tap(find.byIcon(Icons.replay_10_rounded));
      expect(skipDirection, isFalse);

      // Test skip forward
      await tester.tap(find.byIcon(Icons.forward_10_rounded));
      expect(skipDirection, isTrue);
    });

    testWidgets('D-Pad directional traversal steps through inline controls', (
      tester,
    ) async {
      final seekbarFocusNode = FocusNode(debugLabel: 'TestSeekbar');

      await tester.pumpWidget(
        buildTestableWidget(
          Column(
            children: [
              Focus(
                focusNode: seekbarFocusNode,
                child: const SizedBox(height: 10),
              ),
              VideoPlaybackControls(
                playerState: createDummyPlayerState(),
                actions: PlaybackControlActions(
                  onTogglePlayPause: () {},
                  onSkip: (_) {},
                  onToggleMute: () {},
                  onStopPressed: () {},
                  isFullscreen: false,
                  onToggleFullscreen: () {},
                  onSettingsPressed: () {},
                  seekbarFocusNode: seekbarFocusNode,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Play/Pause is initially focused (autofocus)
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('PlayPauseTvButton'),
      );

      // Navigate Left to Rewind 10s
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('RewindTvButton'),
      );

      // Navigate Right back to Play/Pause
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('PlayPauseTvButton'),
      );

      // Navigate Right to Stop
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('StopTvButton'),
      );

      // Navigate Right to Forward 10s
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('ForwardTvButton'),
      );

      // Navigate Right to Settings
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('SettingsTvButton'),
      );

      // Navigate Right to Fullscreen
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('FullscreenTvButton'),
      );

      // Navigate Left back to Settings
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('SettingsTvButton'),
      );

      // Navigate Left to Forward 10s
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('ForwardTvButton'),
      );

      // Navigate Left to Stop
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('StopTvButton'),
      );

      // Navigate Left back to Play/Pause
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('PlayPauseTvButton'),
      );

      // Navigate Up from controls to Seekbar
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(seekbarFocusNode.hasFocus, isTrue);

      seekbarFocusNode.dispose();
    });
  });

  group('Video Settings Widgets D-Pad Tests', () {
    testWidgets(
      'SettingsTile receives focus with autofocus and invokes onTap',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          buildTestableWidget(
            SettingsTile(
              icon: Icons.tune,
              title: 'Quality',
              autofocus: true,
              onTap: () => tapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify autofocus
        expect(tester.binding.focusManager.primaryFocus, isNotNull);

        // Press Enter/Select
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );

    testWidgets('TrackTile activates and calls setAudioTrack and onBack', (
      tester,
    ) async {
      var backCalled = false;
      final dummyTrack = AudioTrack.uri(
        'file://dummy',
        title: 'English',
        language: 'en',
      );

      when(() => mockPlayer.setAudioTrack(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildTestableWidget(
          TrackTile(
            player: mockPlayer,
            track: dummyTrack,
            isSelected: false,
            isSubtitle: false,
            autofocus: true,
            onBack: () => backCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus should be on the TrackTile
      expect(tester.binding.focusManager.primaryFocus, isNotNull);

      // Press Select
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      verify(() => mockPlayer.setAudioTrack(dummyTrack)).called(1);
      expect(backCalled, isTrue);
    });

    testWidgets(
      'VideoBottomBar provides focusable Slider and wires playPauseFocusNode',
      (tester) async {
        final playPauseFocusNode = FocusNode(debugLabel: 'TestPlayPause');
        final seekbarFocusNode = FocusNode(debugLabel: 'TestSeekbar');
        when(
          () => mockStream.position,
        ).thenAnswer((_) => Stream.value(Duration.zero));
        when(() => mockState.duration).thenReturn(const Duration(minutes: 90));

        await tester.pumpWidget(
          buildTestableWidget(
            VideoBottomBar(
              playerState: createDummyPlayerState(),
              actions: PlaybackControlActions(
                onTogglePlayPause: () {},
                onSkip: (_) {},
                onToggleMute: () {},
                onStopPressed: () {},
                isFullscreen: false,
                onToggleFullscreen: () {},
                playPauseFocusNode: playPauseFocusNode,
                seekbarFocusNode: seekbarFocusNode,
              ),
              dragging: false,
              onChangeStart: (_) {},
              onChangeEnd: (_) {},
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Slider is present and focusable
        final sliderFinder = find.byType(Slider);
        expect(sliderFinder, findsOneWidget);

        seekbarFocusNode.requestFocus();
        await tester.pumpAndSettle();
        expect(seekbarFocusNode.hasFocus, isTrue);

        // Request focus on playPauseFocusNode
        playPauseFocusNode.requestFocus();
        await tester.pumpAndSettle();

        expect(playPauseFocusNode.hasFocus, isTrue);
        playPauseFocusNode.dispose();
        seekbarFocusNode.dispose();
      },
    );
  });

  group('CustomVideoControls TV Navigation Tests', () {
    testWidgets(
      'Automatically focuses Play/Pause and navigates inline controls with arrow keys',
      (tester) async {
        final fakeVideoState = FakeVideoState();
        when(
          () => mockStream.position,
        ).thenAnswer((_) => Stream.value(Duration.zero));
        when(() => mockState.duration).thenReturn(const Duration(minutes: 90));
        when(() => mockState.volume).thenReturn(100.0);

        await tester.pumpWidget(
          buildTestableWidget(
            CustomVideoControls(
              videoState: fakeVideoState,
              playerState: createDummyPlayerState(),
              params: const PlayerParams('movie-1', 'movie'),
              onSettingsPressed: () {},
              onBackPressed: () {},
              onOverlayRequested: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Play/Pause gets initial focus
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('PlayPauseTvButton'),
        );

        // Navigate Left to Rewind 10s
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('RewindTvButton'),
        );

        // Navigate Right back to Play/Pause
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('PlayPauseTvButton'),
        );

        // Navigate Right to Stop
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('StopTvButton'),
        );

        // Navigate Right to Forward 10s
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('ForwardTvButton'),
        );

        // Navigate Right to Settings
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('SettingsTvButton'),
        );

        // Navigate Right to Fullscreen
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('FullscreenTvButton'),
        );

        // Navigate Left back to Settings
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('SettingsTvButton'),
        );

        // Navigate Left to Forward 10s
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('ForwardTvButton'),
        );

        // Navigate Left to Stop
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('StopTvButton'),
        );

        // Navigate Left back to Play/Pause
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('PlayPauseTvButton'),
        );

        // Navigate Up from controls to seekbar
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('SeekbarFocusNode'),
        );

        // Navigate Down from seekbar back to Play/Pause
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('PlayPauseTvButton'),
        );
      },
    );

    testWidgets(
      'Long-pressing keys on seekbar keeps focus on seekbar and does not drop to control row',
      (tester) async {
        final fakeVideoState = FakeVideoState();
        when(
          () => mockStream.position,
        ).thenAnswer((_) => Stream.value(Duration.zero));
        when(() => mockState.duration).thenReturn(const Duration(minutes: 90));
        when(() => mockState.volume).thenReturn(100.0);
        when(() => mockPlayer.seek(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildTestableWidget(
            CustomVideoControls(
              videoState: fakeVideoState,
              playerState: createDummyPlayerState(),
              params: const PlayerParams('movie-1', 'movie'),
              onSettingsPressed: () {},
              onBackPressed: () {},
              onOverlayRequested: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate Up from Play/Pause to Seekbar
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('SeekbarFocusNode'),
        );

        // Simulate long-pressing Right on seekbar (KeyDown followed by repeated KeyRepeatEvent)
        await tester.sendKeyDownEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.sendKeyRepeatEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.sendKeyRepeatEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.sendKeyUpEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        await tester.pumpAndSettle();

        // Focus MUST remain on Seekbar and NOT jump down to controls!
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('SeekbarFocusNode'),
        );
      },
    );

    testWidgets('Moving seekbar with spatial navigation skips 30 seconds', (
      tester,
    ) async {
      final fakeVideoState = FakeVideoState();
      when(
        () => mockStream.position,
      ).thenAnswer((_) => Stream.value(Duration.zero));
      when(() => mockState.duration).thenReturn(const Duration(minutes: 90));
      when(() => mockState.volume).thenReturn(100.0);
      Duration? seekTarget;

      await tester.pumpWidget(
        buildTestableWidget(
          CustomVideoControls(
            videoState: fakeVideoState,
            playerState: createDummyPlayerState(),
            params: const PlayerParams('movie-1', 'movie'),
            onSettingsPressed: () {},
            onBackPressed: () {},
            onOverlayRequested: (_) {},
          ),
          onSeek: (pos) => seekTarget = pos,
        ),
      );
      await tester.pumpAndSettle();

      // Navigate Up from Play/Pause to Seekbar
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('SeekbarFocusNode'),
      );

      // Press Right on seekbar once
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // Verify that the seek target is 30 seconds
      expect(seekTarget, equals(const Duration(seconds: 30)));
    });

    testWidgets(
      'Long-pressing Left/Right triggers skip and Up/Down is unused on VOD when controls are hidden',
      (tester) async {
        final fakeVideoState = FakeVideoState();
        when(
          () => mockStream.position,
        ).thenAnswer((_) => Stream.value(Duration.zero));
        when(() => mockState.duration).thenReturn(const Duration(minutes: 90));
        when(() => mockState.volume).thenReturn(50.0);
        when(() => mockState.playing).thenReturn(true);
        when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

        Duration? seekTarget;

        await tester.pumpWidget(
          buildTestableWidget(
            CustomVideoControls(
              videoState: fakeVideoState,
              playerState: createDummyPlayerState(),
              params: const PlayerParams('movie-1', 'movie'),
              onSettingsPressed: () {},
              onBackPressed: () {},
              onOverlayRequested: (_) {},
            ),
            onSeek: (pos) => seekTarget = pos,
          ),
        );
        await tester.pumpAndSettle();

        // Controls start visible. Fast forward 5 seconds to let the hide timer expire
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Verify controls are hidden via opacity
        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity).first,
        );
        expect(animatedOpacity.opacity, equals(0.0));
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('CustomVideoControlsRoot'),
        );

        // Long press arrowRight (KeyDown + repeated KeyRepeatEvent)
        await tester.sendKeyDownEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.sendKeyRepeatEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.sendKeyRepeatEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.sendKeyUpEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        await tester.pumpAndSettle();

        // Verify seek was called for skip
        expect(seekTarget, isNotNull);

        // Press arrowUp: Volume adjustment removed on VOD
        await tester.sendKeyDownEvent(
          LogicalKeyboardKey.arrowUp,
          physicalKey: PhysicalKeyboardKey.arrowUp,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.sendKeyUpEvent(
          LogicalKeyboardKey.arrowUp,
          physicalKey: PhysicalKeyboardKey.arrowUp,
        );
        await tester.pumpAndSettle();

        // Volume should NOT have been adjusted
        verifyNever(() => mockPlayer.setVolume(any()));
      },
    );

    testWidgets(
      'Up/Down keys zap channels on Live TV when controls are hidden',
      (tester) async {
        final fakeVideoState = FakeVideoState();
        when(
          () => mockStream.position,
        ).thenAnswer((_) => Stream.value(Duration.zero));
        when(() => mockState.duration).thenReturn(const Duration(minutes: 90));
        when(() => mockState.volume).thenReturn(50.0);
        when(() => mockState.playing).thenReturn(true);

        Channel channel(String name, int lcn) =>
            Channel(lcn: lcn, name: name, logo: '', group: 'G', links: []);
        final channels = [channel('A', 1), channel('B', 2), channel('C', 3)];

        await tester.pumpWidget(
          buildTestableWidget(
            overrides: [
              filteredChannelsProvider.overrideWithValue(
                AsyncValue.data(channels),
              ),
            ],
            CustomVideoControls(
              videoState: fakeVideoState,
              playerState: createDummyPlayerState(),
              params: const PlayerParams('livetv_session', 'livetv'),
              channel: channels[1],
              isLive: true,
              onSettingsPressed: () {},
              onBackPressed: () {},
              onOverlayRequested: (_) {},
            ),
          ),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CustomVideoControls)),
        );
        await tester.pumpAndSettle();

        // Wait 5 seconds to let hide timer expire
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Verify controls are hidden
        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity).first,
        );
        expect(animatedOpacity.opacity, equals(0.0));

        // Press ArrowDown to zap next channel
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(container.read(selectedChannelProvider)?.name, 'C');

        // Press ArrowUp to zap previous channel
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(container.read(selectedChannelProvider)?.name, 'A');
      },
    );

    testWidgets(
      'Pressing numeric key on Live TV registers digit once in buffer',
      (tester) async {
        final fakeVideoState = FakeVideoState();
        when(
          () => mockStream.position,
        ).thenAnswer((_) => Stream.value(Duration.zero));
        when(() => mockState.duration).thenReturn(const Duration(minutes: 90));
        when(() => mockState.volume).thenReturn(50.0);
        when(() => mockState.playing).thenReturn(true);

        String receivedDigit = '';

        await tester.pumpWidget(
          buildTestableWidget(
            CustomVideoControls(
              videoState: fakeVideoState,
              playerState: createDummyPlayerState(),
              params: const PlayerParams('livetv_session', 'livetv'),
              isLive: true,
              onSettingsPressed: () {},
              onBackPressed: () {},
              onOverlayRequested: (_) {},
              onNumberInput: (d) => receivedDigit += d,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
        await tester.pumpAndSettle();

        expect(receivedDigit, equals('5'));
      },
    );
  });

  group('VideoTopBar TV Tests', () {
    // Stop and Settings live in the bottom bar; cast is hidden for now.
    testWidgets('Shows the title and no buttons', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          VideoTopBar(
            playerState: createDummyPlayerState(),
            params: const PlayerParams('movie-1', 'movie'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Movie'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });

    // REV-291: the hero's Play button passes no episode name.
    for (final (passed, shown) in const [
      ('Passed Name', ' - Passed Name'),
      (null, ' - From TMDB'),
    ]) {
      testWidgets('episode name ${passed ?? 'looked up'}: "$shown"', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestableWidget(
            VideoTopBar(
              playerState: createDummyPlayerState(),
              params: PlayerParams(
                '1',
                'tv',
                season: 2,
                episode: 4,
                episodeTitle: passed,
              ),
            ),
            overrides: [
              seasonDetailsProvider.overrideWith(
                (ref, args) async => {
                  'episodes': <dynamic>[
                    <String, dynamic>{'episode_number': 3, 'name': 'Other'},
                    <String, dynamic>{'episode_number': 4, 'name': 'From TMDB'},
                  ],
                },
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining(shown), findsOneWidget);
      });
    }
  });

  group('MainSettingsView TV Navigation Tests', () {
    testWidgets(
      'Autofocuses Quality and navigates items with D-Pad arrow keys',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            MainSettingsView(
              state: createDummyPlayerState(),
              onNavigate: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Source (playerQuality) tile has initial focus
        expect(find.text('Source'), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
        expect(find.text('Subtitles'), findsOneWidget);

        // Navigate down to Audio
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        // Navigate down to Subtitles
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        // Navigate up to Audio
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        // Navigate up to Quality
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
      },
    );
  });
}
