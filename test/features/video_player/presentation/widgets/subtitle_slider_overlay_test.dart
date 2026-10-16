import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
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

import '../../../../helpers/app_font.dart';
import '../../../../helpers/focus_helpers.dart';

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

  setUpAll(loadAppFont);

  Future<void> pumpOverlay(
    WidgetTester tester, {
    SliderOverlayType type = SliderOverlayType.sync,
    Locale? locale,
    ThemeData? theme,
  }) async {
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
          locale: locale,
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SubtitleSliderOverlay(
              type: type,
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

  // REV-282: â†‘ / â†“ changed the slider's value like â† / â†’, so the keyboard
  // could never leave it.
  for (final type in const [
    SliderOverlayType.fontSize,
    SliderOverlayType.position,
    SliderOverlayType.background,
  ]) {
    testWidgets('${type.name}: â†‘ / â†“ leave the slider', (tester) async {
      await pumpOverlay(tester, type: type);
      bool sliderFocused() =>
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<Slider>() !=
          null;
      for (var i = 0; i < 10 && !sliderFocused(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(sliderFocused(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        isFocused(find.text('OK')) || isFocused(find.text('CANCEL')),
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(sliderFocused(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(isFocused(find.text('Reset to Default')), isTrue);
    });
  }

  // REV-166: a long Italian title pushed "Ripristina Predefiniti" off the
  // panel.
  for (final type in SliderOverlayType.values.where(
    (t) => t != SliderOverlayType.none,
  )) {
    testWidgets('Italian, ${type.name}: the title leaves room for Reset', (
      tester,
    ) async {
      await pumpOverlay(tester, type: type, locale: const Locale('it'));

      // An overflow would fail the test by itself; Reset is also fully shown.
      expect(tester.takeException(), isNull);
      final reset = tester.getRect(find.text('Ripristina Predefiniti'));
      final screen = tester.getRect(find.byType(SubtitleSliderOverlay));
      expect(reset.right, lessThanOrEqualTo(screen.right));
    });
  }

  // REV-176 b: the panel was a fixed 380 px and the sync row needs ~308 px,
  // so "+5" was cut off on a phone.
  testWidgets('phone in portrait: the sync panel fits and shows all six '
      'buttons, on two lines', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpOverlay(tester, theme: AppTheme.darkTheme);

    expect(tester.takeException(), isNull);
    final screen = tester.getRect(find.byType(SubtitleSliderOverlay));
    final labels = ['-5', '-1', '-.1', '+.1', '+1', '+5'];
    for (final label in labels) {
      final button = tester.getRect(find.text(label));
      expect(screen.contains(button.topLeft), isTrue, reason: label);
      expect(screen.contains(button.bottomRight), isTrue, reason: label);
    }
    // Too narrow for one line: the buttons wrap.
    expect(
      tester.getRect(find.text('+5')).top,
      greaterThan(tester.getRect(find.text('-5')).bottom),
    );
  });
}
