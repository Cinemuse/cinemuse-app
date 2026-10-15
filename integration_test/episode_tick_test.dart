/// Real app, dev account: ticking an episode saves it (BE-06, old manual
/// check A 8); unticking one keeps a resume point and a dropped show
/// (DATA-05, old manual check 8o 22).
///
/// Run with (Windows, from `cinemuse-app/`):
/// ```
/// fvm flutter test integration_test/episode_tick_test.dart -d windows --dart-define-from-file=dev_login.json
/// ```
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_list_card.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';

import 'app_test_helpers.dart';

/// Chernobyl (TMDB tv 87108): a short, finished show the dev account has
/// never touched, so the test can delete everything it logs.
const _showId = 87108;

/// Band of Brothers (TMDB tv 4613): finished, 10 episodes, never touched by
/// the dev account.
const _undoShowId = 4613;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ticking episode 1 marks it watched and saves it', (
    tester,
  ) async {
    // Phone width: each episode row has its own tick button there.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 1000);
    addTearDown(tester.view.reset);

    final container = await pumpAppAndLogin(tester);
    final client = container.read(supabaseClientProvider);
    final userId = client.auth.currentUser!.id;

    Future<int> serverLogCount() async {
      final rows = await client
          .from('watch_logs')
          .select('id')
          .eq('tmdb_id', _showId)
          .eq('media_type', 'tv');
      return rows.length;
    }

    Future<int> serverHistoryCount() async {
      final rows = await client
          .from('watch_history')
          .select('tmdb_id')
          .eq('tmdb_id', _showId)
          .eq('media_type', 'tv');
      return rows.length;
    }

    // Never touch real history: stop if the account already has this show.
    expect(await serverLogCount(), 0, reason: 'dev account already logged it');
    expect(await serverHistoryCount(), 0, reason: 'show is in its history');

    // Undo even if a check below fails: no logs left also removes the
    // Continue Watching row (undo_watch).
    addTearDown(
      () => container
          .read(watchHistoryRepositoryProvider)
          .deleteAllSeriesLogs(userId: userId, tmdbId: _showId),
    );

    unawaited(
      container
          .read(shellNavigatorKeyProvider)
          .currentState!
          .push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  MediaDetailsScreen(mediaId: '$_showId', mediaType: 'tv'),
            ),
          ),
    );

    final tickButtons = find.byType(MarkWatchedButton);
    await pumpUntil(
      tester,
      () => tickButtons.evaluate().isNotEmpty,
      what: 'the episode list',
    );
    MarkWatchedButton episode1() => tester.widget(tickButtons.first);
    expect(episode1().isWatched, isFalse);

    await tester.ensureVisible(tickButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(tickButtons.first);

    // Shown at once (optimistic), and still shown once the server answered
    // (a failed save would un-tick it again).
    await pumpUntil(
      tester,
      () => episode1().isWatched,
      what: 'episode 1 ticked',
    );
    var saved = 0;
    for (var i = 0; i < 20 && saved == 0; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      saved = await serverLogCount();
    }
    expect(saved, 1, reason: 'one log saved on the server');
    expect(episode1().isWatched, isTrue);

    // Clean up now and check it worked (the tear-down is only a safety net).
    await container
        .read(watchHistoryRepositoryProvider)
        .deleteAllSeriesLogs(userId: userId, tmdbId: _showId);
    expect(await serverLogCount(), 0);
    expect(await serverHistoryCount(), 0);
  });

  // DATA-05: unticking the newest episode rewrote the show's row, so the
  // resume point was lost and a dropped show became "watching" again.
  testWidgets('unticking keeps a resume point, and a dropped show dropped', (
    tester,
  ) async {
    final container = await pumpAppAndLogin(tester);
    await expectUntouched(container, _undoShowId, 'tv');
    addTearDown(() => eraseTitle(container, _undoShowId, 'tv'));

    // The page is open as when the user ticks (the ticks read its details).
    openDetails(container, _undoShowId, 'tv');
    await tester.pump(const Duration(seconds: 1));
    final controller = container.read(mediaDetailsControllerProvider.notifier);
    final userId = container.read(supabaseClientProvider).auth.currentUser!.id;

    // Tick E1 and E2: Continue Watching moves on to E3.
    await controller.logMultipleEpisodes(
      tmdbId: _undoShowId,
      episodes: [(season: 1, episode: 1), (season: 1, episode: 2)],
    );
    expect(await serverHistoryRow(container, _undoShowId, 'tv'), {
      'status': 'watching',
      'season': 1,
      'episode': 3,
      'progress_seconds': 0,
    });

    // The player saves 3 min into E3 (its own progress save).
    await container
        .read(watchHistoryRepositoryProvider)
        .updateProgress(
          userId: userId,
          media: MediaItem(
            tmdbId: _undoShowId,
            mediaType: MediaKind.tv,
            updatedAt: DateTime.now(),
          ),
          progressSeconds: 180,
          totalDuration: 3600,
          season: 1,
          episode: 3,
        );

    // Untick E2, the newest watch: still E3 at 3 min.
    await controller.deleteLatestEpisodeLog(
      tmdbId: _undoShowId,
      season: 1,
      episode: 2,
    );
    expect(await serverHistoryRow(container, _undoShowId, 'tv'), {
      'status': 'watching',
      'season': 1,
      'episode': 3,
      'progress_seconds': 180,
    });
    // Continue Watching shows what the local copy says.
    Iterable<WatchHistory> shown() =>
        (container.read(continueWatchingProvider).valueOrNull ??
                const <WatchHistory>[])
            .where(
              (h) => h.tmdbId == _undoShowId && h.mediaType == MediaKind.tv,
            );
    await pumpUntil(
      tester,
      () => shown().isNotEmpty,
      what: 'the show in Continue Watching',
    );
    expect(shown().map((h) => (h.episode, h.progressSeconds)), [(3, 180)]);

    // Drop the show, then untick its newest watch (E1, the only one left):
    // it stays Dropped.
    await controller.dropTitle(shown().single);
    await controller.deleteLatestEpisodeLog(
      tmdbId: _undoShowId,
      season: 1,
      episode: 1,
    );
    expect(
      (await serverHistoryRow(container, _undoShowId, 'tv'))?['status'],
      'dropped',
    );
    expect(await serverLogCount(container, _undoShowId, 'tv'), 0);

    await eraseTitle(container, _undoShowId, 'tv');
    expect(await serverHistoryRow(container, _undoShowId, 'tv'), isNull);
  });
}
