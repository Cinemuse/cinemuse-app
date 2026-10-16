import 'package:cinemuse_app/features/media/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/focus_helpers.dart';

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

  // REV-216: the download button swapped for a spinner, so focus was lost.
  testWidgets('download keeps the focus while saving', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    final spinner = find.descendant(
      of: find.byTooltip('Download Image'),
      matching: find.byType(CircularProgressIndicator),
    );
    bool downloadFocused() =>
        isFocused(find.byIcon(Icons.download)) || isFocused(spinner);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    // REV-297: → once landed back on the image.
    for (var i = 0; i < 6 && !downloadFocused(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    expect(downloadFocused(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(spinner, findsOneWidget);
    expect(downloadFocused(), isTrue);

    // The test HTTP client answers 400: the download fails and ends.
    // Not pumpAndSettle: the image's own spinner never settles.
    for (
      var i = 0;
      i < 5 && find.byIcon(Icons.download).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(downloadFocused(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, imageFocus);
  });

  // REV-217: a zoomed image couldn't be dragged sideways on phones.
  testWidgets('a zoomed image locks the page swipe', (tester) async {
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
    ScrollPhysics? physics() =>
        tester.widget<PageView>(find.byType(PageView)).physics;
    expect(physics(), isNull);

    final image = find.byType(InteractiveViewer);
    await tester.tap(image);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(image);
    await tester.pump();
    expect(physics(), isA<NeverScrollableScrollPhysics>());

    // Double tap again: zoom back out, swiping turns pages again.
    await tester.tap(image);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(image);
    await tester.pump();
    expect(physics(), isNull);
    await tester.pump(const Duration(milliseconds: 500)); // double-tap timer
  });
}
