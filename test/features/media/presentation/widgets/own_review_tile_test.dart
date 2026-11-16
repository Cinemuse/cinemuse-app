import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/own_review_text.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/own_review_tile.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/focus_helpers.dart';

void main() {
  final l10n = AppLocalizationsEn();

  Widget tile(String? text) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 500,
        child: OwnReviewTile(
          review: OwnReview(
            tmdbId: 1,
            mediaType: MediaKind.movie,
            rating: 9,
            text: text,
            createdAt: DateTime.now().subtract(const Duration(days: 400)),
            updatedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ),
      ),
    ),
  );

  testWidgets('"Your review" instead of a name, and no outside review\'s '
      'stars, hearts or source label', (tester) async {
    await tester.pumpWidget(tile('Great'));

    expect(find.text(l10n.ownReviewEditorTitle), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.text('CINEMUSE'), findsNothing);
  });

  testWidgets('the score is a big wreath in the middle, its leaves lit up to '
      'the score and the number inside', (tester) async {
    await tester.pumpWidget(tile('Great'));

    final wreath = find.byType(Wreath);
    expect(tester.widget<Wreath>(wreath).score, 9);
    expect(tester.getSize(wreath).width, greaterThanOrEqualTo(90));
    expect(
      tester.getCenter(wreath).dx,
      moreOrLessEquals(tester.getCenter(find.byType(OwnReviewTile)).dx),
    );
    expect(
      find.descendant(of: wreath, matching: find.text('9')),
      findsOneWidget,
    );
  });

  testWidgets('a screen reader says the score', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(tile('Great'));

    expect(find.bySemanticsLabel(RegExp('Score 9 out of 10')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('its text shows formatted, under the wreath', (tester) async {
    await tester.pumpWidget(tile('**Great** visuals'));

    expect(find.text('Great visuals'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    expect(
      tester.getTopLeft(find.byType(OwnReviewText)).dy,
      greaterThan(tester.getBottomLeft(find.byType(Wreath)).dy),
    );
  });

  testWidgets('it shows the date it last changed', (tester) async {
    await tester.pumpWidget(tile('Great'));

    expect(find.text('2 days ago'), findsOneWidget);
  });

  testWidgets('with no text it is only the heading and the wreath', (
    tester,
  ) async {
    await tester.pumpWidget(tile(null));

    expect(find.byType(OwnReviewText), findsNothing);
    expect(find.byType(Wreath), findsOneWidget);
  });

  testWidgets('pressing it does nothing, but the remote stops on it', (
    tester,
  ) async {
    await tester.pumpWidget(tile('Great'));
    final heading = find.text(l10n.ownReviewEditorTitle);

    await tabTo(tester, heading);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(isFocused(heading), isTrue);
  });
}
