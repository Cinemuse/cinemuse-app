import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/cast_remote_view.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';

class _MockVideoController extends Mock implements VideoController {}

class _FakePlayerController extends StateNotifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  _FakePlayerController(this.seeks) : super(const AsyncValue.loading());
  final List<Duration> seeks;

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// REV-168: the cast seekbar must not flood the Chromecast with seeks.
void main() {
  const params = PlayerParams('550', 'movie');
  late List<Duration> seeks;

  Future<void> pumpView(WidgetTester tester, {required Duration at}) async {
    seeks = [];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerControllerProvider.overrideWith(
            (ref, params) => _FakePlayerController(seeks),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CastRemoteView(
            playerState: CinemaPlayerState(
              controller: _MockVideoController(),
              availableStreams: const [],
              currentStream: null,
              title: 'Test',
              isCasting: true,
              remotePosition: at,
              remoteDuration: const Duration(minutes: 100),
            ),
            params: params,
            onBackPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a drag sends one seek, on release', (tester) async {
    await pumpView(tester, at: const Duration(minutes: 10));

    await tester.drag(find.byType(Slider), const Offset(150, 0));
    await tester.pumpAndSettle();

    expect(seeks, hasLength(1));
    expect(seeks.single, greaterThan(const Duration(minutes: 10)));
  });

  testWidgets('-10 s near the start seeks to 0, not below', (tester) async {
    await pumpView(tester, at: const Duration(seconds: 4));

    await tester.tap(find.byIcon(Icons.replay_10));
    await tester.pump();

    expect(seeks, [Duration.zero]);
  });
}
