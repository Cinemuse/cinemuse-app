import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/hero/hero_indicator_dot.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/hero_section.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/cursor_helpers.dart';
import '../../../../helpers/offline_lists.dart';

void main() {
  // REV-246: the dots under the hero showed the arrow cursor.
  testWidgets('the hero dots: the hand', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: offlineListsOverrides(),
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HeroSection(
              items: [
                for (var id = 1; id <= 3; id++)
                  MediaItem(
                    tmdbId: id,
                    mediaType: MediaKind.movie,
                    titleEn: 'Movie $id',
                    titleIt: 'Movie $id',
                    updatedAt: DateTime.utc(2026),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final dots = find.byType(HeroIndicatorDot);
    expect(dots, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      await expectHandOver(tester, dots.at(i));
    }
    // Stops the hero's auto-advance timer.
    await tester.pumpWidget(const SizedBox());
  });
}
