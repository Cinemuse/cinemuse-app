import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/comment_tile.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/focus_helpers.dart';

// REV-211: "Tap to reveal" was a plain GestureDetector: no remote or keyboard.
void main() {
  late int reveals;
  final reveal = find.text('Tap to reveal');

  Widget tile() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: CommentTile(
        comment: const Comment(
          id: '1',
          author: CommentAuthor(id: 'a', username: 'someone'),
          text: 'Bruce Willis was dead all along',
          isSpoiler: true,
          source: CommentSource.imdb,
        ),
        isSpoilerRevealed: false,
        onRevealSpoiler: () => reveals++,
      ),
    ),
  );

  setUp(() => reveals = 0);

  testWidgets('Enter on "Tap to reveal" reveals the spoiler', (tester) async {
    await tester.pumpWidget(tile());
    await tabTo(tester, reveal);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(reveals, 1);
  });

  testWidgets('a tap reveals the spoiler', (tester) async {
    await tester.pumpWidget(tile());
    await tester.tap(reveal);
    await tester.pump();
    expect(reveals, 1);
  });

  testWidgets('an outside review keeps its stars, hearts and plain text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CommentTile(
            comment: const Comment(
              id: '1',
              author: CommentAuthor(id: 'a', username: 'someone'),
              text: 'Five *stars*',
              rating: 4.5,
              source: CommentSource.imdb,
            ),
            isSpoilerRevealed: false,
            onRevealSpoiler: () => reveals++,
          ),
        ),
      ),
    );

    expect(find.text('Five *stars*'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byType(Wreath), findsNothing);
  });
}
