import 'package:cinemuse_app/features/media/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/gallery_bottom_sheet.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// REV-216: gallery images were plain GestureDetectors, so a remote could
// not reach or open them.
void main() {
  testWidgets('arrows move over the images, Enter opens one', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: GalleryBottomSheet(
            backdrops: [
              'https://example.com/a.jpg',
              'https://example.com/b.jpg',
              'https://example.com/c.jpg',
            ],
            posters: [],
            logos: [],
            initialTabIndex: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    final tiles = find
        .descendant(
          of: find.byType(GalleryBottomSheet),
          matching: find.byType(DpadFocusable),
        )
        .evaluate()
        .map((e) => e.widget)
        .toList();
    int focusedTile() => tiles.indexOf(
      FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<DpadFocusable>() ??
          const SizedBox(),
    );

    for (var i = 0; i < 6 && focusedTile() != 0; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focusedTile(), 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focusedTile(), 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final viewer = tester.widget<FullscreenImageViewer>(
      find.byType(FullscreenImageViewer),
    );
    expect(viewer.initialIndex, 1);
  });
}
