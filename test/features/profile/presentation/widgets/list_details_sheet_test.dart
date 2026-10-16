import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_details_sheet.dart';
import 'package:cinemuse_app/features/search/application/search_provider.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/cursor_helpers.dart';
import '../../../../helpers/offline_lists.dart';

class MockTmdbService extends Mock implements TmdbService {}

class MockMediaRepository extends Mock implements MediaRepository {}

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

// REV-203: offline, a title added from the list's search stayed in the list
// with no message.
void main() {
  final l10n = AppLocalizationsEn();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('offline, + (search) on the Watchlist: a red message, '
      'the title is not in the list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...offlineListsOverrides(),
          tmdbServiceProvider.overrideWithValue(MockTmdbService()),
          userIdProvider.overrideWithValue('user-a'),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityResult.wifi),
          ),
          settingsProvider.overrideWith(FakeSettingsNotifier.new),
          searchProvider.overrideWith(
            (ref) =>
                SearchNotifier(ref, userId: 'user-a')
                  ..state = const SearchState(
                    query: 'Some',
                    status: SearchStatus.loaded,
                    results: [
                      {
                        'id': 1,
                        'title': 'Some Movie',
                        'media_type': 'movie',
                        'poster_path': null,
                        'vote_average': 7.0,
                      },
                    ],
                  ),
          ),
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
    await tester.tap(find.widgetWithText(MediaCard, 'Some Movie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.failureNetwork), findsOneWidget);
    expect(find.text('Some Movie'), findsNothing);
  });

  testWidgets('a title saved without its name gets it from TMDB (REV-191)', (
    tester,
  ) async {
    final listsOverrides = offlineListsOverrides();
    final tmdb = MockTmdbService();
    when(
      () => tmdb.getMediaDetails('1', 'movie'),
    ).thenAnswer((_) async => {'id': 1, 'title': 'Found Movie'});
    final media = MockMediaRepository();
    when(
      () => media.getMediaItem(1, MediaKind.movie),
    ).thenAnswer((_) async => null);
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
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...listsOverrides,
          tmdbServiceProvider.overrideWithValue(tmdb),
          mediaRepositoryProvider.overrideWithValue(media),
          userIdProvider.overrideWithValue('user-a'),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityResult.wifi),
          ),
          settingsProvider.overrideWith(FakeSettingsNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ListDetailsSheet(list: list)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Found Movie'), findsOneWidget);
    expect(find.text(l10n.commonUnknown), findsNothing);
  });

  // REV-277: the Dropped list had a ⋮ menu with Rename / Delete.
  group('the ⋮ menu (REV-277)', () {
    late List<String> updates;
    late int deletes;

    setUp(() {
      updates = [];
      deletes = 0;
    });

    // Opens the sheet the way Home and Collections do, always passing
    // Rename / Delete: the sheet itself must hide them on built-in lists.
    Future<void> openSheet(WidgetTester tester, UserList list) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
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
                    onUpdate: (name, description) => updates.add(name),
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

    for (final (type, id, name) in [
      (ListType.dropped, UserList.droppedId, 'Dropped'),
      (ListType.watchlist, 'watchlist', 'Watchlist'),
      (ListType.favorites, 'favorites', 'Favorites'),
    ]) {
      testWidgets('$name: no ⋮ menu', (tester) async {
        await openSheet(tester, listOf(type, id, name));

        expect(find.byType(ListDetailsSheet), findsOneWidget);
        expect(find.byTooltip(l10n.menuMoreOptions), findsNothing);
      });
    }

    testWidgets('a custom list: Rename saves the new name', (tester) async {
      await openSheet(tester, listOf(ListType.custom, 'my-list', 'My List'));

      await tester.tap(find.byTooltip(l10n.menuMoreOptions));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(l10n.detailsEditList));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(TextField).first, 'Best Films');
      await tester.tap(find.byTooltip(l10n.settingsSave));
      await tester.pump(const Duration(seconds: 1));

      expect(updates, ['Best Films']);
      expect(deletes, 0);
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
