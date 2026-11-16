import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_log_events.dart';
import 'package:cinemuse_app/features/media/data/watch_logs_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_progress_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/series_domain_service.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'watch_history_fakes.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSeriesDomainService extends Mock implements SeriesDomainService {}

class MockTmdbService extends Mock implements TmdbService {}

void main() {
  late WatchProgressRepository repository;
  late MockSupabaseClient mockSupabase;
  late AppDatabase database;
  late MediaRepository mediaRepo;
  late MockSeriesDomainService mockSeriesService;
  late MockTmdbService mockTmdb;
  // Events that make the timeline and stats reload (PERF-02).
  late int logsWritten;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    when(() => mockSupabase.from(any())).thenAnswer((_) => FakeQueryBuilder());
    database = AppDatabase(NativeDatabase.memory());
    mockTmdb = MockTmdbService();
    mediaRepo = MediaRepository(database, mockTmdb, mockSupabase);
    mockSeriesService = MockSeriesDomainService();
    final events = WatchLogEvents();
    logsWritten = 0;
    events.written.listen((_) => logsWritten++);
    repository = WatchProgressRepository(
      mockSupabase,
      database,
      WatchLogsRepository(
        mockSupabase,
        mediaRepo,
        database,
        WatchHistoryRepository(mockSupabase, mediaRepo, database),
        mockSeriesService,
        events: events,
      ),
      mockTmdb,
      mockSeriesService,
    );

    registerFallbackValue(MediaKind.movie);
    registerFallbackValue(
      MediaItem(tmdbId: 0, mediaType: MediaKind.tv, updatedAt: DateTime(0)),
    );
    registerFallbackValue((id: 1, type: MediaKind.movie));
  });

  tearDown(() async {
    await database.close();
  });

  group('completeEpisode', () {
    const userId = 'user-123';
    final seriesDetails = MediaItem.fromTmdbDetails({
      'id': 1399,
      'seasons': <dynamic>[],
    }, MediaKind.tv);

    void stubRpc(List<Map<String, dynamic>> rows) {
      when(
        () => mockSupabase.rpc<dynamic>(any(), params: any(named: 'params')),
      ).thenAnswer((_) => FakeFilterBuilder<dynamic>(rows));
    }

    Map<String, dynamic> capturedParams() =>
        verify(
              () => mockSupabase.rpc<dynamic>(
                'complete_watch',
                params: captureAny(named: 'params'),
              ),
            ).captured.single
            as Map<String, dynamic>;

    test(
      'does every step in one complete_watch rpc and caches its row',
      () async {
        when(
          () => mockSeriesService.getNextEpisode(any(), any(), any()),
        ).thenReturn((
          next: NextEpisodeInfo(season: 1, episode: 4),
          isAired: true,
        ));
        stubRpc([
          {
            'user_id': userId,
            'tmdb_id': 1399,
            'media_type': 'tv',
            'season': 1,
            'episode': 4,
            'status': 'watching',
            'progress_seconds': 0,
            'total_duration': 0,
            'watch_count': 0,
            'last_watched_at': '2026-10-10T18:00:00+00:00',
          },
        ]);

        await repository.completeEpisode(
          userId: userId,
          tmdbId: 1399,
          season: 1,
          episode: 3,
          durationWatched: 2500,
          series: seriesDetails,
        );

        expect(capturedParams(), {
          'p_tmdb_id': 1399,
          'p_media_type': 'tv',
          'p_season': 1,
          'p_episode': 3,
          'p_duration_watched': 2500,
          'p_next_season': 1,
          'p_next_episode': 4,
          'p_next_aired': true,
          // "Next episode" is pressed once, so it always finishes the episode.
          'p_only_if_watching': false,
        });
        // Separate table requests are what made it non-atomic.
        verifyNever(() => mockSupabase.from(any()));

        final local = await database.getWatchHistory(userId);
        expect(local.single.mediaType, 'tv');
        expect(local.single.episode, 4);
        expect(local.single.status, 'watching');
        expect(
          local.single.lastWatchedAt.toUtc(),
          DateTime.utc(2026, 10, 10, 18),
        );
      },
    );

    // REV-264: specials are extras; Continue Watching goes back to the show.
    test(
      'after a special: the episode after the highest regular one',
      () async {
        when(() => mockSupabase.from('watch_logs')).thenAnswer(
          (_) => FakeQueryBuilder([
            {'season': 2, 'episode': 4},
          ]),
        );
        when(() => mockSeriesService.getNextEpisode(any(), 2, 4)).thenReturn((
          next: NextEpisodeInfo(season: 2, episode: 5),
          isAired: true,
        ));
        stubRpc([]);

        await repository.completeEpisode(
          userId: userId,
          tmdbId: 1399,
          season: 0,
          episode: 1,
          series: seriesDetails,
        );

        final params = capturedParams();
        expect((params['p_season'], params['p_episode']), (0, 1));
        expect((params['p_next_season'], params['p_next_episode']), (2, 5));
      },
    );

    test('without series details it sends no next episode', () async {
      stubRpc([]);

      await repository.completeEpisode(
        userId: userId,
        tmdbId: 1399,
        season: 1,
        episode: 3,
      );

      final params = capturedParams();
      expect(params['p_next_season'], isNull);
      expect(params['p_next_episode'], isNull);
      expect(params['p_next_aired'], isFalse);
      verifyNever(() => mockSeriesService.getNextEpisode(any(), any(), any()));
      await pumpEventQueue();
      expect(logsWritten, 1);
    });

    test('removes the local row when the server has none left', () async {
      stubRpc([]);
      await database.upsertWatchHistory(
        LocalWatchHistoriesCompanion.insert(
          userId: userId,
          tmdbId: 1399,
          mediaType: 'tv',
          status: 'watching',
          season: const Value(1),
          episode: const Value(3),
          lastWatchedAt: DateTime.now(),
        ),
      );

      await repository.completeEpisode(
        userId: userId,
        tmdbId: 1399,
        season: 1,
        episode: 3,
      );

      expect(await database.getWatchHistory(userId), isEmpty);
    });
  });

  group('updateProgress when playback is finished', () {
    const userId = 'user-123';
    final seriesDetails = MediaItem.fromTmdbDetails({
      'id': 1399,
      'seasons': <dynamic>[],
    }, MediaKind.tv);

    MediaItem media(int tmdbId, MediaKind kind) =>
        MediaItem(tmdbId: tmdbId, mediaType: kind, updatedAt: DateTime.now());

    void stubRpc(List<Map<String, dynamic>> rows) {
      when(
        () => mockSupabase.rpc<dynamic>(any(), params: any(named: 'params')),
      ).thenAnswer((_) => FakeFilterBuilder<dynamic>(rows));
    }

    Map<String, dynamic> capturedParams() =>
        verify(
              () => mockSupabase.rpc<dynamic>(
                'complete_watch',
                params: captureAny(named: 'params'),
              ),
            ).captured.single
            as Map<String, dynamic>;

    test('an episode is finished in one complete_watch rpc', () async {
      when(
        () => mockSeriesService.getNextEpisode(any(), any(), any()),
      ).thenReturn((
        next: NextEpisodeInfo(season: 1, episode: 4),
        isAired: true,
      ));
      stubRpc([
        {
          'user_id': userId,
          'tmdb_id': 1399,
          'media_type': 'tv',
          'season': 1,
          'episode': 4,
          'status': 'watching',
          'progress_seconds': 0,
          'total_duration': 0,
          'watch_count': 0,
          'last_watched_at': '2026-10-10T18:00:00+00:00',
        },
      ]);

      await repository.updateProgress(
        userId: userId,
        media: media(1399, MediaKind.tv),
        progressSeconds: 2950,
        totalDuration: 3000,
        season: 1,
        episode: 3,
        series: seriesDetails,
      );

      expect(capturedParams(), {
        'p_tmdb_id': 1399,
        'p_media_type': 'tv',
        'p_season': 1,
        'p_episode': 3,
        'p_duration_watched': 2950,
        'p_next_season': 1,
        'p_next_episode': 4,
        'p_next_aired': true,
        // Saves keep coming after the end: only the first one may finish it.
        'p_only_if_watching': true,
      });
      // Separate table requests are what made it non-atomic.
      verifyNever(() => mockSupabase.from(any()));

      final local = await database.getWatchHistory(userId);
      expect(local.single.episode, 4);
      expect(local.single.status, 'watching');
      // The row's new episode already reloads them; the saves after the end
      // must not (PERF-02).
      await pumpEventQueue();
      expect(logsWritten, 0);
    });

    test(
      'a finished special moves on from the highest regular episode',
      () async {
        when(() => mockSupabase.from('watch_logs')).thenAnswer(
          (_) => FakeQueryBuilder([
            {'season': 2, 'episode': 4},
          ]),
        );
        when(() => mockSeriesService.getNextEpisode(any(), 2, 4)).thenReturn((
          next: NextEpisodeInfo(season: 2, episode: 5),
          isAired: true,
        ));
        stubRpc([]);

        await repository.updateProgress(
          userId: userId,
          media: media(1399, MediaKind.tv),
          progressSeconds: 1450,
          totalDuration: 1500,
          season: 0,
          episode: 3,
          series: seriesDetails,
        );

        final params = capturedParams();
        expect((params['p_next_season'], params['p_next_episode']), (2, 5));
      },
    );

    test('a movie is finished in one complete_watch rpc', () async {
      stubRpc([
        {
          'user_id': userId,
          'tmdb_id': 603,
          'media_type': 'movie',
          'season': 0,
          'episode': 0,
          'status': 'completed',
          'progress_seconds': 0,
          'total_duration': null,
          'watch_count': 1,
          'last_watched_at': '2026-10-10T18:00:00+00:00',
        },
      ]);

      await repository.updateProgress(
        userId: userId,
        media: media(603, MediaKind.movie),
        progressSeconds: 8000,
        totalDuration: 8100,
      );

      expect(capturedParams(), {
        'p_tmdb_id': 603,
        'p_media_type': 'movie',
        'p_season': 0,
        'p_episode': 0,
        'p_duration_watched': 8000,
        'p_next_season': null,
        'p_next_episode': null,
        'p_next_aired': false,
        'p_only_if_watching': true,
      });
      verifyNever(() => mockSupabase.from(any()));
      verifyNever(() => mockSeriesService.getNextEpisode(any(), any(), any()));

      // Before, the trigger's "completed" row only reached Drift on next sync.
      final local = await database.getWatchHistory(userId);
      expect(local.single.mediaType, 'movie');
      expect(local.single.status, 'completed');
    });
  });
}
