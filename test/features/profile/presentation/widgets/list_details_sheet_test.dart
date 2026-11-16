import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/person_providers.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';
import 'package:cinemuse_app/features/media/domain/search_result.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_details_sheet.dart';
import 'package:cinemuse_app/features/search/application/search_provider.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/cursor_helpers.dart';
import '../../../../helpers/offline_lists.dart';
import '../../../../helpers/override_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class MockTmdbService extends Mock implements TmdbService {}

class MockMediaRepository extends Mock implements MediaRepository {}

class MockListsRepository extends Mock implements ListsRepository {}

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

/// TMDB's details answer [tmdb] as the app reads it.
MediaItem _details(String type, Map<String, dynamic> tmdb) =>
    MediaItem.fromTmdbDetails(tmdb, MediaItem.fromString(type));

// REV-203: offline, a title added from the list's search stayed in the list
// with no message.
void main() {
  final l10n = AppLocalizationsEn();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// The offline Watchlist with its + search open on a film and a person.
  Future<void> openListSearch(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          ...offlineListsOverrides(),
          tmdbServiceProvider.overrideWithValue(MockTmdbService()),
          userIdProvider.overrideWithValue('user-a'),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityResult.wifi),
          ),
          settingsProvider.overrideWith(FakeSettingsNotifier.new),
          // Keeps the person screen loading: no TMDB call in tests.
          personDetailsProvider.overrideWith(
            (ref, id) => Completer<PersonDetails?>().future,
          ),
          searchProvider.overrideWithBuild((ref, notifier) {
            notifier.build();
            return SearchState(
              query: 'Some',
              status: SearchStatus.loaded,
              results: [
                for (final result in [
                  {
                    'id': 1,
                    'title': 'Some Movie',
                    'media_type': 'movie',
                    'poster_path': null,
                    'vote_average': 7.0,
                  },
                  {
                    'id': 287,
                    'name': 'Some Actor',
                    'media_type': 'person',
                    'known_for_department': 'Acting',
                  },
                ])
                  SearchResult.fromTmdbMap(result),
              ],
            );
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ListDetailsSheet(list: offlineWatchlist)),
        ),
      ),
    );
    // Not pumpAndSettle: the empty list's animation never settles.
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byTooltip(l10n.searchPlaceholder));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('offline, + (search) on the Watchlist: a red message, '
      'the title is not in the list', (tester) async {
    await openListSearch(tester);
    await tester.tap(find.widgetWithText(MediaCard, 'Some Movie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.failureNetwork), findsOneWidget);
    expect(find.text('Some Movie'), findsNothing);
  });

  // A person picked there was added as the film with the person's number.
  testWidgets('+ (search): a person opens their page and is not added to '
      'the list', (tester) async {
    await openListSearch(tester);
    await tester.tap(find.widgetWithText(MediaCard, 'Some Actor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final screen = tester.widget<PersonDetailsScreen>(
      find.byType(PersonDetailsScreen),
    );
    expect(screen.personId, 287);
    // Any add fails offline with this message.
    expect(find.text(l10n.failureNetwork), findsNothing);
  });

  // REV-270: a title cached from the server's media_cache (no rating) showed
  // no rating or year until its page was opened.
  final cachedWithoutRating = MediaItem(
    tmdbId: 1,
    mediaType: MediaKind.movie,
    titleEn: 'Found Movie',
    updatedAt: DateTime.utc(2026),
  );
  for (final (name, cached, expected) in [
    (
      'a title saved without its name gets it from TMDB (REV-191)',
      null,
      ['Found Movie'],
    ),
    (
      'a title cached without its rating gets rating and year from TMDB '
          '(REV-270)',
      cachedWithoutRating,
      ['Found Movie', '7.4', '2001'],
    ),
  ]) {
    testWidgets(name, (tester) async {
      await _pumpListWithOneTitle(tester, cached);

      for (final text in expected) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text(l10n.commonUnknown), findsNothing);
    });
  }

  Future<void> removeTheTitle(WidgetTester tester) async {
    await _pumpListWithOneTitle(
      tester,
      MediaItem(
        tmdbId: 1,
        mediaType: MediaKind.movie,
        titleEn: 'Found Movie',
        voteAverage: 7.4,
        updatedAt: DateTime.utc(2026),
      ),
    );

    await tester.tap(find.byTooltip(l10n.menuMoreOptions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.menuRemoveFromList));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  // A title taken out of a list had no Undo.
  testWidgets('Remove from List on a card: the title goes at once, with '
      'Undo; Undo brings it back', (tester) async {
    await removeTheTitle(tester);

    expect(find.text('Found Movie'), findsNothing);
    expect(
      find.textContaining(l10n.listTitleRemoved('Found Movie')),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.commonUndo));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Found Movie'), findsOneWidget);
    expect(find.text(l10n.failureNetwork), findsNothing);
  });

  // REV-89: a failed removal was silent.
  testWidgets('offline, Remove from List on a card: once Undo is gone, a red '
      'message and the title back', (tester) async {
    await removeTheTitle(tester);

    await tester.pump(AppSnackBar.undoDuration);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(l10n.failureNetwork), findsOneWidget);
    expect(find.text('Found Movie'), findsOneWidget);
  });

  // REV-277: the Dropped list had a ⋮ menu with Rename / Delete.
  group('the ⋮ menu (REV-277)', () {
    late List<String> updates;
    late int deletes;
    late bool isRenameSaved;

    setUp(() {
      updates = [];
      deletes = 0;
      isRenameSaved = true;
    });

    // Opens the sheet the way Home and Collections do, always passing
    // Rename / Delete: the sheet itself must hide them on built-in lists.
    Future<void> openSheet(WidgetTester tester, UserList list) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            ...offlineListsOverrides(),
            tmdbServiceProvider.overrideWithValue(MockTmdbService()),
            userIdProvider.overrideWithValue('user-a'),
            connectivityProvider.overrideWith(
              (ref) => Stream.value(ConnectivityResult.wifi),
            ),
            settingsProvider.overrideWith(FakeSettingsNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => ListDetailsSheet.show(
                    context,
                    list: list,
                    onUpdate: (name, description) async {
                      updates.add(name);
                      return isRenameSaved;
                    },
                    onDelete: () => deletes++,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      // Not pumpAndSettle: the empty list's animation never settles.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    UserList listOf(ListType type, String id, String name) => UserList(
      id: id,
      userId: 'user-a',
      name: name,
      type: type,
      createdAt: DateTime.utc(2026),
    );

    // Home never shows Dropped, so its sheet has no pin (REV-311).
    for (final (type, id, name, pin) in [
      (ListType.dropped, UserList.droppedId, 'Dropped', findsNothing),
      (ListType.watchlist, 'watchlist', 'Watchlist', findsOneWidget),
      (ListType.favorites, 'favorites', 'Favorites', findsOneWidget),
    ]) {
      testWidgets('$name: no ⋮ menu, pin button only if not Dropped', (
        tester,
      ) async {
        await openSheet(tester, listOf(type, id, name));

        expect(find.byType(ListDetailsSheet), findsOneWidget);
        expect(find.byTooltip(l10n.menuMoreOptions), findsNothing);
        expect(find.byTooltip(l10n.listPinToHome), pin);
      });
    }

    Future<void> rename(WidgetTester tester, String name) async {
      await openSheet(tester, listOf(ListType.custom, 'my-list', 'My List'));
      await tester.tap(find.byTooltip(l10n.menuMoreOptions));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(l10n.detailsEditList));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(TextField).first, name);
      await tester.tap(find.byTooltip(l10n.settingsSave));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a custom list: Rename saves the new name', (tester) async {
      await rename(tester, 'Best Films');

      expect(updates, ['Best Films']);
      expect(deletes, 0);
      expect(find.byTooltip(l10n.settingsSave), findsNothing);
    });

    // REV-89: a rename that wasn't saved closed the boxes as if saved.
    testWidgets('a custom list: a rename not saved keeps the typed name '
        'open', (tester) async {
      isRenameSaved = false;
      await rename(tester, 'Best Films');

      expect(updates, ['Best Films']);
      expect(find.byTooltip(l10n.settingsSave), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Best Films'), findsOneWidget);
    });

    // REV-246: the sheet's top-right icons showed the arrow cursor.
    testWidgets('a custom list: the top-right icons and the menu options '
        'show the hand (REV-246)', (tester) async {
      await openSheet(tester, listOf(ListType.custom, 'my-list', 'My List'));

      await expectHandOver(tester, find.byTooltip(l10n.listPinToHome));
      await expectHandOver(tester, find.byTooltip(l10n.menuMoreOptions));
      await tester.tap(find.byTooltip(l10n.menuMoreOptions));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await expectHandOver(tester, find.text(l10n.detailsEditList));
    });

    testWidgets('a custom list: Delete closes the sheet and deletes it', (
      tester,
    ) async {
      await openSheet(tester, listOf(ListType.custom, 'my-list', 'My List'));

      await tester.tap(find.byTooltip(l10n.menuMoreOptions));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(l10n.detailsDeleteList));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(deletes, 1);
      expect(updates, isEmpty);
      expect(find.byType(ListDetailsSheet), findsNothing);
    });
  });
}

// A custom list holding movie 1, [cached] as its local details. TMDB knows
// it as "Found Movie" (2001, rated 7.4); the local cache has [cached].
Future<void> _pumpListWithOneTitle(
  WidgetTester tester,
  MediaItem? cached,
) async {
  final tmdb = MockTmdbService();
  when(() => tmdb.getMediaDetails('1', 'movie')).thenAnswer(
    (_) async => _details('movie', {
      'id': 1,
      'title': 'Found Movie',
      'release_date': '2001-05-01',
      'vote_average': 7.4,
    }),
  );
  final media = MockMediaRepository();
  when(
    () => media.getMediaItem(1, MediaKind.movie),
  ).thenAnswer((_) async => cached);
  when(() => media.saveMediaItem(any())).thenAnswer((_) async {});
  final list = UserList(
    id: 'my-list',
    userId: 'user-a',
    name: 'My List',
    type: ListType.custom,
    createdAt: DateTime.utc(2026),
    items: [
      UserListItem(
        listId: 'my-list',
        mediaType: MediaKind.movie,
        tmdbId: 1,
        addedAt: DateTime.utc(2026),
        media: cached,
      ),
    ],
  );
  // The saved lists hold this one, so the sheet follows its changes; every
  // removal fails as if offline.
  final lists = MockListsRepository();
  when(() => lists.syncUserLists(any())).thenAnswer((_) async {});
  when(
    () => lists.watchUserLists(any()),
  ).thenAnswer((_) => Stream.value([list]));
  when(
    () => lists.removeItemFromList(
      listId: any(named: 'listId'),
      tmdbId: any(named: 'tmdbId'),
      mediaType: any(named: 'mediaType'),
    ),
  ).thenThrow(const NetworkFailure('offline'));
  await tester.pumpWidget(
    ProviderScope(
      retry: noProviderRetry,
      overrides: withOwnOverrides(offlineListsOverrides(), [
        listsRepositoryProvider.overrideWithValue(lists),
        tmdbServiceProvider.overrideWithValue(tmdb),
        mediaRepositoryProvider.overrideWithValue(media),
        userIdProvider.overrideWithValue('user-a'),
        connectivityProvider.overrideWith(
          (ref) => Stream.value(ConnectivityResult.wifi),
        ),
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
      ]),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ListDetailsSheet(list: list)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
