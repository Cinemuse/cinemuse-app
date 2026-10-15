import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_carousel_card.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/menu_helpers.dart';

class _MockResolver extends Mock implements UnifiedStreamResolver {}

void main() {
  testWidgets('right-click: the menu opens at the pointer (REV-248)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final resolver = _MockResolver();
    when(
      () => resolver.hasCachedStream(
        any(),
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenReturn(false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unifiedStreamResolverProvider.overrideWithValue(resolver)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: const Alignment(0.5, -0.9),
              child: SizedBox(
                width: 300,
                child: EpisodeCarouselCard(
                  episode: EpisodeItem(
                    episodeNumber: 1,
                    seasonNumber: 1,
                    name: 'Pilot',
                  ),
                  seasonNumber: 1,
                  mediaId: '1429',
                  onTrackOptions: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final at = tester.getCenter(find.byType(EpisodeCarouselCard));
    await rightClickAt(tester, at);
    expect(menuItems, findsWidgets);
    expectMenuAt(tester, at);
  });
}
