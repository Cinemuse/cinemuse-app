import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchHistoryRepository extends Mock
    implements WatchHistoryRepository {}

void main() {
  const tmdbId = 1396;
  final details = <String, dynamic>{
    'seasons': <dynamic>[
      {'season_number': 1, 'episode_count': 2},
      {'season_number': 2, 'episode_count': 3},
    ],
  };

  WatchHistory history({required WatchStatus status}) => WatchHistory(
    userId: 'user-a',
    tmdbId: tmdbId,
    mediaType: MediaKind.tv,
    status: status,
    progressSeconds: 0,
    lastWatchedAt: DateTime.utc(2026, 10, 1),
    season: 1,
    episode: 2,
  );

  // REV-190: opening a show's page used to put it back in Continue Watching
  // at the next season, even when dropped or not aired yet.
  test('a fully watched season opens the next one without writing', () {
    final repository = _MockWatchHistoryRepository();
    final container = ProviderContainer(
      overrides: [
        watchHistoryRepositoryProvider.overrideWithValue(repository),
        watchedEpisodesMapProvider(
          tmdbId,
        ).overrideWithValue({'1-1': 1, '1-2': 1}),
      ],
    );
    addTearDown(container.dispose);

    final season = container
        .read(mediaDetailsControllerProvider.notifier)
        .resolveInitialSeason(
          tmdbId: tmdbId,
          details: details,
          watchHistory: history(status: WatchStatus.dropped),
        );

    expect(season, 2);
    verifyZeroInteractions(repository);
  });
}
