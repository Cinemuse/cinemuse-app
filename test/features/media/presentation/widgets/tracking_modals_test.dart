import 'package:cinemuse_app/features/media/presentation/widgets/tracking_modals.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/focus_helpers.dart';

// REV-216: the "watched on" date was a Cupertino wheel that arrow keys
// couldn't move; it's the Material calendar now.
void main() {
  testWidgets('series sheet: the date is picked with arrows and Enter', (
    tester,
  ) async {
    DateTime? marked;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SeriesTrackModal(
            title: 'Some Show',
            status: (
              isFullyWatched: false,
              isPartiallyWatched: false,
              minWatchCount: 0,
            ),
            onMarkRemaining: (_) {},
            onMarkAll: (date) => marked = date,
            onRemoveAll: () {},
          ),
        ),
      ),
    );

    await tabTo(tester, find.byIcon(Icons.calendar_today));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // The first ← focuses today in the grid, the second moves to yesterday.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    await tabTo(tester, find.text('OK'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day - 1);
    expect(
      find.text('Watched on ${day.day}/${day.month}/${day.year}'),
      findsOneWidget,
    );

    await tester.tap(find.text('Mark All'));
    await tester.pumpAndSettle();
    expect(marked, day);
  });
}
