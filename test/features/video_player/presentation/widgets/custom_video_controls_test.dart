import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/custom_video_controls.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/vod_seekbar.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockPlayerState extends Mock implements PlayerState {}

class _MockVideoController extends Mock implements VideoController {}

class _FakeVideoState extends Fake implements VideoState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'FakeVideoState';
}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

class _FakePlayerController extends StateNotifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  _FakePlayerController(this.seeks) : super(const AsyncValue.loading());
  final List<Duration> seeks;

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final touchLayout = TargetPlatformVariant.only(TargetPlatform.android);
  late _MockPlayer player;
  late List<Duration> seeks;
  late int backPresses;

  setUp(() {
    player = _MockPlayer();
    final stream = _MockPlayerStream();
    final state = _MockPlayerState();
    when(() => player.stream).thenReturn(stream);
    when(() => player.state).thenReturn(state);
    when(() => stream.playing).thenAnswer((_) => const Stream.empty());
    when(() => stream.buffering).thenAnswer((_) => const Stream.empty());
    when(() => stream.volume).thenAnswer((_) => const Stream.empty());
    when(() => stream.position).thenAnswer((_) => const Stream.empty());
    // Playing: only then do the controls fade out.
    when(() => state.playing).thenReturn(true);
    when(() => state.buffering).thenReturn(false);
    when(() => state.volume).thenReturn(100.0);
    when(() => state.position).thenReturn(Duration.zero);
    when(() => state.duration).thenReturn(const Duration(minutes: 90));
    when(() => state.track).thenReturn(const Track());
    when(() => state.tracks).thenReturn(const Tracks());
    seeks = [];
    backPresses = 0;
  });

  Future<void> pumpControls(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _MockVideoController();
    when(() => controller.player).thenReturn(player);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          playerControllerProvider.overrideWith(
            (ref, params) => _FakePlayerController(seeks),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomVideoControls(
              videoState: _FakeVideoState(),
              playerState: CinemaPlayerState(
                controller: controller,
                availableStreams: const [],
                currentStream: null,
                title: 'Test Movie',
              ),
              params: const PlayerParams('movie-1', 'movie'),
              onSettingsPressed: () {},
              onBackPressed: () => backPresses++,
              onOverlayRequested: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps once and waits out the double-tap window.
  Future<void> tapAndSettle(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  // Taps on the controls only work while they show.
  final stop = find.byTooltip('Stop').hitTestable();

  group('touch layout (REV-157)', () {
    testWidgets('controls faded out: a tap where the seekbar was brings them '
        'back and does not seek', (tester) async {
      await pumpControls(tester);
      final seekbar = tester.getCenter(find.byType(VodSeekbar));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(stop, findsNothing);

      await tapAndSettle(tester, seekbar);

      expect(seeks, isEmpty);
      expect(stop, findsOneWidget);
    }, variant: touchLayout);

    testWidgets('controls faded out: a tap where Stop was brings them back '
        'and the player stays open', (tester) async {
      await pumpControls(tester);
      final stopButton = tester.getCenter(stop);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(stop, findsNothing);

      await tapAndSettle(tester, stopButton);

      expect(backPresses, 0);
      expect(stop, findsOneWidget);
    }, variant: touchLayout);

    testWidgets('controls showing: the seekbar seeks and Stop closes', (
      tester,
    ) async {
      await pumpControls(tester);

      await tapAndSettle(tester, tester.getCenter(find.byType(VodSeekbar)));
      expect(seeks, isNotEmpty);

      await tapAndSettle(tester, tester.getCenter(stop));
      expect(backPresses, 1);
    }, variant: touchLayout);
  });
}
