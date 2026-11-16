import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_search_field.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

import '../../../../helpers/focus_helpers.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpField(
    WidgetTester tester, {
    VoidCallback? onClose,
    ValueChanged<String>? onOutsideSearch,
  }) async {
    container = ProviderContainer(retry: noProviderRetry);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChannelSearchField(
              onClose: onClose,
              onOutsideSearch: onOutsideSearch,
            ),
          ),
        ),
      ),
    );
  }

  final box = find.byType(TextField);
  bool isTyping(WidgetTester tester) =>
      tester.widget<TextField>(box).focusNode!.hasFocus;

  /// Reaches the box the way the arrows do, not by clicking it.
  Future<void> arrowToBox(WidgetTester tester) async {
    await tabTo(tester, box);
    expect(isTyping(tester), isFalse);
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  testWidgets('typing searches after a short wait, × clears it at once', (
    tester,
  ) async {
    await pumpField(tester);

    await tester.enterText(box, 'Rai');
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(channelSearchQueryProvider), '');
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(channelSearchQueryProvider), 'Rai');

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(container.read(channelSearchQueryProvider), '');
    expect(find.widgetWithText(TextField, 'Rai'), findsNothing);
  });

  testWidgets('a search set elsewhere shows in the box and is reported; '
      'typed text is not', (tester) async {
    final outside = <String>[];
    await pumpField(tester, onOutsideSearch: outside.add);

    container.read(channelSearchQueryProvider.notifier).set('Sky Sport');
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Sky Sport'), findsOneWidget);
    expect(outside, ['Sky Sport']);

    await tester.enterText(box, 'Rai');
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(channelSearchQueryProvider), 'Rai');
    expect(outside, ['Sky Sport']);
  });

  testWidgets('in the drawer: Right and Back on the box close it, Left '
      'stays; while typing, Back only stops typing and Left moves the '
      'cursor', (tester) async {
    var closed = 0;
    await pumpField(tester, onClose: () => closed++);
    container.read(channelSearchQueryProvider.notifier).set('Rai');
    await tester.pump();

    await arrowToBox(tester);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(closed, 0);
    expect(isFocused(box), isTrue);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.escape);
    expect(closed, 2);

    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(closed, 2);
    expect(isTyping(tester), isTrue);

    await press(tester, LogicalKeyboardKey.escape);
    expect(closed, 2);
    expect(isTyping(tester), isFalse);
  });
}
