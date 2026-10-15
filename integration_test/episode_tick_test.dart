/// Real app, dev account: ticking an episode saves it (BE-06, old manual
/// check A 8).
///
/// Run with (Windows, from `cinemuse-app/`):
/// ```
/// fvm flutter test integration_test/episode_tick_test.dart -d windows --dart-define-from-file=dev_login.json
/// ```
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_list_card.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';

import 'app_test_helpers.dart';

/// Chernobyl (TMDB tv 87108): a short, finished show the dev account has
/// never touched, so the test can delete everything it logs.
const _showId = 87108;

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
}
