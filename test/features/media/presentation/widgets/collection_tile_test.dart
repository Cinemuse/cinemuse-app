import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/collection_tile.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/focus_helpers.dart';

// REV-211: the tile was a plain GestureDetector: no remote or keyboard.
void main() {
  late int opens;
  final title = find.text('Star Wars Collection');

  Widget tile() => ProviderScope(
    overrides: [
      collectionModelProvider.overrideWith((ref, id) async {
        opens++;
        return null;
      }),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: CollectionTile(
          collection: MediaCollection(
            id: 10,
            name: 'Star Wars Collection',
            parts: [],
          ),
        ),
      ),
    ),
  );

  setUp(() => opens = 0);

  testWidgets('Enter opens the collection', (tester) async {
    await tester.pumpWidget(tile());
    await tabTo(tester, title);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opens, 1);
  });

  testWidgets('a tap opens the collection', (tester) async {
    await tester.pumpWidget(tile());
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(opens, 1);
  });
}
