import 'dart:async';

import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSeriesDomainService extends Mock implements SeriesDomainService {}

class _MockTmdbService extends Mock implements TmdbService {}

/// What `rpc()` returns: a builder that completes with [_result].
class _FakeRpcBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  final Future<dynamic> _result;
  _FakeRpcBuilder(this._result);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(dynamic value) onValue, {
    Function? onError,
  }) => _result.then(onValue, onError: onError);
}

void main() {
  const userId = 'user-123';

  late _MockSupabaseClient supabase;
  late AppDatabase database;
  late WatchHistoryRepository repository;

  setUp(() {
    supabase = _MockSupabaseClient();
    database = AppDatabase(NativeDatabase.memory());
    final tmdb = _MockTmdbService();
    repository = WatchHistoryRepository(
      supabase,
      MediaRepository(database, tmdb, supabase),
      database,
      _MockSeriesDomainService(),
      tmdb,
    );
  });

  tearDown(() async {
    await database.close();
  });

  void stubRpc(List<Map<String, dynamic>> rows) {
    when(
      () => supabase.rpc<dynamic>(any(), params: any(named: 'params')),
    ).thenAnswer((_) => _FakeRpcBuilder(Future.value(rows)));
  }

  Map<String, dynamic> capturedParams() =>
      verify(
            () => supabase.rpc<dynamic>(
              'undo_watch',
              params: captureAny(named: 'params'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  Map<String, dynamic> remoteRow({
    required String mediaType,
    required String status,
    int season = 0,
    int episode = 0,
  }) => {
    'user_id': userId,
    'tmdb_id': 1399,
    'media_type': mediaType,
    'season': season,
    'episode': episode,
    'status': status,
    'progress_seconds': 0,
    'total_duration': 0,
    'watch_count': 1,
    'last_watched_at': '2026-10-09T18:00:00+00:00',
  };

  Future<void> seedLocalRow(String mediaType) => database.upsertWatchHistory(
    LocalWatchHistoriesCompanion.insert(
      userId: userId,
      tmdbId: 1399,
      mediaType: mediaType,
      status: 'watching',
      season: Value(mediaType == 'tv' ? 1 : 0),
      episode: Value(mediaType == 'tv' ? 6 : 0),
      lastWatchedAt: DateTime.now(),
    ),
  );

  group('undo a watch', () {
    test('removing an episode log is one undo_watch rpc', () async {
      stubRpc([
        remoteRow(mediaType: 'tv', status: 'watching', season: 1, episode: 5),
      ]);
      await seedLocalRow('tv');

      await repository.deleteLatestEpisodeLog(
        userId: userId,
        tmdbId: 1399,
        season: 1,
        episode: 5,
      );

      expect(capturedParams(), {
        'p_tmdb_id': 1399,
        'p_media_type': 'tv',
        'p_season': 1,
        'p_episode': 5,
        'p_only_latest': true,
      });
      // Separate table requests are what made it non-atomic.
      verifyNever(() => supabase.from(any()));

      final local = await database.getWatchHistory(userId);
      expect(local.single.episode, 5);
      expect(local.single.status, 'watching');
      expect(local.single.lastWatchedAt.toUtc(), DateTime.utc(2026, 10, 9, 18));
    });

    test('removing all logs of an episode', () async {
      stubRpc([
        remoteRow(mediaType: 'tv', status: 'watching', season: 1, episode: 5),
      ]);

      await repository.deleteAllEpisodeLogs(
        userId: userId,
        tmdbId: 1399,
        season: 1,
        episode: 5,
      );

      expect(capturedParams(), {
        'p_tmdb_id': 1399,
        'p_media_type': 'tv',
        'p_season': 1,
        'p_episode': 5,
        'p_only_latest': false,
      });
      verifyNever(() => supabase.from(any()));
    });

    test('removing a whole series clears the local row', () async {
      stubRpc([]);
      await seedLocalRow('tv');

      await repository.deleteAllSeriesLogs(userId: userId, tmdbId: 1399);

      expect(capturedParams(), {
        'p_tmdb_id': 1399,
        'p_media_type': 'tv',
        'p_season': null,
        'p_episode': null,
        'p_only_latest': false,
      });
      verifyNever(() => supabase.from(any()));
      expect(await database.getWatchHistory(userId), isEmpty);
    });

    test('removing one movie watch keeps it completed (REV-224)', () async {
      stubRpc([remoteRow(mediaType: 'movie', status: 'completed')]);
      await seedLocalRow('movie');

      await repository.deleteLatestMovieLog(userId: userId, tmdbId: 1399);

      expect(capturedParams(), {
        'p_tmdb_id': 1399,
        'p_media_type': 'movie',
        'p_season': null,
        'p_episode': null,
        'p_only_latest': true,
      });
      verifyNever(() => supabase.from(any()));
      // "watching" would put a finished movie back in Continue Watching.
      final local = await database.getWatchHistory(userId);
      expect(local.single.status, 'completed');
    });

    test('removing all movie watches', () async {
      stubRpc([]);
      await seedLocalRow('movie');

      await repository.deleteAllMovieLogs(userId: userId, tmdbId: 1399);

      expect(capturedParams()['p_only_latest'], isFalse);
      expect(await database.getWatchHistory(userId), isEmpty);
    });

    test('a server error becomes an AppFailure and keeps the cache', () async {
      when(
        () => supabase.rpc<dynamic>(any(), params: any(named: 'params')),
      ).thenAnswer(
        (_) => _FakeRpcBuilder(
          Future.error(const PostgrestException(message: 'boom', code: '500')),
        ),
      );
      await seedLocalRow('tv');

      await expectLater(
        repository.deleteAllSeriesLogs(userId: userId, tmdbId: 1399),
        throwsA(isA<ServerFailure>()),
      );
      expect(await database.getWatchHistory(userId), hasLength(1));
    });
  });
}
