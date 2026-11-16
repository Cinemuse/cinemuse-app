/// Real app, dev account: the details page's Drop, Play and "mark all"
/// save through the controller (REV-205, old manual check 8p 4), and a
/// movie's watch count goes up and stays, today and on a past date
/// (REV-196, old manual check 8o 15). Your own rating is saved from the
/// reviews sheet, read back on the next opening, and removed.
///
/// Run with (Windows, from `cinemuse-app/`):
/// ```
/// fvm flutter test integration_test/details_actions_test.dart -d windows --dart-define-from-file=dev_login.json
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/data/own_review_draft_storage.dart';
import 'package:cinemuse_app/features/media/data/own_reviews_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/comments_bottom_sheet.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/details_hero.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/own_review_editor.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';

import 'app_test_helpers.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service_provider.dart';

/// Fleabag (TMDB tv 67070): finished, two short seasons, never touched by
/// the dev account.
const _showId = 67070;

/// Dr. Strangelove (TMDB movie 935), never touched by the dev account.
const _movieId = 935;

/// 12 Angry Men (TMDB movie 389), never touched or rated by the dev account.
const _ratedMovieId = 389;

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
            .value
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
    await pumpUntil(
      tester,
      () => inHero(find.byIcon(Icons.check_circle)).evaluate().isNotEmpty,
      what: 'the "fully watched" badge',
    );
    expect(inHero(find.text(l10n.detailsFinishSeries)), findsNothing);
    // REV-303: a fully watched show said "Watched".
    expect(inHero(find.text(l10n.detailsUpToDate)), findsOneWidget);
    expect(inHero(find.text(l10n.detailsWatched)), findsNothing);
    expect(
      (await serverHistoryRow(container, _showId, 'tv'))?['status'],
      'completed',
    );

    await eraseTitle(container, _showId, 'tv');
    expect(await serverHistoryRow(container, _showId, 'tv'), isNull);
  });

  testWidgets('movie Track → watched today, then a rewatch on a past date', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    final container = await pumpAppAndLogin(tester);
    await expectUntouched(container, _movieId, 'movie');
    addTearDown(() => eraseTitle(container, _movieId, 'movie'));

    openDetails(container, _movieId, 'movie');
    await pumpUntil(
      tester,
      () => find.byType(DetailsHero).evaluate().isNotEmpty,
      what: 'the details page',
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MediaDetailsScreen)),
    )!;
    Finder inHero(Finder finder) =>
        find.descendant(of: find.byType(DetailsHero), matching: finder);
    // Hidden behind a spinner until the count loads (REV-287).
    final track = inHero(find.text(l10n.detailsTrack)).hitTestable();
    await pumpUntil(
      tester,
      () => track.evaluate().isNotEmpty,
      what: 'the Track button',
    );
    Future<void> waitForLogs(int count) async {
      var logs = 0;
      for (var i = 0; i < 40 && logs != count; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        logs = await serverLogCount(container, _movieId, 'movie');
      }
      expect(logs, count);
    }

    // Today.
    await tester.tap(track);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(l10n.detailsMarkAsWatched));
    await waitForLogs(1);
    final watched = inHero(find.text(l10n.detailsWatched));
    await pumpUntil(
      tester,
      () => watched.evaluate().isNotEmpty,
      what: '"Watched" on the Track button',
    );

    // A rewatch on the 15th of last month, through the calendar.
    await tester.tap(watched);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip(l10n.detailsSelectDate));
    await tester.pump(const Duration(seconds: 1));
    final material = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    );
    await tester.tap(find.byTooltip(material.previousMonthTooltip));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('15'));
    await tester.tap(find.text(material.okButtonLabel));
    await tester.pump(const Duration(seconds: 1));
    final now = DateTime.now();
    final past = DateTime(now.year, now.month - 1, 15);
    await tester.tap(
      find.text(l10n.detailsWatchedOnDate('15/${past.month}/${past.year}')),
    );
    await waitForLogs(2);

    // The count goes up and stays, once the server's logs come back.
    final twice = inHero(find.text(l10n.detailsWatchedCount(2)));
    await pumpUntil(
      tester,
      () => twice.evaluate().isNotEmpty,
      what: '"Watched x2" on the Track button',
    );
    await tester.pump(const Duration(seconds: 3));
    expect(twice, findsOneWidget);
    expect(await serverLogCount(container, _movieId, 'movie'), 2);
    final dates = await container
        .read(supabaseClientProvider)
        .from('watch_logs')
        .select('logged_at')
        .eq('tmdb_id', _movieId)
        .eq('media_type', 'movie');
    final days = dates
        .map((r) => DateTime.parse(r['logged_at'] as String).toLocal())
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    expect(days, {DateTime(now.year, now.month, now.day), past});
    expect(
      (await serverHistoryRow(container, _movieId, 'movie'))?['status'],
      'completed',
    );
  });

  testWidgets('your own rating: saved from the reviews sheet, read back on '
      'the next opening, then removed', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    final container = await pumpAppAndLogin(tester);
    final client = container.read(supabaseClientProvider);
    final userId = client.auth.currentUser!.id;
    const title = (tmdbId: _ratedMovieId, mediaType: MediaKind.movie);
    Future<Map<String, dynamic>?> serverRating() => client
        .from('reviews')
        .select('rating, review_text')
        .eq('tmdb_id', _ratedMovieId)
        .eq('media_type', 'movie')
        .maybeSingle();

    await expectUntouched(container, _ratedMovieId, 'movie');
    expect(
      await serverRating(),
      isNull,
      reason: 'dev account already rated movie $_ratedMovieId',
    );
    // Run last, after the rating's own clean-up: eraseTitle leaves the
    // reviews table alone.
    addTearDown(() => eraseTitle(container, _ratedMovieId, 'movie'));
    addTearDown(() async {
      await client
          .from('reviews')
          .delete()
          .eq('tmdb_id', _ratedMovieId)
          .eq('media_type', 'movie');
      await container.read(ownReviewDraftStorageProvider).remove(userId, title);
    });

    // Only a watched film can be rated.
    await container
        .read(mediaDetailsControllerProvider.notifier)
        .logMovieWatch(tmdbId: _ratedMovieId);
    expect(await serverLogCount(container, _ratedMovieId, 'movie'), 1);

    Finder inHero(Finder finder) =>
        find.descendant(of: find.byType(DetailsHero), matching: finder);
    // The title page's own score: a wreath beside the number.
    Finder ownScore(int rating) => find.descendant(
      of: find
          .ancestor(of: inHero(find.byType(Wreath)), matching: find.byType(Row))
          .first,
      matching: find.text('$rating'),
    );
    late AppLocalizations l10n;
    Future<void> openPage() async {
      openDetails(container, _ratedMovieId, 'movie');
      await pumpUntil(
        tester,
        () => find.byType(DetailsHero).evaluate().isNotEmpty,
        what: 'the details page',
      );
      l10n = AppLocalizations.of(
        tester.element(find.byType(MediaDetailsScreen)),
      )!;
    }

    Future<void> openEditor(String button) async {
      // Not while the page is still sliding in.
      final comments = inHero(
        find.byTooltip(l10n.detailsTvTimeComments),
      ).hitTestable();
      await pumpUntil(
        tester,
        () => comments.evaluate().isNotEmpty,
        what: 'the Comments button',
      );
      await tester.tap(comments);
      final open = find.text(button).hitTestable();
      await pumpUntil(tester, () => open.evaluate().isNotEmpty, what: button);
      await tester.tap(open);
      final editor = find.byType(OwnReviewEditor);
      await pumpUntil(
        tester,
        () => editor.evaluate().isNotEmpty,
        what: 'the editor',
      );
    }

    Future<void> closeSheetAndPage() async {
      Navigator.of(tester.element(find.byType(CommentsBottomSheet))).pop();
      await tester.pump(const Duration(seconds: 1));
      container.read(shellNavigatorKeyProvider).currentState!.pop();
      await tester.pump(const Duration(seconds: 1));
    }

    // Save: the score moved from 5 to 8 with the arrows, and a review.
    await openPage();
    expect(inHero(find.byType(Wreath)), findsNothing);
    await openEditor(l10n.ownReviewAdd);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
    }
    const text = 'Real-app test: *tense* from start to end';
    final reviewBox = find.descendant(
      of: find.byType(OwnReviewEditor),
      matching: find.byType(TextField),
    );
    await tester.tap(reviewBox);
    await tester.pump();
    await tester.enterText(reviewBox, text);
    await tester.pump();
    await tester.tap(find.text(l10n.ownReviewSave));
    Map<String, dynamic>? saved;
    for (var i = 0; i < 40 && saved == null; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      saved = await serverRating();
    }
    expect(saved, {'rating': 8, 'review_text': text});
    // Back to the reviews, with yours on top and the score on the page.
    await pumpUntil(
      tester,
      () => find.text(l10n.ownReviewEdit).evaluate().isNotEmpty,
      what: 'the "Edit review" button',
    );
    expect(find.byType(OwnReviewEditor), findsNothing);
    expect(ownScore(8), findsOneWidget);

    // Read: a new opening asks the server again.
    await closeSheetAndPage();
    final read = await container
        .read(ownReviewsRepositoryProvider)
        .get(userId, title);
    expect((read?.rating, read?.text), (8, text));
    await openPage();
    await pumpUntil(
      tester,
      () => ownScore(8).evaluate().isNotEmpty,
      what: 'the score on the reopened page',
    );

    // Remove: the editor opens on the saved score and text.
    await openEditor(l10n.ownReviewEdit);
    expect(find.text(text), findsOneWidget);
    await tester.tap(find.text(l10n.ownReviewRemove));
    var removed = false;
    for (var i = 0; i < 40 && !removed; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      removed = await serverRating() == null;
    }
    expect(removed, isTrue, reason: 'the rating is still on the server');
    await pumpUntil(
      tester,
      () => find.text(l10n.ownReviewAdd).evaluate().isNotEmpty,
      what: 'the "Add a review" button',
    );
    expect(inHero(find.byType(Wreath)), findsNothing);
    // The Undo message closes without Undo: the rating stays removed.
    await tester.pump(AppSnackBar.undoDuration + const Duration(seconds: 2));
    expect(await serverRating(), isNull);
  });
}
