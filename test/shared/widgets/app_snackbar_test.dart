import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pageScaffold = Key('page');

  Future<void> pumpApp(WidgetTester tester, {required Widget home}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AppSnackBarHost(child: child!),
        home: home,
      ),
    );
  }

  /// A page with a bottom tab bar and a button that opens a sheet whose
  /// button calls [onPressed] with the sheet's context.
  Widget pageWithSheet(void Function(BuildContext sheetContext) onPressed) {
    return Scaffold(
      key: pageScaffold,
      bottomNavigationBar: const SizedBox(height: 60, child: Text('Tabs')),
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => AppBottomSheet.show(
            context: context,
            child: AppBottomSheet(
              child: SizedBox(
                height: 300,
                child: Builder(
                  builder: (sheetContext) => TextButton(
                    onPressed: () => onPressed(sheetContext),
                    child: const Text('Remove'),
                  ),
                ),
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    );
  }

  Future<void> openSheetAndRemove(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('the Undo time setting', () {
    tearDown(() => AppSnackBar.undoDuration = AppSnackBar.defaultUndoDuration);

    late Future<bool> undone;

    Future<void> remove(WidgetTester tester) async {
      await pumpApp(
        tester,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  undone = AppSnackBar.showUndo(context, message: 'Removed'),
              child: const Text('Remove'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Remove'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('10 seconds: the countdown starts from 10 and closes then', (
      tester,
    ) async {
      AppSnackBar.undoDuration = const Duration(seconds: 10);
      await remove(tester);
      expect(find.text('Removed (10)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 8));
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
      expect(await undone, isFalse);
    });

    testWidgets('Off: no message, and the removal is final at once', (
      tester,
    ) async {
      AppSnackBar.undoDuration = Duration.zero;
      await remove(tester);

      expect(find.textContaining('Removed'), findsNothing);
      expect(await undone, isFalse);
    });
  });

  testWidgets('Undo from inside a sheet shows over it and can be pressed', (
    tester,
  ) async {
    Future<bool>? undone;
    await pumpApp(
      tester,
      home: pageWithSheet(
        (sheetContext) =>
            undone = AppSnackBar.showUndo(sheetContext, message: 'Removed'),
      ),
    );
    await openSheetAndRemove(tester);

    expect(find.text('Undo').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await undone, isTrue);
  });

  testWidgets('Undo stays and works after the sheet is closed', (tester) async {
    Future<bool>? undone;
    await pumpApp(
      tester,
      home: pageWithSheet(
        (sheetContext) =>
            undone = AppSnackBar.showUndo(sheetContext, message: 'Removed'),
      ),
    );
    await openSheetAndRemove(tester);

    await tester.tapAt(const Offset(200, 100)); // beside the sheet
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Remove'), findsNothing);

    expect(find.text('Undo').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await undone, isTrue);
  });

  testWidgets('a message from inside a sheet sits above the keyboard', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await pumpApp(
      tester,
      home: pageWithSheet(
        (sheetContext) => AppSnackBar.show(sheetContext, message: 'Saved'),
      ),
    );
    await openSheetAndRemove(tester);

    expect(tester.getRect(find.text('Saved')).bottom, lessThan(800 - 300));
  });

  testWidgets('a message from a screen stays on it, above its tab bar', (
    tester,
  ) async {
    await pumpApp(
      tester,
      home: Scaffold(
        key: pageScaffold,
        bottomNavigationBar: const SizedBox(height: 60, child: Text('Tabs')),
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => AppSnackBar.show(context, message: 'Saved'),
            child: const Text('Save'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(pageScaffold),
        matching: find.byType(SnackBar),
      ),
      findsOneWidget,
    );
    expect(tester.getRect(find.text('Saved')).bottom, lessThan(800 - 60));
  });

  group('Undo with the arrows and Enter', () {
    late FocusNode removeButton;
    late BuildContext pageContext;
    late Future<bool> undone;

    /// A page whose "Remove" button has the keyboard focus, as after
    /// pressing it with Enter.
    Future<void> pumpFocusedPage(WidgetTester tester) async {
      removeButton = FocusNode();
      addTearDown(removeButton.dispose);
      await pumpApp(
        tester,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              pageContext = context;
              return TextButton(
                focusNode: removeButton,
                onPressed: () {},
                child: const Text('Remove'),
              );
            },
          ),
        ),
      );
      removeButton.requestFocus();
      await tester.pump();
    }

    Future<void> showUndo(WidgetTester tester) async {
      undone = AppSnackBar.showUndo(pageContext, message: 'Removed');
      await tester.pump(); // the message is built
      await tester.pump(); // the button takes the focus
      await tester.pump(const Duration(milliseconds: 300));
    }

    bool undoHasFocus() =>
        FocusManager.instance.primaryFocus?.debugLabel == 'SnackBar button';

    /// Lets the countdown run out and the message slide away.
    Future<void> waitUntilClosed(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
    }

    testWidgets('Undo under the mouse: the brand purple', (tester) async {
      await pumpFocusedPage(tester);
      await showUndo(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Undo')));
      await tester.pump(const Duration(milliseconds: 200));

      final button = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('Undo'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(
        (button.decoration! as BoxDecoration).color,
        AppTheme.accentHoverBg,
      );
      await waitUntilClosed(tester);
    });

    testWidgets('the message takes the focus, and Enter undoes', (
      tester,
    ) async {
      await pumpFocusedPage(tester);
      await showUndo(tester);
      expect(undoHasFocus(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(await undone, isTrue);
      expect(removeButton.hasPrimaryFocus, isTrue);
    });

    testWidgets('an arrow goes back to the item, and the message stays', (
      tester,
    ) async {
      await pumpFocusedPage(tester);
      await showUndo(tester);
      expect(undoHasFocus(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(removeButton.hasPrimaryFocus, isTrue);
      expect(find.text('Undo'), findsOneWidget);

      await waitUntilClosed(tester);
      expect(await undone, isFalse);
    });

    testWidgets('closing by itself gives the focus back', (tester) async {
      await pumpFocusedPage(tester);
      await showUndo(tester);
      expect(undoHasFocus(), isTrue);

      await waitUntilClosed(tester);
      expect(await undone, isFalse);
      expect(removeButton.hasPrimaryFocus, isTrue);
    });

    testWidgets('after the mouse or a finger, the focus stays put', (
      tester,
    ) async {
      await pumpFocusedPage(tester);
      await tester.tap(find.text('Remove'));
      await showUndo(tester);

      expect(undoHasFocus(), isFalse);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await undone, isTrue);
    });

    testWidgets('from inside a sheet, Enter undoes and the sheet gets the '
        'focus back', (tester) async {
      Future<bool>? undoneInSheet;
      await pumpApp(
        tester,
        home: pageWithSheet(
          (sheetContext) => undoneInSheet = AppSnackBar.showUndo(
            sheetContext,
            message: 'Removed',
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final sheetButton = Focus.of(tester.element(find.text('Remove')));
      sheetButton.requestFocus();
      await tester.pump();
      FocusRing.debugResetInput(); // the tap above was the mouse
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(undoHasFocus(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(await undoneInSheet, isTrue);
      expect(sheetButton.hasPrimaryFocus, isTrue);
    });
  });
}
