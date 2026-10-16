import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/social_actions_group.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/offline_lists.dart';

void main() {
  final l10n = AppLocalizationsEn();

  Future<void> pumpGroup(
    WidgetTester tester, {
    bool isFavorite = false,
    bool isInWatchlist = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: offlineListsOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SocialActionsGroup(
              mediaItem: MediaItem(
                tmdbId: 1,
                mediaType: MediaKind.movie,
                titleEn: 'Some Movie',
                updatedAt: DateTime.utc(2026),
              ),
              isFavorite: isFavorite,
              isInWatchlist: isInWatchlist,
              onListTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // REV-203: offline, the bookmark failed with no message.
  testWidgets('offline bookmark: a red message, still not bookmarked', (
    tester,
  ) async {
    await pumpGroup(tester);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.failureNetwork), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  // REV-304: the three icons had no tooltip.
  for (final (saved, tooltips) in [
    (
      false,
      [l10n.menuAddToFavorites, l10n.menuAddToWatchlist, l10n.detailsAddToList],
    ),
    (
      true,
      [
        l10n.menuRemoveFromFavorites,
        l10n.menuRemoveFromWatchlist,
        l10n.detailsAddToList,
      ],
    ),
  ]) {
    testWidgets('${saved ? 'saved' : 'not saved'}: tooltips $tooltips', (
      tester,
    ) async {
      await pumpGroup(tester, isFavorite: saved, isInWatchlist: saved);

      for (final tooltip in tooltips) {
        expect(find.byTooltip(tooltip), findsOneWidget);
      }
    });
  }
}
