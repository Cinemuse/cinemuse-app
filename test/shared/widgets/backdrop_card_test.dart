import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/backdrop_card.dart';
import 'package:cinemuse_app/shared/widgets/card_list_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/menu_helpers.dart';

void main() {
  final l10n = AppLocalizationsEn();

  Widget buildCard({CardListActions? listActions}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: const Alignment(0.5, -0.9),
        child: BackdropCard(
          title: 'Some Show',
          width: 300,
          onDetails: () {},
          onDrop: () {},
          listActions: listActions,
        ),
      ),
    ),
  );

  testWidgets('right-click: the menu opens at the pointer (REV-248)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildCard());
    await tester.pumpAndSettle();

    final at = tester.getCenter(find.byType(BackdropCard));
    await rightClickAt(tester, at);
    expect(find.text(l10n.homeMoreInfo), findsOneWidget);
    expectMenuAt(tester, at);
    // No list actions given: no list entries.
    expect(find.text(l10n.menuAddToWatchlist), findsNothing);
    expect(find.text(l10n.detailsAddToList), findsNothing);
  });

  // REV-44: the Watchlist / "Add to list" entries come from the list
  // actions, like MediaCard's.
  for (final (isWatchlisted, label) in [
    (false, l10n.menuAddToWatchlist),
    (true, l10n.menuRemoveFromWatchlist),
  ]) {
    testWidgets('watchlisted $isWatchlisted: "$label", tap toggles', (
      tester,
    ) async {
      final actions = _FakeListActions(isWatchlisted: isWatchlisted);
      await tester.pumpWidget(buildCard(listActions: actions));
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(BackdropCard));
      await tester.pumpAndSettle();
      expect(find.text(l10n.detailsAddToList), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(actions.toggles, 1);
    });
  }
}

class _FakeListActions implements CardListActions {
  @override
  final bool isWatchlisted;
  int toggles = 0;

  _FakeListActions({required this.isWatchlisted});

  @override
  void toggleWatchlist() => toggles++;

  @override
  void addToList() {}
}
