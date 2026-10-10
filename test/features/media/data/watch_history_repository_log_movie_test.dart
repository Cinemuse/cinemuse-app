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

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

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
              'log_movie_watch',
              params: captureAny(named: 'params'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  Map<String, dynamic> remoteMovieRow({required String status}) => {
    'user_id': userId,
    'tmdb_id': 1399,
    'media_type': 'movie',
    'season': 0,
    'episode': 0,
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
      progressSeconds: const Value(1200),
      // In the future, as rows synced before REV-178 was fixed can be.
      lastWatchedAt: DateTime.now().add(const Duration(hours: 2)),
    ),
  );

  group('mark a movie as watched', () {
    test('is one log_movie_watch rpc, with UTC time', () async {
      stubRpc([remoteMovieRow(status: 'completed')]);
      await seedLocalRow('movie');

      await repository.logMovieWatch(
        userId: userId,
        tmdbId: 1399,
        loggedAt: DateTime.utc(2026, 10, 9, 18).toLocal(),
        isNow: false,
      );

      expect(capturedParams(), {
        'p_tmdb_id': 1399,
        // REV-178: UTC with "Z", not local time without an offset.
        'p_logged_at': '2026-10-09T18:00:00.000Z',
        'p_is_now': false,
      });
      // Separate table requests are what made it non-atomic.
      verifyNever(() => supabase.from(any()));

      // The server decides (REV-179); the local copy follows its answer even
      // though the old local row looked newer.
      final local = await database.getWatchHistory(userId);
      expect(local.single.status, 'completed');
      expect(local.single.progressSeconds, 0);
      expect(local.single.lastWatchedAt.toUtc(), DateTime.utc(2026, 10, 9, 18));
    });

    test('"now" is passed on, so the server counts it as newest', () async {
      stubRpc([remoteMovieRow(status: 'completed')]);

      await repository.logMovieWatch(
        userId: userId,
        tmdbId: 1399,
        loggedAt: DateTime.utc(2026, 10, 10, 12),
        isNow: true,
      );

      expect(capturedParams()['p_is_now'], true);
    });

    test('a show with the same id is left alone (REV-177)', () async {
      stubRpc([remoteMovieRow(status: 'completed')]);
      await seedLocalRow('movie');
      await seedLocalRow('tv');

      await repository.logMovieWatch(
        userId: userId,
        tmdbId: 1399,
        loggedAt: DateTime.now(),
        isNow: true,
      );

      final local = await database.getWatchHistory(userId);
      expect(local.singleWhere((h) => h.mediaType == 'tv').status, 'watching');
      expect(
        local.singleWhere((h) => h.mediaType == 'movie').status,
        'completed',
      );
    });

    test('a server error becomes an AppFailure and keeps the cache', () async {
      when(
        () => supabase.rpc<dynamic>(any(), params: any(named: 'params')),
      ).thenAnswer(
        (_) => _FakeRpcBuilder(
          Future.error(const PostgrestException(message: 'boom', code: '500')),
        ),
      );
      await seedLocalRow('movie');

      await expectLater(
        repository.logMovieWatch(
          userId: userId,
          tmdbId: 1399,
          loggedAt: DateTime.now(),
          isNow: true,
        ),
        throwsA(isA<ServerFailure>()),
      );
      final local = await database.getWatchHistory(userId);
      expect(local.single.status, 'watching');
    });
  });
}
