import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/data/own_reviews_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

/// What the fake table answers with and what it was asked. The builders are
/// marked immutable, so this is kept apart from them.
class _Table {
  _Table(this.rows);

  final List<Map<String, dynamic>> rows;
  final filters = <String, Object>{};
  final ranges = <(int, int)>[];
  Map<dynamic, dynamic>? upserted;
  String? onConflict;
  bool deleted = false;
  Object? error;
}

class _FakeTable extends Fake implements SupabaseQueryBuilder {
  _FakeTable(this._table);

  final _Table _table;

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) => _FakeQuery(_table);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    _table.upserted = values as Map;
    _table.onConflict = onConflict;
    return _FakeQuery(_table);
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> delete() {
    _table.deleted = true;
    return _FakeQuery(_table);
  }
}

class _FakeQuery extends Fake
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  _FakeQuery(this._table, [this._range]);

  final _Table _table;
  final (int, int)? _range;

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> eq(
    String column,
    Object value,
  ) {
    _table.filters[column] = value;
    return this;
  }

  @override
  PostgrestTransformBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) => this;

  @override
  PostgrestTransformBuilder<List<Map<String, dynamic>>> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  PostgrestTransformBuilder<List<Map<String, dynamic>>> range(
    int from,
    int to, {
    String? referencedTable,
  }) {
    _table.ranges.add((from, to));
    return _FakeQuery(_table, (from, to));
  }

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() =>
      _FakeRow(_table, _table.rows.firstOrNull);

  @override
  PostgrestTransformBuilder<Map<String, dynamic>> single() =>
      _FakeSavedRow(_table);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) {
    final error = _table.error;
    final Future<List<Map<String, dynamic>>> answer = error != null
        ? Future.error(error)
        : Future.value(_page());
    return answer.then(onValue, onError: onError);
  }

  List<Map<String, dynamic>> _page() {
    final range = _range;
    if (range == null) return _table.rows;
    final start = range.$1.clamp(0, _table.rows.length);
    final end = (range.$2 + 1).clamp(0, _table.rows.length);
    return _table.rows.sublist(start, end);
  }
}

class _FakeRow extends Fake
    implements PostgrestTransformBuilder<Map<String, dynamic>?> {
  _FakeRow(this._table, this._row);

  final _Table _table;
  final Map<String, dynamic>? _row;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(Map<String, dynamic>? value) onValue, {
    Function? onError,
  }) {
    final error = _table.error;
    final Future<Map<String, dynamic>?> answer = error != null
        ? Future.error(error)
        : Future.value(_row);
    return answer.then(onValue, onError: onError);
  }
}

class _FakeSavedRow extends Fake
    implements PostgrestTransformBuilder<Map<String, dynamic>> {
  _FakeSavedRow(this._table);

  final _Table _table;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(Map<String, dynamic> value) onValue, {
    Function? onError,
  }) {
    final error = _table.error;
    final Future<Map<String, dynamic>> answer = error != null
        ? Future.error(error)
        : Future.value({
            'created_at': '2026-01-01T00:00:00+00:00',
            ..._table.upserted!.cast<String, dynamic>(),
          });
    return answer.then(onValue, onError: onError);
  }
}

Map<String, dynamic> _row(int tmdbId, {int rating = 7}) => {
  'tmdb_id': tmdbId,
  'media_type': 'movie',
  'rating': rating,
  'review_text': null,
  'created_at': '2026-11-01T10:00:00+00:00',
  'updated_at': '2026-11-01T10:00:00+00:00',
};

void main() {
  const userId = 'user-1';
  const dune = (tmdbId: 438631, mediaType: MediaKind.movie);

  late _MockClient client;
  late OwnReviewsRepository repository;

  _Table tableWith(List<Map<String, dynamic>> rows) {
    final table = _Table(rows);
    when(() => client.from('reviews')).thenAnswer((_) => _FakeTable(table));
    return table;
  }

  setUp(() {
    client = _MockClient();
    repository = OwnReviewsRepository(client);
  });

  group('get', () {
    test('asks for this title of this user and reads the row', () async {
      final table = tableWith([_row(438631, rating: 9)]);

      final review = await repository.get(userId, dune);

      expect(review?.rating, 9);
      expect(table.filters, {
        'user_id': userId,
        'tmdb_id': 438631,
        'media_type': 'movie',
      });
    });

    test('is null when the title has no rating', () async {
      tableWith([]);

      expect(await repository.get(userId, dune), isNull);
    });

    test('a failure is an AppFailure, not "no rating"', () async {
      tableWith([]).error = const PostgrestException(message: 'down');

      await expectLater(
        repository.get(userId, dune),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('getAll', () {
    test('reads only this user', () async {
      final table = tableWith([_row(1), _row(2)]);

      final reviews = await repository.getAll(userId);

      expect(reviews.map((r) => r.tmdbId), [1, 2]);
      expect(table.filters, {'user_id': userId});
    });

    test('keeps reading past the server limit of 1000 rows', () async {
      final table = tableWith([for (var i = 0; i < 1500; i++) _row(i)]);

      final reviews = await repository.getAll(userId);

      expect(reviews, hasLength(1500));
      expect(table.ranges, [(0, 999), (1000, 1999)]);
    });

    test('stops when the last page is exactly full', () async {
      final table = tableWith([for (var i = 0; i < 1000; i++) _row(i)]);

      expect(await repository.getAll(userId), hasLength(1000));
      expect(table.ranges, [(0, 999), (1000, 1999)]);
    });
  });

  group('save', () {
    test('overwrites the title\'s rating and keeps its first date', () async {
      final table = tableWith([]);

      final saved = await repository.save(
        userId,
        dune,
        rating: 9,
        text: '**Great**',
      );

      expect(table.onConflict, 'user_id,tmdb_id,media_type');
      expect(table.upserted, containsPair('user_id', userId));
      expect(table.upserted, containsPair('tmdb_id', 438631));
      expect(table.upserted, containsPair('media_type', 'movie'));
      expect(table.upserted, containsPair('rating', 9));
      expect(table.upserted, containsPair('review_text', '**Great**'));
      expect(
        table.upserted!.containsKey('created_at'),
        isFalse,
        reason: 'sending it would replace when it was first made',
      );
      expect(saved.rating, 9);
    });

    test('stores when it changed in UTC', () async {
      final table = tableWith([]);

      await repository.save(userId, dune, rating: 9);

      final updatedAt = DateTime.parse(table.upserted!['updated_at'] as String);
      expect(updatedAt.isUtc, isTrue);
    });

    test('a failure is an AppFailure', () async {
      tableWith([]).error = const PostgrestException(message: 'refused');

      await expectLater(
        repository.save(userId, dune, rating: 9),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  test('restore puts the rating back with its own dates', () async {
    final table = tableWith([]);

    await repository.restore(
      userId,
      OwnReview(
        tmdbId: 438631,
        mediaType: MediaKind.movie,
        rating: 9,
        text: 'kept',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 2, 2),
      ),
    );

    expect(table.onConflict, 'user_id,tmdb_id,media_type');
    expect(table.upserted, containsPair('review_text', 'kept'));
    expect(
      table.upserted,
      containsPair('created_at', DateTime.utc(2026, 1, 1).toIso8601String()),
    );
    expect(
      table.upserted,
      containsPair('updated_at', DateTime.utc(2026, 2, 2).toIso8601String()),
    );
  });

  test('remove deletes only this title of this user', () async {
    final table = tableWith([]);

    await repository.remove(userId, dune);

    expect(table.deleted, isTrue);
    expect(table.filters, {
      'user_id': userId,
      'tmdb_id': 438631,
      'media_type': 'movie',
    });
  });
}
