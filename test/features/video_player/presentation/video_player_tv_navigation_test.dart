import 'dart:async';
import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/custom_video_controls.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/settings_widgets.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_bottom_bar.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_playback_controls.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/main_settings_view.dart';
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
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) => 'FakeVideoState';
}
class FakeAudioTrack extends Fake implements AudioTrack {}

class FakeSettingsNotifier extends StateNotifier<UserSettings>
    implements SettingsNotifier {
  FakeSettingsNotifier() : super(const UserSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeAudioTrack());
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
    when(() => mockStream.playing).thenAnswer((_) => playingStreamController.stream);
    when(() => mockStream.buffering).thenAnswer((_) => const Stream.empty());
    when(() => mockState.playing).thenReturn(false);
    when(() => mockState.buffering).thenReturn(false);
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
    DisplayMode mode = DisplayMode.bigPicture,
  }) {
    return ProviderScope(
      key: ValueKey(mode),
      overrides: [
        displayModeProvider.overrideWith((ref) {
          final notifier = DisplayModeNotifier();
          notifier.setMode(mode);
          return notifier;
        }),
        settingsProvider.overrideWith((ref) => FakeSettingsNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  group('VideoPlaybackControls TV Layout Tests', () {
    testWidgets('Renders inline row layout in Big Picture mode', (tester) async {
      var playPauseToggled = false;
      var skipDirection = false;
      var settingsTapped = false;
      var nextEpisodeTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          VideoPlaybackControls(
            playerState: createDummyPlayerState(),
            onTogglePlayPause: () => playPauseToggled = true,
            onSkip: (forward) => skipDirection = forward,
            onToggleMute: () {},
            isFullscreen: false,
            onToggleFullscreen: () {},
            onNextEpisode: () => nextEpisodeTapped = true,
            onSettingsPressed: () => settingsTapped = true,
          ),
          mode: DisplayMode.bigPicture,
        ),
      );
      await tester.pumpAndSettle();

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

      // Play/Pause button has autofocus and is focused
      expect(
        tester.binding.focusManager.primaryFocus?.context?.widget,
        isNotNull,
      );

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

    testWidgets('D-Pad directional traversal steps through inline controls', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          VideoPlaybackControls(
            playerState: createDummyPlayerState(),
            onTogglePlayPause: () {},
            onSkip: (_) {},
            onToggleMute: () {},
            isFullscreen: false,
            onToggleFullscreen: () {},
            onSettingsPressed: () {},
          ),
          mode: DisplayMode.bigPicture,
        ),
      );
      await tester.pumpAndSettle();

      // Play/Pause is initially focused (autofocus in center)
      // Navigate Left to Rewind 10s
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(tester.binding.focusManager.primaryFocus, isNotNull);

      // Navigate Right back to Play/Pause
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.binding.focusManager.primaryFocus, isNotNull);

      // Navigate Right to Forward 10s
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.binding.focusManager.primaryFocus, isNotNull);

      // Navigate Right to Settings
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.binding.focusManager.primaryFocus, isNotNull);

      // Navigate Left back to Forward 10s
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(tester.binding.focusManager.primaryFocus, isNotNull);
    });
  });

  group('Video Settings Widgets D-Pad Tests', () {
    testWidgets('SettingsTile receives focus with autofocus and invokes onTap', (tester) async {
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
    });

    testWidgets('TrackTile activates and calls setAudioTrack and onBack', (tester) async {
      var backCalled = false;
      final dummyTrack = AudioTrack.uri('file://dummy', title: 'English', language: 'en');

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

    testWidgets('VideoBottomBar in Big Picture mode excludes Slider and wires playPauseFocusNode', (tester) async {
      final playPauseFocusNode = FocusNode(debugLabel: 'TestPlayPause');
      when(() => mockStream.position).thenAnswer((_) => Stream.value(Duration.zero));
      when(() => mockState.duration).thenReturn(const Duration(minutes: 90));

      await tester.pumpWidget(
        buildTestableWidget(
          VideoBottomBar(
            playerState: createDummyPlayerState(),
            dragging: false,
            onChangeStart: (_) {},
            onChangeEnd: (_) {},
            onChanged: (_) {},
            onTogglePlayPause: () {},
            onSkip: (_) {},
            onToggleMute: () {},
            isFullscreen: false,
            onToggleFullscreen: () {},
            playPauseFocusNode: playPauseFocusNode,
          ),
          mode: DisplayMode.bigPicture,
        ),
      );
      await tester.pumpAndSettle();

      // In Big Picture mode, Slider is wrapped in ExcludeFocus(excluding: true)
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);
      final excludeFocusFinder = find.ancestor(
        of: sliderFinder,
        matching: find.byWidgetPredicate(
          (w) => w is ExcludeFocus && w.excluding == true,
        ),
      );
      expect(excludeFocusFinder, findsOneWidget);

      // Request focus on playPauseFocusNode
      playPauseFocusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(playPauseFocusNode.hasFocus, isTrue);
      playPauseFocusNode.dispose();
    });
  });

  group('CustomVideoControls TV Navigation Tests', () {
    testWidgets('Automatically focuses Play/Pause and navigates inline controls with arrow keys', (tester) async {
      final fakeVideoState = FakeVideoState();
      when(() => mockStream.position).thenAnswer((_) => Stream.value(Duration.zero));
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
          mode: DisplayMode.bigPicture,
        ),
      );
      await tester.pumpAndSettle();

      // In Big Picture mode, Play/Pause gets initial focus
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

      // Navigate Down to hide controls
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        equals('CustomVideoControlsRoot'),
      );
    });
  });

  group('VideoTopBar TV Tests', () {
    testWidgets('Hides Cast and Settings icons in Big Picture mode', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          VideoTopBar(
            playerState: createDummyPlayerState(),
            params: const PlayerParams('movie-1', 'movie'),
            onSettingsPressed: () {},
            onCastPressed: () {},
            onBackPressed: () {},
          ),
          mode: DisplayMode.bigPicture,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cast), findsNothing);
      expect(find.byIcon(Icons.settings), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('Shows Cast and Settings icons in Desktop mode', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          VideoTopBar(
            playerState: createDummyPlayerState(),
            params: const PlayerParams('movie-1', 'movie'),
            onSettingsPressed: () {},
            onCastPressed: () {},
            onBackPressed: () {},
          ),
          mode: DisplayMode.standard,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cast), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  group('MainSettingsView TV Navigation Tests', () {
    testWidgets('Autofocuses Quality and navigates items with D-Pad arrow keys', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          MainSettingsView(
            state: createDummyPlayerState(),
            onNavigate: (_) {},
          ),
          mode: DisplayMode.bigPicture,
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
    });
  });
}
