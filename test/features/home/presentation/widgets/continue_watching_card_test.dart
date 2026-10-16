import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/continue_watching_card.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/features/video_player/application/episode_name_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/carousels/carousel_layout_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/app_font.dart';

class MockUnifiedStreamResolver extends Mock implements UnifiedStreamResolver {}

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

// REV-245: under the title a Continue Watching card shows the episode
// ("S2 E5 · Pilot") and the time left.
void main() {
  WatchHistory history(MediaKind type, {required int left}) => WatchHistory(
    userId: 'u',
    tmdbId: 1,
    mediaType: type,
    status: WatchStatus.watching,
    progressSeconds: 600,
    totalDuration: 600 + left,
    lastWatchedAt: DateTime.utc(2026, 10, 1),
    season: type == MediaKind.tv ? 2 : null,
    episode: type == MediaKind.tv ? 5 : null,
    media: MediaItem(
      tmdbId: 1,
      mediaType: type,
      titleEn: 'Some Title',
      titleIt: 'Some Title',
      updatedAt: DateTime.utc(2026),
    ),
  );

  setUpAll(loadAppFont);

  Widget app(WatchHistory item, {String? episodeName}) {
    final resolver = MockUnifiedStreamResolver();
    when(
      () => resolver.hasCachedStream(
        any(),
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenReturn(false);
    return ProviderScope(
      overrides: [
        isRewatchingProvider.overrideWith((ref, title) async => false),
        unifiedStreamResolverProvider.overrideWithValue(resolver),
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
        episodeNameProvider.overrideWith((ref, args) async => episodeName),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          // The row's own height: the extra line must fit (no overflow).
          body: Center(
            child: SizedBox(
              height: CarouselLayoutCalculator.defaultBackdropHeightDesktop,
              child: ContinueWatchingCard(
                historyItem: item,
                width: CarouselLayoutCalculator.defaultBackdropWidthDesktop,
                onCancelRewatch: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  final cases = [
    (
      history(MediaKind.tv, left: 23 * 60),
      'Pilot',
      'S2 E5 · Pilot',
      '23 min left',
    ),
    (history(MediaKind.tv, left: 23 * 60), null, 'S2 E5', '23 min left'),
    (history(MediaKind.movie, left: 70 * 60), null, null, '1 h 10 min left'),
    (history(MediaKind.movie, left: 120 * 60), null, null, '2 h left'),
  ];
  for (final (item, episodeName, episodeLabel, timeLeft) in cases) {
    testWidgets('${item.mediaType.name}: "$episodeLabel", "$timeLeft"', (
      tester,
    ) async {
      await tester.pumpWidget(app(item, episodeName: episodeName));
      await tester.pumpAndSettle();

      if (episodeLabel != null) expect(find.text(episodeLabel), findsOneWidget);
      expect(find.text(timeLeft), findsOneWidget);
      // The title line (the last: the empty picture shows it too), then
      // the episode / time line under it.
      expect(
        tester.getTopLeft(find.text(timeLeft)).dy,
        greaterThan(tester.getBottomLeft(find.text('Some Title').last).dy),
      );
    });
  }
}
