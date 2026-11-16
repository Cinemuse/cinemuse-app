import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_appearance_form.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_color_picker.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_style_slider.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_text_colors.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/focus_helpers.dart';

void main() {
  late List<SubtitleStyle> changes;

  Future<void> pumpForm(
    WidgetTester tester, {
    SubtitleStyle style = const SubtitleStyle(),
    Locale? locale,
  }) async {
    changes = [];
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SubtitleAppearanceForm(
              style: style,
              onChanged: changes.add,
              onChangeEnd: changes.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // REV-286: a colour picked in the player's colour panel (its yellow) shows
  // as selected in Settings → Subtitles too.
  testWidgets('the player yellow is ticked in Settings', (tester) async {
    await pumpForm(
      tester,
      style: const SubtitleStyle(color: AppTheme.watchlist),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  // REV-308: Settings and the player's panel draw the same controls.
  testWidgets('Settings uses the shared subtitle controls', (tester) async {
    await pumpForm(tester);

    expect(find.byType(SubtitleStyleSlider), findsNWidgets(3));
    expect(find.byType(SubtitleColorPicker), findsOneWidget);
    expect(find.text('24 px'), findsOneWidget);
  });

  // REV-332: ↓ on a Settings slider lowered it instead of moving on, so the
  // keyboard and the remote could never leave the slider.
  testWidgets('↓ leaves a slider without changing it', (tester) async {
    await pumpForm(tester);
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
    await tester.pumpAndSettle();

    expect(changes, isEmpty);
    expect(sliderFocused(), isFalse);
  });

  // Each circle was a stop with its own small ring; now the whole block is
  // one stop with the ring on its edge, like the sliders.
  testWidgets('the colours are one stop: the ring goes round the block, → '
      'and ← move the tick, and Tab leaves it', (tester) async {
    FocusRing.debugWatchKeys();
    await pumpForm(tester);
    const label = 'Text Color';

    await tabTo(tester, find.text(label));
    await tester.pumpAndSettle();
    final ringed = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is FocusRing && w.isVisible),
    );
    expect(
      find.descendant(of: ringed, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(changes.single.color, subtitleTextColors[1]);
    expect(isFocused(find.text(label)), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<Slider>(),
      isNotNull,
      reason: 'Tab stopped on a colour circle',
    );
  });

  // REV-293 (part): the position marks were English in every language.
  testWidgets('Italian: the position marks are translated', (tester) async {
    await pumpForm(tester, locale: const Locale('it'));

    expect(find.text('BASSO'), findsOneWidget);
    expect(find.text('CENTRO'), findsOneWidget);
    expect(find.text('ALTO'), findsOneWidget);
  });
}
