import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WreathLeaf leaf(int value) =>
      wreathLeaves.firstWhere((l) => l.value == value);

  group('the leaves', () {
    test('there are ten, one for each point from 1 to 10', () {
      expect(wreathLeaves.map((l) => l.value).toList()..sort(), [
        for (var value = 1; value <= 10; value++) value,
      ]);
    });

    test('five per side, odd points on the left, even on the right', () {
      for (final l in wreathLeaves) {
        expect(l.isLeft, l.value.isOdd, reason: 'leaf ${l.value}');
        expect(l.center.dx < 100, l.isLeft, reason: 'leaf ${l.value}');
      }
    });

    test('they light from the bottom up, alternating sides', () {
      for (var value = 1; value <= 8; value++) {
        expect(
          leaf(value + 2).center.dy,
          lessThan(leaf(value).center.dy),
          reason: 'leaf ${value + 2} should be above leaf $value',
        );
      }
      expect(leaf(1).center.dy, leaf(2).center.dy);
    });

    test('the wreath is open at the top', () {
      final gap = leaf(10).center.dx - leaf(9).center.dx;
      expect(gap, greaterThan(40));
    });

    test('the two sides mirror each other', () {
      for (var value = 1; value <= 9; value += 2) {
        final left = leaf(value);
        final right = leaf(value + 1);
        expect(left.center.dx, closeTo(200 - right.center.dx, 0.001));
        expect(left.angle, closeTo(-right.angle, 0.001));
      }
    });

    test('pink on the left and cyan on the right, from the theme', () {
      expect(leaf(1).color, AppTheme.wreathLeftLeaves.first);
      expect(leaf(9).color, AppTheme.wreathLeftLeaves.last);
      expect(leaf(2).color, AppTheme.wreathRightLeaves.first);
      expect(leaf(10).color, AppTheme.wreathRightLeaves.last);
    });

    test('a score lights exactly that many leaves', () {
      for (var score = 0; score <= 10; score++) {
        expect(
          wreathLeaves.where((l) => l.isLitAt(score)).length,
          score,
          reason: 'score $score',
        );
      }
    });

    test('a 9 leaves only the top right leaf empty', () {
      expect(wreathLeaves.where((l) => !l.isLitAt(9)).map((l) => l.value), [
        10,
      ]);
    });
  });

  group('the widget', () {
    Widget host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('takes exactly the size it is given', (tester) async {
      await tester.pumpWidget(host(const Wreath(score: 9, size: 170)));

      expect(tester.getSize(find.byType(Wreath)), const Size(170, 170));
    });

    testWidgets('shows the number only when asked', (tester) async {
      await tester.pumpWidget(host(const Wreath(score: 9, size: 170)));
      expect(find.text('9'), findsNothing);

      await tester.pumpWidget(
        host(const Wreath(score: 9, size: 170, showNumber: true)),
      );
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('a screen reader hears the score', (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(host(const Wreath(score: 9, size: 170)));

      expect(find.bySemanticsLabel('Score 9 out of 10'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('draws at every size the app uses, empty or full', (
      tester,
    ) async {
      for (final size in const [18.0, 20.0, 26.0, 36.0, 170.0, 190.0]) {
        for (final score in const [0, 10]) {
          await tester.pumpWidget(host(Wreath(score: score, size: size)));
          expect(tester.takeException(), isNull);
        }
      }
    });
  });
}
