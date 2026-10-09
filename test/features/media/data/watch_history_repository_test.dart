import 'dart:async';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockMediaRepository extends Mock implements MediaRepository {}

class MockSeriesDomainService extends Mock implements SeriesDomainService {}

class MockTmdbService extends Mock implements TmdbService {}

class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final T _value;
  FakeFilterBuilder(this._value);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> limit(int count, {String? referencedTable}) => this;

  @override
  PostgrestFilterBuilder<T> range(
    int from,
    int to, {
    String? referencedTable,
  }) => this;

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) => FakeTransformBuilder<T>(_value);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future.value(_value).then(onValue, onError: onError);
  }
}

class FakeTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  final T _value;
  FakeTransformBuilder(this._value);

  @override
  PostgrestTransformBuilder<T> range(
    int from,
    int to, {
    String? referencedTable,
  }) => this;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future.value(_value).then(onValue, onError: onError);
  }
}

class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final dynamic _value;
  FakeQueryBuilder([this._value]);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) {
    return FakeFilterBuilder<List<Map<String, dynamic>>>(
      (_value as List?)?.cast<Map<String, dynamic>>() ?? [],
    );
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    return FakeFilterBuilder<List<Map<String, dynamic>>>([]);
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> delete() {
    return FakeFilterBuilder<List<Map<String, dynamic>>>([]);
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> update(Map values) {
    return FakeFilterBuilder<List<Map<String, dynamic>>>([]);
  }
}

void main() {
  late WatchHistoryRepository repository;
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
    repository = WatchHistoryRepository(
      mockSupabase,
      mediaRepo,
      database,
      mockSeriesService,
      mockTmdb,
    );

    // Register Fallbacks
    registerFallbackValue(MediaKind.movie);
    registerFallbackValue((id: 1, type: MediaKind.movie));
  });

  tearDown(() async {
    await database.close();
  });

  group('WatchHistoryRepository Tests', () {
    const userId = 'user-123';

    test('syncWatchHistory fetches from remote and updates local', () async {
      final remoteData = [
        {
          'tmdb_id': 1,
          'media_type': 'movie',
          'status': 'watching',
          'progress_seconds': 100,
          'total_duration': 1000,
          'last_watched_at': DateTime.now().toIso8601String(),
        },
      ];

      when(
        () => mockSupabase.from(any()),
      ).thenAnswer((_) => FakeQueryBuilder(remoteData) as SupabaseQueryBuilder);

      await repository.syncWatchHistory(userId);

      final history = await database.getWatchHistory(userId);
      expect(history.length, 1);
      expect(history.first.tmdbId, 1);
    });

    test(
      'watchHistory stream maps local database results and media metadata',
      () async {
        await database.upsertWatchHistory(
          LocalWatchHistoriesCompanion.insert(
            userId: userId,
            tmdbId: 1,
            mediaType: 'movie',
            status: 'watching',
            lastWatchedAt: DateTime.now(),
          ),
        );

        // Add metadata in database for the stream to find it
        await database.upsertMediaItem(
          CachedMediaItemsCompanion.insert(
            tmdbId: 1,
            mediaType: 'movie',
            titleEn: Value('Movie Title'),
            updatedAt: DateTime.now(),
          ),
        );

        final stream = repository.watchHistory(userId);
        final result = await stream.first;

        expect(result.length, 1);
        expect(result.first.media?.titleEn, 'Movie Title');
      },
    );

    test(
      'getHistoryItem returns null immediately for non-numeric tmdbId',
      () async {
        final result = await repository.getHistoryItem(
          userId,
          'livetv_session',
        );
        expect(result, isNull);
        verifyNever(() => mockSupabase.from(any()));
      },
    );

    test('clearProgress for movie deletes from database (peek case)', () async {
      await database.upsertWatchHistory(
        LocalWatchHistoriesCompanion.insert(
          userId: userId,
          tmdbId: 42,
          mediaType: 'movie',
          status: 'watching',
          progressSeconds: const Value(150),
          lastWatchedAt: DateTime.now(),
        ),
      );

      await repository.clearProgress(
        userId: userId,
        tmdbId: 42,
        mediaType: 'movie',
      );

      final history = await database.getWatchHistory(userId);
      expect(history.any((h) => h.tmdbId == 42), isFalse);
    });

    test(
      'clearProgress for TV peek (0 completed episodes) deletes from database',
      () async {
        when(
          () => mockSupabase.from('watch_logs'),
        ).thenAnswer((_) => FakeQueryBuilder([]));

        await database.upsertWatchHistory(
          LocalWatchHistoriesCompanion.insert(
            userId: userId,
            tmdbId: 101,
            mediaType: 'tv',
            season: const Value(1),
            episode: const Value(1),
            status: 'watching',
            progressSeconds: const Value(180),
            lastWatchedAt: DateTime.now(),
          ),
        );

        await repository.clearProgress(
          userId: userId,
          tmdbId: 101,
          mediaType: 'tv',
        );

        final history = await database.getWatchHistory(userId);
        expect(history.any((h) => h.tmdbId == 101), isFalse);
      },
    );

    test(
      'clearProgress for TV with completed episodes resets progress to 0',
      () async {
        when(() => mockSupabase.from('watch_logs')).thenAnswer(
          (_) => FakeQueryBuilder([
            {'id': 1, 'season': 1, 'episode': 1},
          ]),
        );

        await database.upsertWatchHistory(
          LocalWatchHistoriesCompanion.insert(
            userId: userId,
            tmdbId: 202,
            mediaType: 'tv',
            season: const Value(1),
            episode: const Value(2),
            status: 'watching',
            progressSeconds: const Value(500),
            lastWatchedAt: DateTime.now(),
          ),
        );

        await repository.clearProgress(
          userId: userId,
          tmdbId: 202,
          mediaType: 'tv',
        );

        final history = await database.getWatchHistory(userId);
        final item = history.firstWhere((h) => h.tmdbId == 202);
        expect(item.progressSeconds, 0);
        expect(item.season, 1);
        expect(item.episode, 2);
      },
    );

    test('removeFromDropped deletes item from database', () async {
      await database.upsertWatchHistory(
        LocalWatchHistoriesCompanion.insert(
          userId: userId,
          tmdbId: 303,
          mediaType: 'tv',
          status: 'dropped',
          lastWatchedAt: DateTime.now(),
        ),
      );

      await repository.removeFromDropped(userId, 303, 'tv');

      final history = await database.getWatchHistory(userId);
      expect(history.any((h) => h.tmdbId == 303), isFalse);
    });

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

        when(
          () => mockSupabase.from('watch_logs'),
        ).thenAnswer((_) => FakeQueryBuilder(logsData));

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

        // Verify cached call returns same reference without hitting Supabase again
        final cachedResult = await repository.getAllWatchLogs(userId);
        expect(identical(result, cachedResult), isTrue);

        // Invalidate cache and verify fresh call
        repository.invalidateWatchLogsCache();
        final freshResult = await repository.getAllWatchLogs(userId);
        expect(freshResult.length, 2);
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

        final result = await repository.getAllWatchLogs(
          userId,
          forceRefresh: true,
        );

        expect(result.length, 2);
        expect(result.first.tmdbId, 200);
        expect(result.first.status, WatchStatus.dropped);
        expect(result.last.tmdbId, 300);
        expect(result.last.status, WatchStatus.watching);
      },
    );
  });
}
