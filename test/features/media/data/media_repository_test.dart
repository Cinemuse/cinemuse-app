import 'dart:async';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cinemuse_app/core/services/media/tmdb_service.dart';

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
}
