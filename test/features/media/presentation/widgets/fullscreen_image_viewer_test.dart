import 'dart:async';
import 'dart:io';

import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/features/media/data/gallery_image_service.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/focus_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

// Lets the 300 ms page animation run frame by frame.
Future<void> turnPage(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The viewer on two images; [service] answers its download button.
Widget viewerApp([GalleryImageService? service]) => ProviderScope(
  retry: noProviderRetry,
  overrides: [
    if (service != null) galleryImageServiceProvider.overrideWithValue(service),
    localizationsProvider.overrideWithValue(AppLocalizationsEn()),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const FullscreenImageViewer(
      imageUrls: ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
      initialIndex: 0,
    ),
  ),
);

/// A service whose save window answers with [window].
GalleryImageService savingTo(Future<String?> Function() window) =>
    GalleryImageService(
      fetchImageBytes: (_) async => Uint8List(1),
      saveFileDialog:
          ({required dialogTitle, required fileName, required bytes}) =>
              window(),
    );

void main() {
  // REV-216: the viewer's buttons could never get focus.
  testWidgets('arrows turn pages on the image, up reaches the buttons', (
    tester,
  ) async {
    await tester.pumpWidget(viewerApp());
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

  group('the back arrow, hidden on the keys', () {
    bool arrowShown() =>
        find.byIcon(Icons.arrow_back).hitTestable().evaluate().isNotEmpty;

    Future<void> moveMouse(WidgetTester tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(400, 400));
      await mouse.moveBy(const Offset(100, 0));
      await mouse.removePointer();
      await tester.pump();
    }

    /// The viewer opened over a page, as in the app.
    Future<void> pumpOpen(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            localizationsProvider.overrideWithValue(AppLocalizationsEn()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Text('Page below'),
          ),
        ),
      );
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) => const FullscreenImageViewer(
                  imageUrls: ['https://example.com/a.jpg'],
                  initialIndex: 0,
                ),
              ),
            ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FullscreenImageViewer), findsOneWidget);
    }

    Future<void> expectLeft(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FullscreenImageViewer), findsNothing);
      expect(find.text('Page below'), findsOneWidget);
    }

    testWidgets('Up from the image lands on the download button', (
      tester,
    ) async {
      await tester.pumpWidget(viewerApp());
      await tester.pump();
      expect(arrowShown(), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(isFocused(find.byIcon(Icons.arrow_back)), isFalse);
      expect(isFocused(find.byIcon(Icons.download)), isTrue);
    });

    testWidgets('the mouse brings it back, and a click leaves', (tester) async {
      await pumpOpen(tester);
      await moveMouse(tester);
      expect(arrowShown(), isTrue);

      await tester.tap(find.byIcon(Icons.arrow_back));

      await expectLeft(tester);
    });

    testWidgets('Esc leaves', (tester) async {
      await pumpOpen(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      await expectLeft(tester);
    });

    testWidgets("the remote's Back leaves", (tester) async {
      await pumpOpen(tester);

      // Nothing takes the key, so Android turns it into its own Back.
      await tester.binding.handlePopRoute();

      await expectLeft(tester);
    });
  });

  // REV-216: the download button swapped for a spinner, so focus was lost.
  testWidgets('download keeps the focus while saving', (tester) async {
    final window = Completer<String?>();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(viewerApp(savingTo(() => window.future)));
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

    // The user cancels the save window. Not pumpAndSettle: the image's own
    // spinner never settles.
    window.complete(null);
    await tester.pump();
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(downloadFocused(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, imageFocus);
  });

  // REV-218: the download ran in the widget and showed raw error text.
  testWidgets('a saved image says so', (tester) async {
    await tester.pumpWidget(viewerApp(savingTo(() async => '/x/a.jpg')));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pump();
    await tester.pump();
    expect(find.text('Image saved successfully'), findsOneWidget);
  });

  testWidgets('a failed download shows the translated error', (tester) async {
    await tester.pumpWidget(
      viewerApp(
        GalleryImageService(
          fetchImageBytes: (_) async => throw const SocketException('offline'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pump();
    await tester.pump();
    expect(find.text(AppLocalizationsEn().failureNetwork), findsOneWidget);
    expect(find.textContaining('offline'), findsNothing);
    expect(find.byIcon(Icons.download), findsOneWidget);
  });

  // REV-217: a zoomed image couldn't be dragged sideways on phones.
  testWidgets('a zoomed image locks the page swipe', (tester) async {
    await tester.pumpWidget(viewerApp());
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
