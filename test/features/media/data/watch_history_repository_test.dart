import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'watch_history_fakes.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockTmdbService extends Mock implements TmdbService {}

void main() {
  late WatchHistoryRepository repository;
  late MockSupabaseClient mockSupabase;
  late AppDatabase database;
  late MediaRepository mediaRepo;
  late MockTmdbService mockTmdb;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    when(() => mockSupabase.from(any())).thenAnswer((_) => FakeQueryBuilder());
    database = AppDatabase(NativeDatabase.memory());
    mockTmdb = MockTmdbService();
    mediaRepo = MediaRepository(database, mockTmdb, mockSupabase);
    repository = WatchHistoryRepository(mockSupabase, mediaRepo, database);

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

      final table = FakeQueryBuilder(remoteData);
      when(() => mockSupabase.from(any())).thenAnswer((_) => table);

      await repository.syncWatchHistory(userId);

      final history = await database.getWatchHistory(userId);
      expect(history.length, 1);
      expect(history.first.tmdbId, 1);
      // REV-185: pages need a fixed order, or they repeat or skip rows.
      expect(table.orders, ['tmdb_id', 'media_type']);
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
          'movie',
        );
        expect(result, isNull);
        verifyNever(() => mockSupabase.from(any()));
      },
    );
  });
}
