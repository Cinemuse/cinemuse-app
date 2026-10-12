import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/subtitle_slider_overlay.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoController extends Mock implements VideoController {}

class _FakePlayerController extends StateNotifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  _FakePlayerController() : super(const AsyncValue.loading());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// REV-166: the panel takes the keys; Esc cancels it instead of closing the
// player.
void main() {
  const params = PlayerParams('550', 'movie');
  late List<bool> closes;

  Future<void> pumpOverlay(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    closes = [];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerControllerProvider.overrideWith(
            (ref, params) => _FakePlayerController(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SubtitleSliderOverlay(
              type: SliderOverlayType.sync,
              params: params,
              state: CinemaPlayerState(
                controller: _MockVideoController(),
                availableStreams: const [],
                currentStream: null,
                title: 'Test',
              ),
              onClose: closes.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Esc cancels the panel', (tester) async {
    await pumpOverlay(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);

    expect(closes, [false]);
  });

  testWidgets('OK starts focused, so Enter confirms', (tester) async {
    await pumpOverlay(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(closes, [true]);
  });
}
