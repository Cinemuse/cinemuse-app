import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_filter_sheet.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/focus_helpers.dart';

/// Opens the sheet on a window big enough for all of it.
Future<void> _openSheet(WidgetTester tester, List<String> categories) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: noProviderRetry,
      overrides: [
        channelCategoriesProvider.overrideWithValue(AsyncData(categories)),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showChannelFilterSheet(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(DpadFocusable).first))!;

/// The fill of the switch's side or the row that shows [label].
Color? _fill(WidgetTester tester, String label) =>
    ((tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.widgetWithText(DpadFocusable, label),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration)!
            as BoxDecoration)
        .color;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // On the TV the category rows showed no ring where the remote was.
  testWidgets('every stop of the categories shows the ring', (tester) async {
    FocusRing.debugWatchKeys();
    await _openSheet(tester, const ['News', 'Sport']);
    expect(find.text('Sport'), findsOneWidget);

    expect(await stopsWithoutRing(tester), isEmpty);

    // An outer ring covered the switch's other side and was cut by the list.
    expect(
      tester
          .widgetList<FocusRing>(find.byType(FocusRing))
          .where((ring) => !ring.isInside),
      isEmpty,
    );
  });

  // Both sides of the switch looked the same: the selected one, and the other
  // with the focus or the mouse on it.
  testWidgets('the selected side of the switch never looks like the other', (
    tester,
  ) async {
    await _openSheet(tester, const ['News']);

    final l10n = _l10n(tester);
    final categories = find.widgetWithText(
      DpadFocusable,
      l10n.liveTvCategories,
    );
    final playlists = find.widgetWithText(DpadFocusable, l10n.liveTvPlaylists);
    FontWeight? weight(Finder side, String label) => tester
        .widget<Text>(find.descendant(of: side, matching: find.text(label)))
        .style
        ?.fontWeight;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(playlists));
    await tester.pumpAndSettle();

    expect(_fill(tester, l10n.liveTvPlaylists), AppTheme.accentHoverBg);
    expect(
      _fill(tester, l10n.liveTvPlaylists),
      isNot(_fill(tester, l10n.liveTvCategories)),
    );
    expect(
      weight(playlists, l10n.liveTvPlaylists),
      isNot(weight(categories, l10n.liveTvCategories)),
    );
  });

  // Purple text on the purple fill was hard to read; the top bar's is white.
  testWidgets('what is selected reads in bold white, on the switch and the '
      'rows', (tester) async {
    await _openSheet(tester, const ['News']);

    final l10n = _l10n(tester);
    for (final label in [l10n.liveTvCategories, l10n.liveTvAllChannels]) {
      final style = tester.widget<Text>(find.text(label)).style;
      expect(style?.color, AppTheme.textWhite, reason: label);
      expect(style?.fontWeight, FontWeight.bold, reason: label);
    }
  });

  // No other sheet has a close button in its title: a tap outside, Back or a
  // drag closes them all.
  testWidgets('the title has no close button', (tester) async {
    await _openSheet(tester, const ['News']);

    expect(find.byTooltip(_l10n(tester).commonClose), findsNothing);
  });

  testWidgets('a gap keeps the two sides of the switch apart', (tester) async {
    await _openSheet(tester, const ['News']);

    final l10n = _l10n(tester);
    final categories = find.widgetWithText(
      DpadFocusable,
      l10n.liveTvCategories,
    );
    final playlists = find.widgetWithText(DpadFocusable, l10n.liveTvPlaylists);

    expect(
      tester.getTopLeft(playlists).dx - tester.getTopRight(categories).dx,
      4,
    );
  });

  // The hover was drawn under the sheet's opaque background.
  testWidgets('a category row shows the mouse on it, selected or not', (
    tester,
  ) async {
    await _openSheet(tester, const ['News']);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    final selected = _l10n(tester).liveTvAllChannels;
    final selectedFill = _fill(tester, selected);
    await mouse.moveTo(tester.getCenter(find.text(selected)));
    await tester.pumpAndSettle();
    expect(_fill(tester, selected), isNot(selectedFill));

    await mouse.moveTo(tester.getCenter(find.text('News')));
    await tester.pumpAndSettle();
    expect(_fill(tester, 'News'), AppTheme.accentHoverBg);
    expect(_fill(tester, selected), selectedFill);
  });

  // The remote walks the rows of a list too long for the sheet.
  testWidgets('the arrows walk a long list: it follows, never jumps', (
    tester,
  ) async {
    final categories = [for (var i = 0; i < 40; i++) 'Group $i'];
    await _openSheet(tester, categories);
    await tabTo(tester, find.text(_l10n(tester).liveTvAllChannels));

    final list = find.byType(SingleChildScrollView);
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first,
        )
        .position;

    var lastOffset = position.pixels;
    for (final category in categories) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(isFocused(find.text(category)), isTrue, reason: category);
      final row = tester.getRect(find.text(category));
      expect(row.top, greaterThanOrEqualTo(tester.getRect(list).top));
      expect(row.bottom, lessThanOrEqualTo(tester.getRect(list).bottom));
      expect(position.pixels, greaterThanOrEqualTo(lastOffset));
      lastOffset = position.pixels;
    }
    expect(lastOffset, greaterThan(0));
  });
}
