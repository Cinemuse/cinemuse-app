import 'dart:async';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cinemuse_app/features/media/data/tmdb_service.dart';

class MockTmdbService extends Mock implements TmdbService {}

class FakeTransformBuilder<T> extends Fake
    implements PostgrestTransformBuilder<T> {
  final T _value;
  FakeTransformBuilder(this._value);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future.value(_value).then(onValue, onError: onError);
  }
}

class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final T _value;
  FakeFilterBuilder(this._value);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<T> inFilter(String column, List values) => this;

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    Map<String, dynamic>? singleValue;
    if (_value is List && (_value as List).isNotEmpty) {
      singleValue = (_value as List).first as Map<String, dynamic>?;
    } else if (_value is Map) {
      singleValue = _value as Map<String, dynamic>?;
    }
    return FakeTransformBuilder(singleValue);
  }

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
      _value as List<Map<String, dynamic>>? ?? [],
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
}

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MediaRepository repository;
  late MockTmdbService mockTmdb;
  late AppDatabase database;
  late MockSupabaseClient mockSupabase;

  setUp(() {
    mockTmdb = MockTmdbService();
    database = AppDatabase(NativeDatabase.memory());
    mockSupabase = MockSupabaseClient();
    when(() => mockSupabase.from(any())).thenAnswer((_) => FakeQueryBuilder());
    repository = MediaRepository(database, mockTmdb, mockSupabase);
  });

  tearDown(() async {
    await database.close();
  });

  group('MediaRepository Tests', () {
    const tmdbId = 123;
    const mediaType = MediaKind.movie;

    test('getMediaItem returns item from local cache if present', () async {
      final now = DateTime.now();
      await database.upsertMediaItem(
        CachedMediaItemsCompanion.insert(
          tmdbId: tmdbId,
          mediaType: 'movie',
          titleEn: Value('Cached Movie'),
          updatedAt: now,
        ),
      );

      final result = await repository.getMediaItem(tmdbId, mediaType);

      expect(result?.titleEn, 'Cached Movie');
    });

    test('getMediaItem returns null if not in memory or Drift', () async {
      final result = await repository.getMediaItem(tmdbId, mediaType);
      expect(result, isNull);
    });
  });

  group('cacheMissingFromRemote', () {
    test(
      'saves missing titles from media_cache, with the right type',
      () async {
        when(() => mockSupabase.from('media_cache')).thenAnswer(
          (_) => FakeQueryBuilder(<Map<String, dynamic>>[
            {
              'tmdb_id': 1399,
              'media_type': 'tv',
              'title_en': 'Game of Thrones',
              'poster_path': '/got.jpg',
              'genres': [18],
              'release_date': '2011-04-17',
              'updated_at': '2026-10-01T10:00:00Z',
            },
            // Same ID, other type: not asked for, must not be saved.
            {'tmdb_id': 1399, 'media_type': 'movie', 'title_en': 'Wrong'},
          ]),
        );

        await repository.cacheMissingFromRemote([
          (id: 1399, type: MediaKind.tv),
        ]);

        final tv = await database.getMediaItem(1399, 'tv');
        expect(tv?.titleEn, 'Game of Thrones');
        expect(tv?.posterPath, '/got.jpg');
        expect(tv?.releaseDate, DateTime(2011, 4, 17));
        expect(await database.getMediaItem(1399, 'movie'), isNull);
      },
    );

    test('keeps titles the local cache already has', () async {
      await database.upsertMediaItem(
        CachedMediaItemsCompanion.insert(
          tmdbId: 1399,
          mediaType: 'tv',
          titleEn: const Value('Local title'),
          voteAverage: const Value(8.4),
          updatedAt: DateTime(2026),
        ),
      );

      await repository.cacheMissingFromRemote([(id: 1399, type: MediaKind.tv)]);

      verifyNever(() => mockSupabase.from('media_cache'));
      final tv = await database.getMediaItem(1399, 'tv');
      expect(tv?.titleEn, 'Local title');
      expect(tv?.voteAverage, 8.4);
    });
  });
}
