import 'dart:async';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

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
  late ListsRepository repository;
  late MockSupabaseClient mockSupabase;
  late AppDatabase database;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    database = AppDatabase(NativeDatabase.memory());
    repository = ListsRepository(mockSupabase, database);
  });

  tearDown(() async {
    await database.close();
  });

  group('ListsRepository Tests', () {
    const userId = 'user-123';

    test('syncUserLists updates both lists and items in Drift', () async {
      final remoteData = [
        {
          'id': 'list-1',
          'name': 'My List',
          'type': 'custom',
          'created_at': DateTime.now().toIso8601String(),
          'list_items': [
            {
              'media_tmdb_id': 555,
              'media_type': 'movie',
              'added_at': DateTime.now().toIso8601String(),
            }
          ]
        }
      ];

      when(() => mockSupabase.from(any())).thenAnswer((_) => FakeQueryBuilder(remoteData) as SupabaseQueryBuilder);

      await repository.syncUserLists(userId);

      final lists = await database.watchUserLists(userId).first;
      expect(lists.length, 1);
      expect(lists.first.id, 'list-1');

      final items = await database.watchListItems('list-1').first;
      expect(items.length, 1);
      expect(items.first.mediaTmdbId, 555);
    });

    test('watchUserLists correctly maps and combines DB data', () async {
      final now = DateTime.now();
      await database.upsertUserList(CachedUserListsCompanion.insert(
        id: 'list-1',
        userId: userId,
        name: 'My List',
        type: 'custom',
        createdAt: Value(now),
      ));
      await database.upsertListItem(CachedListItemsCompanion.insert(
        listId: 'list-1',
        mediaTmdbId: 555,
        mediaType: 'movie',
        addedAt: Value(now),
      ));

      final stream = repository.watchUserLists(userId);
      final result = await stream.first;

      expect(result.length, 1);
      expect(result.first.name, 'My List');
      expect(result.first.items.length, 1);
      expect(result.first.items.first.tmdbId, 555);
    });
  });
}
