import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_input.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:cinemuse_app/shared/widgets/state_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a DpadFocusable's builder was last told.
class _Seen {
  bool focused = false;
  bool hovered = false;
}

Widget _item(_Seen seen, {Widget? inside}) => DpadFocusable(
  onTap: () {},
  child: const SizedBox.shrink(),
  builder: (context, isFocused, isHovered, _) {
    seen
      ..focused = isFocused
      ..hovered = isHovered;
    return SizedBox(width: 80, height: 40, child: inside);
  },
);

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  // The brand showcase (cinemuse-design) shows hover and focus side by
  // side without a mouse or remote, through StatePreview.
  group('StatePreview', () {
    for (final c in [
      (name: 'none', preview: null, focused: false, hovered: false),
      (
        name: 'focused',
        preview: (isFocused: true, isHovered: false),
        focused: true,
        hovered: false,
      ),
      (
        name: 'hovered',
        preview: (isFocused: false, isHovered: true),
        focused: false,
        hovered: true,
      ),
    ]) {
      testWidgets('DpadFocusable draws the state it asks for: ${c.name}', (
        tester,
      ) async {
        final seen = _Seen();
        final preview = c.preview;
        await tester.pumpWidget(
          _app(
            preview == null
                ? _item(seen)
                : StatePreview(
                    isFocused: preview.isFocused,
                    isHovered: preview.isHovered,
                    child: _item(seen),
                  ),
          ),
        );

        expect(seen.focused, c.focused);
        expect(seen.hovered, c.hovered);
        expect(
          tester.widget<FocusRing>(find.byType(FocusRing).first).isVisible,
          c.focused,
        );
      });
    }

    testWidgets('only the outer item: a button inside stays normal', (
      tester,
    ) async {
      final outer = _Seen();
      final inner = _Seen();
      await tester.pumpWidget(
        _app(
          StatePreview(
            isFocused: true,
            isHovered: true,
            child: _item(outer, inside: _item(inner)),
          ),
        ),
      );

      expect(outer.focused, isTrue);
      expect(inner.focused, isFalse);
      expect(inner.hovered, isFalse);
    });

    testWidgets('the ring shows even after a click', (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () {}, child: const Text('Click')),
              StatePreview(
                isFocused: true,
                child: FocusRing(
                  isVisible: true,
                  child: const SizedBox(width: 80, height: 40),
                ),
              ),
            ],
          ),
        ),
      );
      FocusRing.debugWatchKeys();
      await tester.tap(find.text('Click'));
      await tester.pump();

      expect(FocusRing.isKeyInput.value, isFalse);
      expect(
        tester.renderObject(find.byType(FocusRing).last),
        paints..rrect(color: AppTheme.focusRing),
      );
    });

    testWidgets('a settings text box gets its focused border', (tester) async {
      await tester.pumpWidget(
        _app(
          StatePreview(
            isFocused: true,
            child: SizedBox(
              width: 300,
              child: SettingsTextField(
                controller: TextEditingController(),
                decoration: settingsInputDecoration(hintText: 'Link'),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.widget<InputDecorator>(find.byType(InputDecorator)).isFocused,
        isTrue,
      );
    });
  });
}
