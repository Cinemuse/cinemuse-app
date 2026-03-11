import 'dart:async';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockMediaRepository extends Mock implements MediaRepository {}
class MockSeriesDomainService extends Mock implements SeriesDomainService {}

class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final T _value;
  FakeFilterBuilder(this._value);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    return Future.value(_value).then(onValue, onError: onError);
  }
}

class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final dynamic _value;
  FakeQueryBuilder([this._value]);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([String columns = '*']) {
    return FakeFilterBuilder<List<Map<String, dynamic>>>(_value as List<Map<String, dynamic>>? ?? []);
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> upsert(Object values, {String? onConflict, bool ignoreDuplicates = false, bool defaultToNull = true}) {
    return FakeFilterBuilder<List<Map<String, dynamic>>>([]);
  }
}

void main() {
  late WatchHistoryRepository repository;
  late MockSupabaseClient mockSupabase;
  late AppDatabase database;
  late MockMediaRepository mockMediaRepo;
  late MockSeriesDomainService mockSeriesService;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    database = AppDatabase(NativeDatabase.memory());
    mockMediaRepo = MockMediaRepository();
    mockSeriesService = MockSeriesDomainService();
    repository = WatchHistoryRepository(mockSupabase, mockMediaRepo, database, mockSeriesService);
    
    // Register Fallbacks
    registerFallbackValue(MediaKind.movie);
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
        }
      ];

      when(() => mockSupabase.from(any())).thenAnswer((_) => FakeQueryBuilder(remoteData) as SupabaseQueryBuilder);

      await repository.syncWatchHistory(userId);

      final history = await database.getWatchHistory(userId);
      expect(history.length, 1);
      expect(history.first.tmdbId, 1);
    });

    test('watchHistory stream maps local database results and media metadata', () async {
      await database.upsertWatchHistory(LocalWatchHistoriesCompanion.insert(
        userId: userId,
        tmdbId: 1,
        mediaType: 'movie',
        status: 'watching',
        lastWatchedAt: DateTime.now(),
      ));

      when(() => mockMediaRepo.getMediaItem(1, any())).thenAnswer((_) async => MediaItem(
        tmdbId: 1,
        title: 'Movie Title',
        mediaType: MediaKind.movie,
        updatedAt: DateTime.now(),
      ));

      final stream = repository.watchHistory(userId);
      final result = await stream.first;

      expect(result.length, 1);
      expect(result.first.media?.title, 'Movie Title');
    });
  });
}
