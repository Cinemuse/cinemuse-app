import 'dart:async';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockTmdbService extends Mock implements TmdbService {}

class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final T _value;
  FakeFilterBuilder(this._value);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

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

/// Every write fails, as when the device is offline (REV-203).
class _FailingFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future<T>.error(
      const PostgrestException(message: 'offline'),
    ).then(onValue, onError: onError);
  }
}

class _FailingQueryBuilder extends Fake implements SupabaseQueryBuilder {
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) => _FailingFilterBuilder<List<Map<String, dynamic>>>();

  @override
  PostgrestFilterBuilder<dynamic> delete({CountOption? count}) =>
      _FailingFilterBuilder<dynamic>();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ListsRepository repository;
  late MockSupabaseClient mockSupabase;
  late AppDatabase database;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    database = AppDatabase(NativeDatabase.memory());
    repository = ListsRepository(
      mockSupabase,
      database,
      MediaRepository(database, _MockTmdbService(), mockSupabase),
    );

    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'check') {
            return ['wifi'];
          }
          return null;
        });
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
              'tmdb_id': 555,
              'media_type': 'movie',
              'added_at': DateTime.now().toIso8601String(),
            },
          ],
        },
      ];

      when(
        () => mockSupabase.from(any()),
      ).thenAnswer((_) => FakeQueryBuilder(remoteData) as SupabaseQueryBuilder);

      await repository.syncUserLists(userId);

      final lists = await database.watchUserLists(userId).first;
      expect(lists.length, 1);
      expect(lists.first.id, 'list-1');

      final items = await (database.select(
        database.cachedListItems,
      )..where((t) => t.listId.equals('list-1'))).get();
      expect(items.length, 1);
      expect(items.first.tmdbId, 555);
    });

    test('an unknown list type does not break the other lists', () async {
      for (final (id, type) in [('l1', 'watchlist'), ('l2', 'ranking')]) {
        await database.upsertUserList(
          CachedUserListsCompanion.insert(
            id: id,
            userId: userId,
            name: id,
            type: type,
          ),
        );
      }

      final lists = await repository.watchUserLists(userId).first;

      expect(lists.map((l) => l.type), [ListType.watchlist, ListType.custom]);
    });

    test('watchUserLists correctly maps and combines DB data', () async {
      final now = DateTime.now();
      await database.upsertUserList(
        CachedUserListsCompanion.insert(
          id: 'list-1',
          userId: userId,
          name: 'My List',
          type: 'custom',
          createdAt: Value(now),
        ),
      );
      await database.upsertListItem(
        CachedListItemsCompanion.insert(
          listId: 'list-1',
          tmdbId: 555,
          mediaType: 'movie',
          addedAt: Value(now),
        ),
      );

      final stream = repository.watchUserLists(userId);
      final result = await stream.first;

      expect(result.length, 1);
      expect(result.first.name, 'My List');
      expect(result.first.items.length, 1);
      expect(result.first.items.first.tmdbId, 555);
    });

    group('a failed server write is undone locally (REV-203)', () {
      Future<List<CachedListItem>> localItems() =>
          database.select(database.cachedListItems).get();

      setUp(() {
        when(
          () => mockSupabase.from('list_items'),
        ).thenAnswer((_) => _FailingQueryBuilder());
      });

      test('add: the item is gone again and the error is rethrown', () async {
        await expectLater(
          repository.addItemToList(
            listId: 'fav',
            tmdbId: 7,
            mediaType: MediaKind.movie,
            meta: const {},
          ),
          throwsA(anything),
        );

        expect(await localItems(), isEmpty);
      });

      test('remove: the item is back and the error is rethrown', () async {
        await database.upsertListItem(
          const CachedListItemsCompanion(
            listId: Value('fav'),
            tmdbId: Value(7),
            mediaType: Value('movie'),
            sortOrder: Value(3),
          ),
        );

        await expectLater(
          repository.removeItemFromList(
            listId: 'fav',
            tmdbId: 7,
            mediaType: MediaKind.movie,
          ),
          throwsA(anything),
        );

        final items = await localItems();
        expect(items.single.tmdbId, 7);
        expect(items.single.sortOrder, 3);
      });
    });
  });
}
