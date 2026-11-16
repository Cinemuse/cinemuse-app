import 'package:cinemuse_app/features/media/presentation/widgets/own_review_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpText(WidgetTester tester, String text) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: OwnReviewText(text))));

  testWidgets('bold, headings and lists show formatted, without their marks', (
    tester,
  ) async {
    await pumpText(tester, '# Top\n\n**Great** visuals\n\n- The sound');

    expect(find.text('Top'), findsOneWidget);
    expect(find.text('Great visuals'), findsOneWidget);
    expect(find.text('The sound'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('a picture never loads: only its description shows', (
    tester,
  ) async {
    await pumpText(tester, '![The poster](https://example.com/a.png)');

    expect(find.byType(Image), findsNothing);
    expect(find.text('The poster'), findsOneWidget);
  });

  testWidgets('a link shows as its words and a tap opens nothing', (
    tester,
  ) async {
    await pumpText(tester, '[The site](https://example.com)');

    expect(find.text('The site'), findsOneWidget);
    await tester.tap(find.text('The site'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
