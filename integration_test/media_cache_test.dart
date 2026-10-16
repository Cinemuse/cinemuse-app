/// Real app, dev account: opening a title saves it in the shared
/// `media_cache` table, and an empty local cache (a restart on a new
/// device) gets poster, runtime and genres back from it (BE-05, old manual
/// check A 7).
///
/// Run with (Windows, from `cinemuse-app/`):
/// ```
/// fvm flutter test integration_test/media_cache_test.dart -d windows --dart-define-from-file=dev_login.json
/// ```
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';

import 'app_test_helpers.dart';

/// Movies not in `media_cache` when the test was written (12 Angry Men,
/// Vertigo, One Flew Over the Cuckoo's Nest, Jaws, Full Metal Jacket). Users
/// can't delete cache rows, so each run uses up one: add more when the test
/// says none is left.
const _candidates = [389, 426, 510, 578, 600];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opening a title fills media_cache, an empty local cache '
      'reads it back', (tester) async {
    final container = await pumpAppAndLogin(tester);
    final client = container.read(supabaseClientProvider);
    final db = container.read(appDatabaseProvider);

    Future<Map<String, dynamic>?> serverRow(int id) => client
        .from('media_cache')
        .select('poster_path, runtime_minutes, genres')
        .eq('tmdb_id', id)
        .eq('media_type', 'movie')
        .maybeSingle();
    Future<void> forgetLocally(int id) => (db.delete(
      db.cachedMediaItems,
    )..where((t) => t.tmdbId.equals(id) & t.mediaType.equals('movie'))).go();

    int? movieId;
    for (final id in _candidates) {
      if (await serverRow(id) == null) {
        movieId = id;
        break;
      }
    }
    expect(
      movieId,
      isNotNull,
      reason: 'every candidate is in media_cache: add new ones',
    );
    final id = movieId!;
    await forgetLocally(id);

    openDetails(container, id, 'movie');
    await pumpUntil(
      tester,
      () => find.byType(MediaDetailsScreen).evaluate().isNotEmpty,
      what: 'the details page',
    );
    Map<String, dynamic>? row;
    for (var i = 0; i < 40 && row == null; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      row = await serverRow(id);
    }
    expect(row, isNotNull, reason: 'the cache row was saved');
    expect(row!['poster_path'], isNotNull);
    expect(row['runtime_minutes'], greaterThan(0));
    expect(row['genres'], isNotEmpty);

    // "Restart": the local cache is empty, as on a new device.
    await forgetLocally(id);
    await container.read(mediaRepositoryProvider).cacheMissingFromRemote([
      (id: id, type: MediaKind.movie),
    ]);
    final local = await db.getMediaItem(id, 'movie');
    expect(local, isNotNull, reason: 'copied from media_cache');
    expect(local!.posterPath, row['poster_path']);
    expect(local.runtimeMinutes, row['runtime_minutes']);
    expect(local.genres, isNotNull);
  });
}
