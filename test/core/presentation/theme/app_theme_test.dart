import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
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
