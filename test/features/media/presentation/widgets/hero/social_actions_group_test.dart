import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/social_actions_group.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/offline_lists.dart';

// REV-203: offline, the bookmark failed with no message.
void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('offline bookmark: a red message, still not bookmarked', (
    tester,
  ) async {
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
              isFavorite: false,
              isInWatchlist: false,
              onListTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.failureNetwork), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });
}
