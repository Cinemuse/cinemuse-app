import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/title_list_actions.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/menu_helpers.dart';
import '../../helpers/offline_lists.dart';

// REV-203: offline, "Add to Watchlist" from a card's menu failed silently.
void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('offline "Add to Watchlist": a red message, not added', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: offlineListsOverrides(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(child: SizedBox(width: 160, child: _MovieCard())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(MediaCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.menuAddToWatchlist));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.failureNetwork), findsOneWidget);

    // The menu still offers to add it: it isn't in the Watchlist.
    await tester.longPress(find.byType(MediaCard));
    await tester.pumpAndSettle();
    expect(find.text(l10n.menuAddToWatchlist), findsOneWidget);
  });

  // REV-253: the card's ⋮ button has a tooltip in the app's language.
  for (final (locale, l10n) in [
    (const Locale('en'), AppLocalizationsEn()),
    (const Locale('it'), AppLocalizationsIt()),
  ]) {
    testWidgets('⋮ tooltip in ${locale.languageCode}', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: offlineListsOverrides(),
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Center(child: SizedBox(width: 160, child: _MovieCard())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.menuMoreOptions), findsOneWidget);
    });
  }

  testWidgets('right-click: the menu opens at the pointer (REV-248)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: offlineListsOverrides(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment(0.5, -0.9),
              child: SizedBox(width: 160, child: _MovieCard()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final at = tester.getCenter(find.byType(MediaCard));
    await rightClickAt(tester, at);
    expect(find.text(l10n.menuAddToWatchlist), findsOneWidget);
    expectMenuAt(tester, at);
  });
}

/// A movie card wired to the real lists, as the app's screens wire it.
class _MovieCard extends ConsumerWidget {
  const _MovieCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MediaCard(
    title: 'Some Movie',
    listActions: TitleListActions(
      context,
      ref,
      MediaItem(
        tmdbId: 1,
        mediaType: MediaKind.movie,
        titleEn: 'Some Movie',
        updatedAt: DateTime(2026),
      ),
    ),
  );
}
