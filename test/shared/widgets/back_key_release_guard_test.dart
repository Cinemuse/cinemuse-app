import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/shared/widgets/back_key_release_guard.dart';

// Flutter's test keys have no Android scan code for the remote's Back button:
// it is sent as the web names it, and the app sees the same Back key.
Future<bool> pressBack() => simulateKeyDownEvent(
  LogicalKeyboardKey.goBack,
  physicalKey: PhysicalKeyboardKey.browserBack,
  platform: 'web',
);

Future<bool> holdBack() => simulateKeyRepeatEvent(
  LogicalKeyboardKey.goBack,
  physicalKey: PhysicalKeyboardKey.browserBack,
  platform: 'web',
);

Future<bool> releaseBack() => simulateKeyUpEvent(
  LogicalKeyboardKey.goBack,
  physicalKey: PhysicalKeyboardKey.browserBack,
  platform: 'web',
);

void main() {
  // On the Fire Stick every Back counted twice: the app used the press and
  // Android turned the release into a second Back.
  Future<void> pumpPage(WidgetTester tester, {required bool usesBack}) async {
    await tester.pumpWidget(
      BackKeyReleaseGuard(
        child: MaterialApp(
          home: Focus(
            autofocus: true,
            onKeyEvent: (node, event) =>
                usesBack &&
                    event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.goBack
                ? KeyEventResult.handled
                : KeyEventResult.ignored,
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('BackKeyReleaseGuard: a Back press the app used keeps its '
      'release, held or not', (tester) async {
    await pumpPage(tester, usesBack: true);

    expect(await pressBack(), isTrue);
    expect(await releaseBack(), isTrue);

    // Held: the repeats go on as before, the release is still kept.
    expect(await pressBack(), isTrue);
    expect(await holdBack(), isFalse);
    expect(await releaseBack(), isTrue);
  });

  testWidgets('BackKeyReleaseGuard: a Back press nothing used leaves its '
      'release to Android', (tester) async {
    await pumpPage(tester, usesBack: false);

    expect(await pressBack(), isFalse);
    expect(await releaseBack(), isFalse);
  });

  testWidgets('BackKeyReleaseGuard: other keys pass through', (tester) async {
    await pumpPage(tester, usesBack: true);

    expect(await simulateKeyDownEvent(LogicalKeyboardKey.keyA), isFalse);
    expect(await simulateKeyUpEvent(LogicalKeyboardKey.keyA), isFalse);
  });
}
