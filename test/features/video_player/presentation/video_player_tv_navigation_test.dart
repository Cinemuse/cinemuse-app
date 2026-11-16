import 'dart:async';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/custom_video_controls.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_settings_panel.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/track_tile.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_bottom_bar.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_playback_controls.dart';
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
import 'package:flutter_riverpod/misc.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class MockPlayer extends Mock implements Player {}

class MockPlayerStream extends Mock implements PlayerStream {}

class MockPlayerState extends Mock implements PlayerState {}

class MockVideoController extends Mock implements VideoController {}

class FakeVideoState extends Fake implements VideoState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'FakeVideoState';
}

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

class FakePlayerController extends Notifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  FakePlayerController({this.onSeek});

  @override
  AsyncValue<CinemaPlayerState> build() => const AsyncValue.loading();
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
      retry: noProviderRetry,
      overrides: [
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
        playerControllerProvider.overrideWith2(
          (_) => FakePlayerController(onSeek: onSeek),
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
      final settingsOpened = <PlayerSettingsKind>[];
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
              onSettingsPressed: settingsOpened.add,
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
      // REV-333: one Settings button became Source and Tracks.
      expect(find.byTooltip('Source'), findsOneWidget);
      expect(find.byTooltip('Audio & subtitles'), findsOneWidget);
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

      // Each opens its own panel.
      await tester.tap(find.byTooltip('Source'));
      await tester.tap(find.byTooltip('Audio & subtitles'));
      expect(settingsOpened, [
        PlayerSettingsKind.source,
        PlayerSettingsKind.tracks,
      ]);

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
                  onSettingsPressed: (_) async {},
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

      // Navigate Right to Source, then Tracks
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('SourceTvButton'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('TracksTvButton'),
      );

      // Navigate Right to Fullscreen
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('FullscreenTvButton'),
      );

      // Navigate Left back to Tracks, then Source
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('TracksTvButton'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('SourceTvButton'),
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
    testWidgets('TrackTile picks its track with Select', (tester) async {
      var picks = 0;
      final dummyTrack = AudioTrack.uri(
        'file://dummy',
        title: 'English',
        language: 'en',
      );

      await tester.pumpWidget(
        buildTestableWidget(
          TrackTile(
            track: dummyTrack,
            isSelected: false,
            autofocus: true,
            onPick: () => picks++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus should be on the TrackTile
      expect(tester.binding.focusManager.primaryFocus, isNotNull);

      // Press Select
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(picks, 1);
    });

    testWidgets(
      'TrackTile shows the language, then CC, then the title (REV-281)',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            TrackTile(
              track: SubtitleTrack('3', 'Commentary', 'eng'),
              kind: SubtitleKind.cc,
              isSelected: false,
              onPick: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('English · CC · Commentary'), findsOneWidget);
      },
    );

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
              onSettingsPressed: (_) async {},
              onBackPressed: () {},
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

        // Navigate Right to Source, then Tracks
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('SourceTvButton'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('TracksTvButton'),
        );

        // Navigate Right to Fullscreen
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('FullscreenTvButton'),
        );

        // Navigate Left back to Tracks, then Source
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('TracksTvButton'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          equals('SourceTvButton'),
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
              onSettingsPressed: (_) async {},
              onBackPressed: () {},
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
            onSettingsPressed: (_) async {},
            onBackPressed: () {},
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
              onSettingsPressed: (_) async {},
              onBackPressed: () {},
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
              onSettingsPressed: (_) async {},
              onBackPressed: () {},
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

    // Same as on the channel list: the number keypad counts, and the channel
    // changes 1.5 s after the last digit.
    testWidgets('typing a channel number switches to it, the number keypad '
        'too', (tester) async {
      when(
        () => mockStream.position,
      ).thenAnswer((_) => Stream.value(Duration.zero));
      when(() => mockState.playing).thenReturn(true);
      Channel channel(String name, int lcn) =>
          Channel(lcn: lcn, name: name, logo: '', group: 'G', links: []);
      final channels = [channel('One', 1), channel('Twelve', 12)];

      await tester.pumpWidget(
        buildTestableWidget(
          overrides: [channelsProvider.overrideWith((ref) async => channels)],
          CustomVideoControls(
            videoState: FakeVideoState(),
            playerState: createDummyPlayerState(),
            params: const PlayerParams('livetv_session', 'livetv'),
            channel: channels[0],
            isLive: true,
            onSettingsPressed: (_) async {},
            onBackPressed: () {},
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomVideoControls)),
      );
      await container.read(channelsProvider.future);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.numpad1);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      expect(find.text('12'), findsOneWidget);
      expect(container.read(selectedChannelProvider), isNull);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(container.read(selectedChannelProvider)?.name, 'Twelve');
      expect(find.text('12'), findsNothing);
      await tester.pumpAndSettle();
    });

    // REV-333: the panel covers the bar, so the controls step aside.
    testWidgets('a settings panel hides the controls; once it closes the keys '
        'go back to the player', (tester) async {
      when(
        () => mockStream.position,
      ).thenAnswer((_) => Stream.value(Duration.zero));
      when(() => mockState.duration).thenReturn(const Duration(minutes: 90));
      when(() => mockState.volume).thenReturn(100.0);
      final panel = Completer<void>();
      final opened = <PlayerSettingsKind>[];

      await tester.pumpWidget(
        buildTestableWidget(
          CustomVideoControls(
            videoState: FakeVideoState(),
            playerState: createDummyPlayerState(),
            params: const PlayerParams('movie-1', 'movie'),
            onSettingsPressed: (kind) {
              opened.add(kind);
              return panel.future;
            },
            onBackPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Audio & subtitles'));
      await tester.pumpAndSettle();
      expect(opened, [PlayerSettingsKind.tracks]);
      final controls = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(controls.opacity, 0.0);

      panel.complete();
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        'CustomVideoControlsRoot',
      );
    });
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
              seasonEpisodesProvider.overrideWith(
                (ref, args) async => EpisodeItem.listFromTmdbSeason({
                  'episodes': <dynamic>[
                    <String, dynamic>{'episode_number': 3, 'name': 'Other'},
                    <String, dynamic>{'episode_number': 4, 'name': 'From TMDB'},
                  ],
                }, args.seasonNumber),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining(shown), findsOneWidget);
      });
    }
  });
}
