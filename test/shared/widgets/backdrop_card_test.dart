import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/backdrop_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/menu_helpers.dart';

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('right-click: the menu opens at the pointer (REV-248)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
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
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final at = tester.getCenter(find.byType(BackdropCard));
    await rightClickAt(tester, at);
    expect(find.text(l10n.homeMoreInfo), findsOneWidget);
    expectMenuAt(tester, at);
  });
}
