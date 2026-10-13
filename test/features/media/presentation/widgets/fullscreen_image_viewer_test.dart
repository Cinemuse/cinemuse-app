import 'package:cinemuse_app/features/media/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Lets the 300 ms page animation run frame by frame.
Future<void> turnPage(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // REV-216: the viewer's buttons could never get focus.
  testWidgets('arrows turn pages on the image, up reaches the buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const FullscreenImageViewer(
          imageUrls: ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
          initialIndex: 0,
        ),
      ),
    );
    await tester.pump();
    final imageFocus = FocusManager.instance.primaryFocus;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await turnPage(tester);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNot(imageFocus));

    // On a button, left / right move focus instead of turning the page.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await turnPage(tester);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, imageFocus);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await turnPage(tester);
    expect(find.text('1 / 2'), findsOneWidget);
  });
}
