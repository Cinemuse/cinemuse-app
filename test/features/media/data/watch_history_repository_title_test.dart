import 'dart:async';
import 'dart:io';

import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSeriesDomainService extends Mock implements SeriesDomainService {}

class _MockTmdbService extends Mock implements TmdbService {}

/// An `update()` that records its filters and completes with no rows.
class _RecordingFilterBuilder extends Fake
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  final Map<String, Object> filters;
  _RecordingFilterBuilder(this.filters);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> eq(
    String column,
    Object value,
  ) {
    filters[column] = value;
    return this;
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) => Future.value(<Map<String, dynamic>>[]).then(onValue, onError: onError);
}

class _RecordingQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final filters = <String, Object>{};
  final upserts = <Map<String, dynamic>>[];

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> update(Map values) =>
      _RecordingFilterBuilder(filters);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    upserts.add(values as Map<String, dynamic>);
    return _RecordingFilterBuilder(filters);
  }
}

/// An `update()` that fails as if offline.
class _OfflineFilterBuilder extends Fake
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> eq(
    String column,
    Object value,
  ) => this;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) => Future<List<Map<String, dynamic>>>.error(
    const SocketException('offline'),
  ).then(onValue, onError: onError);
}

class _OfflineQueryBuilder extends Fake implements SupabaseQueryBuilder {
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> update(Map values) =>
      _OfflineFilterBuilder();
}

// REV-177: TMDB movie 1399 and TV show 1399 are different titles.
void main() {
  const userId = 'user-123';
  const sharedId = 1399;

  late _MockSupabaseClient supabase;
  late _RecordingQueryBuilder table;
  late AppDatabase database;
  late WatchHistoryRepository repository;

  setUp(() async {
    supabase = _MockSupabaseClient();
    table = _RecordingQueryBuilder();
    when(() => supabase.from('watch_history')).thenAnswer((_) => table);
    database = AppDatabase(NativeDatabase.memory());
    final tmdb = _MockTmdbService();
    when(
      () => tmdb.getMediaDetails(any(), any()),
    ).thenAnswer((_) async => null);
    repository = WatchHistoryRepository(
      supabase,
      MediaRepository(database, tmdb, supabase),
      database,
      _MockSeriesDomainService(),
      tmdb,
    );
    for (final type in ['movie', 'tv']) {
      await database.upsertWatchHistory(
        LocalWatchHistoriesCompanion.insert(
          userId: userId,
          tmdbId: sharedId,
          mediaType: type,
          status: 'watching',
          lastWatchedAt: DateTime.utc(2026, 10, 1),
        ),
      );
    }
  });

  tearDown(() async {
    await database.close();
  });

  Future<Map<String, String>> localStatuses() async => {
    for (final row in await database.getWatchHistory(userId))
      row.mediaType: row.status,
  };

  test('dropping the movie leaves the show alone', () async {
    await repository.dropFromContinueWatching(userId, sharedId, 'movie');

    expect(await localStatuses(), {'movie': 'dropped', 'tv': 'watching'});
    expect(table.filters, {
      'user_id': userId,
      'tmdb_id': sharedId,
      'media_type': 'movie',
    });
  });

  // REV-184: the drop had no error handling and changed the local copy first.
  test('a drop that fails offline throws and changes nothing', () async {
    when(
      () => supabase.from('watch_history'),
    ).thenAnswer((_) => _OfflineQueryBuilder());

    await expectLater(
      repository.dropFromContinueWatching(userId, sharedId, 'movie'),
      throwsA(isA<NetworkFailure>()),
    );
    expect(await localStatuses(), {'movie': 'watching', 'tv': 'watching'});
  });

  test('restoring the show leaves the movie alone', () async {
    await repository.dropFromContinueWatching(userId, sharedId, 'movie');
    await repository.dropFromContinueWatching(userId, sharedId, 'tv');

    await repository.restoreToContinueWatching(userId, sharedId, 'tv');

    expect(await localStatuses(), {'movie': 'dropped', 'tv': 'watching'});
    expect(table.filters['media_type'], 'tv');
  });

  // REV-178: local time without an offset was stored 1-2 hours ahead.
  test('a progress save sends the time as UTC', () async {
    await repository.updateProgress(
      userId: userId,
      media: MediaItem(
        tmdbId: sharedId,
        mediaType: MediaKind.movie,
        updatedAt: DateTime.now(),
      ),
      progressSeconds: 1800,
      totalDuration: 6000,
    );

    final sent = table.upserts.single['last_watched_at'] as String;
    expect(sent, endsWith('Z'));
    expect(
      DateTime.parse(sent).difference(DateTime.now()).inMinutes.abs(),
      lessThan(1),
    );
  });

  test('a series history stream has no movie rows', () async {
    final rows = await repository.watchSeriesHistory(userId, sharedId).first;

    expect(rows.map((r) => r.mediaType), [MediaKind.tv]);
  });
}
