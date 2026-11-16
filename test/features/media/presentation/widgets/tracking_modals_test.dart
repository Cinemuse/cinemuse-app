import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/tracking_modals.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/focus_helpers.dart';

/// Holds [key] down for a second, the way a remote's OK is held.
Future<void> holdKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(key);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyRepeatEvent(key);
  }
  await tester.sendKeyUpEvent(key);
  await tester.pumpAndSettle();
}

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

    // Enter held on the row opens the calendar.
    await tabTo(tester, find.text('Mark All'));
    await holdKey(tester, LogicalKeyboardKey.enter);
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // The first ← focuses today in the grid, the second moves to yesterday.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    // On the 1st, yesterday is in the last month: the calendar turns its
    // page first.
    await tester.pumpAndSettle();
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

    // The focus is back on the row: a short Enter marks it.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(marked, day);
  });

  // REV-220: the movie and episode sheets were two copies of one sheet.
  group('movie / episode sheet', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      required int watchCount,
      ValueChanged<DateTime?>? onRewatch,
      VoidCallback? onRemoveAll,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WatchTrackModal(
            title: 'EP 3',
            prompt: 'Track your progress for this episode.',
            removeAllSubtitle: 'Clear all logs for this episode',
            watchCount: watchCount,
            onRewatch: onRewatch ?? (_) {},
            onRemoveOne: () {},
            onRemoveAll: onRemoveAll ?? () {},
            onViewHistory: () {},
          ),
        ),
      ),
    );

    testWidgets('never watched: only "Mark as Watched", dated today', (
      tester,
    ) async {
      DateTime? marked = DateTime(2000);
      await pumpSheet(tester, watchCount: 0, onRewatch: (d) => marked = d);

      expect(find.text('EP 3'), findsOneWidget);
      expect(
        find.text('Track your progress for this episode.'),
        findsOneWidget,
      );
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('View Watch History'), findsNothing);
      expect(find.text('Remove One Watch'), findsNothing);
      expect(find.text('Clear Watch History'), findsNothing);

      await tester.tap(find.text('Mark as Watched'));
      await tester.pumpAndSettle();
      expect(marked, isNull);
    });

    testWidgets('watched twice: rewatch, history and both removes', (
      tester,
    ) async {
      var removedAll = false;
      await pumpSheet(
        tester,
        watchCount: 2,
        onRemoveAll: () => removedAll = true,
      );

      expect(find.text('Mark a Rewatch'), findsOneWidget);
      expect(find.text('View Watch History'), findsOneWidget);
      expect(find.text('Remove One Watch'), findsOneWidget);
      expect(find.text('Clear all logs for this episode'), findsOneWidget);

      await tester.tap(find.text('Clear Watch History'));
      await tester.pumpAndSettle();
      expect(removedAll, isTrue);
    });

    // On the TV the rows only changed colour: no ring showed where the
    // remote was.
    testWidgets('every row shows the ring', (tester) async {
      FocusRing.debugWatchKeys();
      await pumpSheet(tester, watchCount: 2);

      expect(await stopsWithoutRing(tester), isEmpty);
    });

    // On the Fire Stick the remote couldn't reach the calendar button
    // inside the row: holding OK on the row opens the calendar instead.
    testWidgets('the remote: OK marks, held OK opens the calendar', (
      tester,
    ) async {
      DateTime? marked = DateTime(2000);
      await pumpSheet(tester, watchCount: 2, onRewatch: (d) => marked = d);
      await tabTo(tester, find.text('Mark a Rewatch'));

      await holdKey(tester, LogicalKeyboardKey.select);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(marked, DateTime(2000));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(isFocused(find.text('Mark a Rewatch')), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(marked, isNull);
    });

    // The calendar button is for the mouse and touch only.
    testWidgets('the arrows and Tab never stop on the calendar button', (
      tester,
    ) async {
      await pumpSheet(tester, watchCount: 2);
      await tabTo(tester, find.text('Mark a Rewatch'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(isFocused(find.text('Mark a Rewatch')), isTrue);

      bool onIconButton() =>
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<IconButton>() !=
          null;
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(onIconButton(), isFalse);
      }

      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });
}
