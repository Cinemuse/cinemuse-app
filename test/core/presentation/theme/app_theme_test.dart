import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/explore/domain/explore_type.dart';
import 'package:cinemuse_app/features/explore/presentation/widgets/explore_type_selector.dart';
import 'package:cinemuse_app/features/search/presentation/widgets/search_hover_button.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/cursor_helpers.dart';

// REV-246: buttons, icon buttons and menu options showed the arrow cursor.
void main() {
  Future<void> pumpThemed(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  for (final (name, button) in [
    ('text', TextButton(onPressed: () {}, child: const Text('Go'))),
    ('elevated', ElevatedButton(onPressed: () {}, child: const Text('Go'))),
    ('outlined', OutlinedButton(onPressed: () {}, child: const Text('Go'))),
    ('filled', FilledButton(onPressed: () {}, child: const Text('Go'))),
    ('icon', IconButton(onPressed: () {}, icon: const Icon(Icons.star))),
  ]) {
    testWidgets('$name button: the hand', (tester) async {
      await pumpThemed(tester, button);
      await expectHandOver(tester, find.byWidget(button));
    });
  }

  for (final (name, button) in [
    ('text', const TextButton(onPressed: null, child: Text('Go'))),
    ('icon', const IconButton(onPressed: null, icon: Icon(Icons.star))),
  ]) {
    testWidgets('disabled $name button: the arrow', (tester) async {
      await pumpThemed(tester, button);
      expect(
        await cursorOver(tester, find.byWidget(button)),
        SystemMouseCursors.basic,
      );
    });
  }

  // REV-313: a disabled ElevatedButton looked as pink as an enabled one,
  // also one with its own `styleFrom` colours (the Settings Save button).
  for (final (name, style) in [
    ('theme', null),
    ('own colours', ElevatedButton.styleFrom(backgroundColor: Colors.white)),
  ]) {
    testWidgets('disabled elevated button ($name): greyed', (tester) async {
      await pumpThemed(
        tester,
        ElevatedButton(onPressed: null, style: style, child: const Text('Go')),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, isNot(AppTheme.accent));
      expect(material.color, isNot(Colors.white));
      expect(material.textStyle?.color, AppTheme.textMuted);
    });
  }

  group('hover colour', () {
    /// What the button under [finder] paints in [states].
    Color? overlayOf(
      WidgetTester tester,
      Finder finder,
      Set<WidgetState> states,
    ) => tester
        .widget<InkWell>(
          find.descendant(of: finder, matching: find.byType(InkWell)),
        )
        .overlayColor!
        .resolve(states);

    // Flutter's default is a tint of the icon or text colour: grey on a white
    // one, whatever the app's hover colour says.
    for (final (name, button) in [
      ('icon', IconButton(onPressed: () {}, icon: const Icon(Icons.star))),
      (
        'white icon',
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.star, color: Colors.white),
        ),
      ),
      ('text', TextButton(onPressed: () {}, child: const Text('Go'))),
      (
        'text with its own padding',
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: const Text('Go'),
        ),
      ),
    ]) {
      testWidgets('$name button: the brand purple', (tester) async {
        await pumpThemed(tester, button);
        expect(
          overlayOf(tester, find.byWidget(button), {WidgetState.hovered}),
          AppTheme.accentHoverBg,
        );
      });
    }

    testWidgets('a press under the mouse is not the hover', (tester) async {
      final button = TextButton(onPressed: () {}, child: const Text('Go'));
      await pumpThemed(tester, button);
      expect(
        overlayOf(tester, find.byWidget(button), {
          WidgetState.hovered,
          WidgetState.pressed,
        }),
        Colors.white.withValues(alpha: 0.1),
      );
    });

    testWidgets('a red icon button stays red', (tester) async {
      final button = IconButton(
        onPressed: () {},
        color: Colors.redAccent,
        icon: const Icon(Icons.delete),
      );
      await pumpThemed(tester, button);
      final hover = overlayOf(tester, find.byWidget(button), {
        WidgetState.hovered,
      })!;
      expect(
        hover.withValues(alpha: 1).toARGB32(),
        Colors.redAccent.toARGB32(),
      );
    });

    testWidgets('search buttons: the brand purple under the mouse', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        SearchHoverButton(onTap: () {}, child: const Text('Clear')),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Clear')));
      await tester.pumpAndSettle();

      final box = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.text('Clear'),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as BoxDecoration).color, AppTheme.accentHoverBg);
    });

    testWidgets('Explore tabs: the brand purple under the mouse', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: Center(
                child: ExploreTypeSelector(
                  selectedType: ExploreType.movie,
                  onTypeChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Series')));
      await tester.pumpAndSettle();

      final tab = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('Series'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect((tab.decoration! as BoxDecoration).color, AppTheme.accentHoverBg);
    });
  });

  testWidgets('drop-down options: the hand', (tester) async {
    await pumpThemed(
      tester,
      PopupMenuButton<int>(
        tooltip: 'Sort',
        itemBuilder: (context) => const [
          PopupMenuItem(value: 1, child: Text('Newest')),
          PopupMenuItem(value: 2, child: Text('Oldest')),
        ],
      ),
    );
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();

    await expectHandOver(tester, find.text('Oldest'));
  });
}
