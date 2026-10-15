/// Real app, dev account: the details page's Drop, Play and "mark all"
/// save through the controller (REV-205, old manual check 8p 4).
///
/// Run with (Windows, from `cinemuse-app/`):
/// ```
/// fvm flutter test integration_test/details_actions_test.dart -d windows --dart-define-from-file=dev_login.json
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/details_hero.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

import 'app_test_helpers.dart';

/// Fleabag (TMDB tv 67070): finished, two short seasons, never touched by
/// the dev account.
const _showId = 67070;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Play menu → Drop, Play restores, Track → mark the rest', (
    tester,
  ) async {
    // Wide window: the hero shows Play, its menu arrow and Track.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    final container = await pumpAppAndLogin(tester);
    await expectUntouched(container, _showId, 'tv');
    addTearDown(() => eraseTitle(container, _showId, 'tv'));

    // Being watched: E1 ticked, Continue Watching on E2.
    await container
        .read(mediaDetailsControllerProvider.notifier)
        .logEpisodeWatch(tmdbId: _showId, season: 1, episode: 1);
    expect(
      (await serverHistoryRow(container, _showId, 'tv'))?['status'],
      'watching',
    );

    openDetails(container, _showId, 'tv');
    final menuArrow = find.byIcon(Icons.keyboard_arrow_down);
    await pumpUntil(
      tester,
      () => menuArrow.evaluate().isNotEmpty,
      what: 'the details page',
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MediaDetailsScreen)),
    )!;
    // The episode rows have their own menus and Play buttons.
    Finder inHero(Finder finder) =>
        find.descendant(of: find.byType(DetailsHero), matching: finder);
    bool isDropped() =>
        container
            .read(droppedListProvider)
            .valueOrNull
            ?.containsTitle(_showId, MediaKind.tv) ??
        false;
    Future<void> waitForStatus(String status) async {
      String? shown;
      for (var i = 0; i < 40 && shown != status; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        shown = (await serverHistoryRow(container, _showId, 'tv'))?['status'];
      }
      expect(shown, status);
    }

    // Play menu → Stop Watching: it's in Dropped.
    await tester.tap(inHero(find.byTooltip(l10n.menuMoreOptions)));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(l10n.menuStopWatching));
    await waitForStatus('dropped');
    await pumpUntil(tester, isDropped, what: 'the show in Dropped');

    // Play: it leaves Dropped (the player opens; close it again).
    await tester.tap(inHero(find.byIcon(Icons.play_arrow_outlined)));
    await waitForStatus('watching');
    await pumpUntil(
      tester,
      () => !isDropped(),
      what: 'the show out of Dropped',
    );
    final player = find.byType(VideoPlayerScreen);
    await pumpUntil(
      tester,
      () => player.evaluate().isNotEmpty,
      what: 'the player',
    );
    Navigator.of(tester.element(player)).pop();
    await tester.pump(const Duration(seconds: 1));

    // Track → Mark Remaining: every aired episode ticked, fully watched.
    await tester.tap(inHero(find.text(l10n.detailsFinishSeries)));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(l10n.detailsMarkRemaining));
    final details = await container.read(
      mediaDetailsProvider((id: '$_showId', type: 'tv')).future,
    );
    final aired = container
        .read(seriesDomainServiceProvider)
        .airedEpisodes(details!)
        .length;
    var logs = 0;
    for (var i = 0; i < 40 && logs != aired; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      logs = await serverLogCount(container, _showId, 'tv');
    }
    expect(logs, aired, reason: 'one log per aired episode');
    // The label itself is REV-303 (a show says "Watched", not "Up to date").
    await pumpUntil(
      tester,
      () => inHero(find.byIcon(Icons.check_circle)).evaluate().isNotEmpty,
      what: 'the "fully watched" badge',
    );
    expect(inHero(find.text(l10n.detailsFinishSeries)), findsNothing);
    expect(
      (await serverHistoryRow(container, _showId, 'tv'))?['status'],
      'completed',
    );

    await eraseTitle(container, _showId, 'tv');
    expect(await serverHistoryRow(container, _showId, 'tv'), isNull);
  });
}
