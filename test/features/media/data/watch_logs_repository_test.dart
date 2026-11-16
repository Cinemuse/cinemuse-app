import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_logs_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
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
  late WatchLogsRepository repository;
  late MockSupabaseClient mockSupabase;
  late AppDatabase database;
  late MediaRepository mediaRepo;
  late MockSeriesDomainService mockSeriesService;
  late MockTmdbService mockTmdb;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    when(() => mockSupabase.from(any())).thenAnswer((_) => FakeQueryBuilder());
    database = AppDatabase(NativeDatabase.memory());
    mockTmdb = MockTmdbService();
    mediaRepo = MediaRepository(database, mockTmdb, mockSupabase);
    mockSeriesService = MockSeriesDomainService();
    repository = WatchLogsRepository(
      mockSupabase,
      mediaRepo,
      database,
      WatchHistoryRepository(mockSupabase, mediaRepo, database),
      mockSeriesService,
    );

    registerFallbackValue(MediaKind.movie);
    registerFallbackValue((id: 1, type: MediaKind.movie));
  });

  tearDown(() async {
    await database.close();
  });

  group('getAllWatchLogs', () {
    const userId = 'user-123';

    test(
      'getAllWatchLogs fetches watch logs and maps to WatchHistory with metadata',
      () async {
        final logsData = [
          {
            'tmdb_id': 100,
            'media_type': 'tv',
            'season': 1,
            'episode': 1,
            'logged_at': '2026-09-14T10:00:00.000Z',
            'duration_watched_seconds': 2400,
          },
          {
            'tmdb_id': 100,
            'media_type': 'tv',
            'season': 1,
            'episode': 2,
            'logged_at': '2026-09-14T11:00:00.000Z',
            'duration_watched_seconds': 2400,
          },
        ];

        final logsTable = FakeQueryBuilder(logsData);
        when(
          () => mockSupabase.from('watch_logs'),
        ).thenAnswer((_) => logsTable);

        await database.upsertMediaItem(
          CachedMediaItemsCompanion.insert(
            tmdbId: 100,
            mediaType: 'tv',
            titleEn: const Value('Test Series'),
            updatedAt: DateTime.now(),
          ),
        );

        final result = await repository.getAllWatchLogs(userId);

        expect(result.length, 2);
        expect(result.first.tmdbId, 100);
        expect(result.first.mediaType, MediaKind.tv);
        expect(result.first.season, 1);
        expect(result.first.episode, 1);
        expect(result.first.media?.titleEn, 'Test Series');
        expect(result.last.episode, 2);
        expect(logsTable.orders, ['logged_at', 'id']);
      },
    );

    test(
      'getAllWatchLogs applies watching and dropped status from watch history',
      () async {
        final logsData = [
          {
            'tmdb_id': 200,
            'media_type': 'tv',
            'season': 1,
            'episode': 1,
            'logged_at': '2026-09-14T10:00:00.000Z',
            'duration_watched_seconds': 1800,
          },
          {
            'tmdb_id': 300,
            'media_type': 'movie',
            'season': null,
            'episode': null,
            'logged_at': '2026-09-14T11:00:00.000Z',
            'duration_watched_seconds': 5400,
          },
        ];

        when(
          () => mockSupabase.from('watch_logs'),
        ).thenAnswer((_) => FakeQueryBuilder(logsData));

        await database.upsertWatchHistory(
          LocalWatchHistoriesCompanion.insert(
            userId: userId,
            tmdbId: 200,
            mediaType: 'tv',
            status: 'dropped',
            lastWatchedAt: DateTime.now(),
          ),
        );
        await database.upsertWatchHistory(
          LocalWatchHistoriesCompanion.insert(
            userId: userId,
            tmdbId: 300,
            mediaType: 'movie',
            status: 'watching',
            lastWatchedAt: DateTime.now(),
          ),
        );

        final result = await repository.getAllWatchLogs(userId);

        expect(result.length, 2);
        expect(result.first.tmdbId, 200);
        expect(result.first.status, WatchStatus.dropped);
        expect(result.last.tmdbId, 300);
        expect(result.last.status, WatchStatus.watching);
      },
    );
  });
}
