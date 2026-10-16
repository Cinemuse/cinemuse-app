/// Real app, dev account: the Profile tab shows the watch history and the
/// lists, and the details page's bookmark adds a title to the Watchlist
/// (BE-08, old manual check A 9: the RLS rules read `auth.uid()` once).
///
/// Run with (Windows, from `cinemuse-app/`):
/// ```
/// fvm flutter test integration_test/profile_test.dart -d windows --dart-define-from-file=dev_login.json
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/media/application/media_details_controller.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/details_hero.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/navigation/presentation/app_shell.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/system_list_card.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';

import 'app_test_helpers.dart';

/// The Gold Rush (TMDB movie 962), never touched by the dev account.
const _movieId = 962;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bookmark adds to the Watchlist, Profile shows history and '
      'lists', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    final container = await pumpAppAndLogin(tester);
    final client = container.read(supabaseClientProvider);
    final lists = container.read(userListsProvider.notifier);
    Future<bool> inServerWatchlist() async {
      final rows = await client
          .from('list_items')
          .select('tmdb_id, lists!inner(type)')
          .eq('lists.type', 'watchlist')
          .eq('tmdb_id', _movieId)
          .eq('media_type', 'movie');
      return rows.isNotEmpty;
    }

    await expectUntouched(container, _movieId, 'movie');
    expect(await inServerWatchlist(), isFalse, reason: 'already watchlisted');
    addTearDown(() => eraseTitle(container, _movieId, 'movie'));
    addTearDown(() async {
      final watchlist = container
          .read(userListsProvider)
          .valueOrNull
          ?.where((l) => l.type == ListType.watchlist)
          .firstOrNull;
      if (watchlist != null && lists.isInWatchlist(_movieId, MediaKind.movie)) {
        await lists.removeItemFromList(watchlist.id, _movieId, MediaKind.movie);
      }
    });

    // Watched, so it's in the history the Profile shows.
    await container
        .read(mediaDetailsControllerProvider.notifier)
        .logMovieWatch(tmdbId: _movieId);

    openDetails(container, _movieId, 'movie');
    final bookmark = find.descendant(
      of: find.byType(DetailsHero),
      matching: find.byIcon(Icons.bookmark_border),
    );
    await pumpUntil(
      tester,
      () => bookmark.evaluate().isNotEmpty,
      what: 'the bookmark button',
    );
    await tester.tap(bookmark);
    var saved = false;
    for (var i = 0; i < 40 && !saved; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      saved = await inServerWatchlist();
    }
    expect(saved, isTrue, reason: 'the Watchlist row was saved');
    await pumpUntil(
      tester,
      () => find
          .descendant(
            of: find.byType(DetailsHero),
            matching: find.byIcon(Icons.bookmark),
          )
          .evaluate()
          .isNotEmpty,
      what: 'the filled bookmark',
    );

    // Profile → Overview: the movie in the recent movies.
    container.read(shellNavigatorKeyProvider).currentState!.pop();
    container.read(navIndexProvider.notifier).state = NavTab.profile;
    final l10n = AppLocalizations.of(tester.element(find.byType(AppShell)))!;
    await pumpUntil(
      tester,
      () => find
          .byWidgetPredicate((w) => w is MediaCard && w.tmdbId == _movieId)
          .evaluate()
          .isNotEmpty,
      what: 'the movie in the Profile history',
    );
    expect(find.text(l10n.profileRecentMovies.toUpperCase()), findsOneWidget);

    // Profile → Collections: the Watchlist holds it, the custom lists show.
    // The page opens scrolled below its tab bar (Profile scrolling: REV-239).
    final collectionsTab = find.text(
      l10n.profileCollections,
      skipOffstage: false,
    );
    await tester.ensureVisible(collectionsTab);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(collectionsTab);
    final watchlistCard = find.ancestor(
      of: find.text(l10n.listWatchLater),
      matching: find.byType(SystemListCard),
    );
    await pumpUntil(
      tester,
      () => watchlistCard.evaluate().isNotEmpty,
      what: 'the Watchlist card',
    );
    final watchlistSize = await client
        .from('list_items')
        .select('tmdb_id, lists!inner(type)')
        .eq('lists.type', 'watchlist');
    expect(
      find.descendant(
        of: watchlistCard,
        matching: find.text('${watchlistSize.length}'),
      ),
      findsOneWidget,
    );
    final customLists = await client
        .from('lists')
        .select('name')
        .eq('type', 'custom');
    for (final row in customLists) {
      expect(find.text(row['name'] as String), findsWidgets);
    }
  });
}
