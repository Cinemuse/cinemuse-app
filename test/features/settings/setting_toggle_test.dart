import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

void main() {
  testWidgets('SettingToggle toggles value on tap', (tester) async {
    bool value = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SettingToggle(
                value: value,
                onChanged: (val) => setState(() => value = val),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(value, isFalse);

    // Tap the toggle
    await tester.tap(find.byType(DpadFocusable));
    await tester.pumpAndSettle();

    expect(value, isTrue);
  });

  testWidgets('SettingToggle can be activated via D-Pad Enter and Select', (tester) async {
    bool value = false;
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SettingToggle(
                focusNode: focusNode,
                value: value,
                onChanged: (val) => setState(() => value = val),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);

    // Send Enter key
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(value, isTrue);

    // Send Select key (remote center button)
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(value, isFalse);

    focusNode.dispose();
  });
}
