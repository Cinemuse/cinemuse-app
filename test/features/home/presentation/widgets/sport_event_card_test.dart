import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/home/domain/sport_tv_event.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/sport_event_card.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

import '../../../../helpers/menu_helpers.dart';

void main() {
  testWidgets('a one-channel event opens Live TV with the channel in the '
      'search box and no chip (REV-122)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'live_tv_selected_categories': ['DTT'],
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SportEventCard(
              event: SportTvEvent(
                dateTime: null,
                sportName: 'Rugby',
                description: 'Italia - Francia',
                channels: ['Rai 2'],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SportEventCard)),
    );
    container.listen(channelFilterProvider, (previous, next) {});
    await tester.pumpAndSettle();
    expect(container.read(channelFilterProvider).isActive, isTrue);

    await tester.tap(find.textContaining('Italia - Francia'));
    await tester.pumpAndSettle();

    expect(container.read(navIndexProvider), NavTab.liveTv);
    expect(container.read(liveTvTabProvider), LiveTvTab.all);
    expect(container.read(channelSearchQueryProvider), 'Rai 2');
    expect(container.read(channelFilterProvider).isActive, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('live_tv_selected_categories'), isNull);
  });

  testWidgets('right-click: the menu opens at the pointer (REV-248)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: const Alignment(0.5, -0.9),
              child: SportEventCard(
                event: SportTvEvent(
                  dateTime: null,
                  sportName: 'Rugby',
                  description: 'Italia - Francia',
                  channels: ['Rai 2', 'Rai Sport'],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final at = tester.getCenter(find.byType(SportEventCard));
    await rightClickAt(tester, at);
    expect(menuItems, findsNWidgets(2));
    expectMenuAt(tester, at);
  });
}
