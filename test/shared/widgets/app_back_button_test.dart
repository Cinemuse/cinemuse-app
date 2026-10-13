import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpButton(WidgetTester tester, VoidCallback onTap) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(child: AppBackButton(onTap: onTap)),
        ),
      ),
    );
  }

  testWidgets('tap calls onTap', (tester) async {
    var calls = 0;
    await pumpButton(tester, () => calls++);

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('Enter on the focused button calls onTap', (tester) async {
    var calls = 0;
    await pumpButton(tester, () => calls++);

    // Tab moves focus to the first focusable control: the back button.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(calls, 1);
  });
}
