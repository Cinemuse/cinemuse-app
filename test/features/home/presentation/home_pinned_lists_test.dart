import 'dart:async';

import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/home/presentation/home_screen.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/media_details_parts.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/application/pinned_list_ids_provider.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

class _FakeUserListsNotifier extends UserListsNotifier {
  _FakeUserListsNotifier(this._lists);
  final Stream<List<UserList>> _lists;

  @override
  Stream<List<UserList>> build() => _lists;
}

MediaItem _movie(int id, String title) => MediaItem(
  tmdbId: id,
  mediaType: MediaKind.movie,
  titleEn: title,
  titleIt: title,
  updatedAt: DateTime.utc(2026),
);

UserList _list(String id, String name, List<MediaItem> titles) => UserList(
  id: id,
  userId: 'user-a',
  name: name,
  type: ListType.custom,
  createdAt: DateTime.utc(2026),
  items: [
    for (final t in titles)
      UserListItem(
        listId: id,
        mediaType: t.mediaType,
        tmdbId: t.tmdbId,
        addedAt: DateTime.utc(2026),
        media: t,
      ),
  ],
);

Profile _profile(List<String> pins) => Profile(
  id: 'user-a',
  preferences: {PinnedListIdsNotifier.prefsKey: pins},
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

// Home's pinned rows follow the pins (live profile) and the lists wherever
// they change: on Home, on another tab, under a sheet or a pushed screen.
// Any "setState() called during build" while doing so fails the test.
void main() {
  late StreamController<Profile?> profile;
  late StreamController<List<UserList>> lists;
  final tab = ValueNotifier(0);

  setUp(() {
    profile = StreamController<Profile?>.broadcast();
    lists = StreamController<List<UserList>>.broadcast();
    tab.value = 0;
  });

  tearDown(() async {
    await profile.close();
    await lists.close();
  });

  /// Home offline (no TMDB rows) unless [tmdbRows] gives them.
  Future<void> pumpHome(
    WidgetTester tester, {
    Map<FutureProvider<List<MediaItem>>, List<MediaItem>>? tmdbRows,
    Map<MediaKind, List<MediaItem>> lovedSuggestions = const {},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          connectivityProvider.overrideWith(
            (ref) => Stream.value(
              tmdbRows == null
                  ? ConnectivityResult.none
                  : ConnectivityResult.wifi,
            ),
          ),
          if (tmdbRows != null) ...[
            for (final MapEntry(key: row, value: titles) in tmdbRows.entries)
              row.overrideWith((ref) async => titles),
            sportScheduleProvider.overrideWith((ref) async => []),
            shownWatchHistoryProvider.overrideWithValue(const AsyncData({})),
            allOwnReviewsProvider.overrideWith((ref) async => const {}),
            lovedSuggestionsProvider.overrideWith(
              (ref, kind) async => lovedSuggestions[kind] ?? const [],
            ),
          ],
          continueWatchingProvider.overrideWithValue(const AsyncData([])),
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          profileStreamProvider.overrideWith((ref) => profile.stream),
          userIdProvider.overrideWithValue('user-a'),
          userListsProvider.overrideWith(
            () => _FakeUserListsNotifier(lists.stream),
          ),
          collectionDetailsProvider.overrideWith(
            (ref, id) async => MediaCollection(
              id: id,
              name: 'Saga $id',
              parts: [_movie(id * 10, 'Saga part')],
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Like the app's tabs: Home stays alive while another tab shows.
          home: ValueListenableBuilder(
            valueListenable: tab,
            builder: (_, index, _) => IndexedStack(
              index: index,
              children: const [HomeScreen(), Text('Other tab')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('pinned rows follow pin and list changes without errors', (
    tester,
  ) async {
    await pumpHome(tester);

    profile.add(_profile(['horror', '${UserList.collectionIdPrefix}7']));
    lists.add([
      _list('horror', 'Horror', [_movie(1, 'Scream')]),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Horror'), findsOneWidget);
    expect(find.text('Saga 7'), findsOneWidget);

    // A pin made on another device arrives with the live profile.
    profile.add(_profile(['horror', 'comedy']));
    await tester.pumpAndSettle();
    expect(find.text('Saga 7'), findsNothing);

    lists.add([
      _list('horror', 'Horror', [_movie(1, 'Scream')]),
      _list('comedy', 'Comedy', [_movie(2, 'Airplane!')]),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Comedy'), findsOneWidget);

    // Both change in the same frame.
    profile.add(_profile(['comedy']));
    lists.add([
      _list('comedy', 'Comedy', [
        _movie(2, 'Airplane!'),
        _movie(3, 'Hot Shots'),
      ]),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Horror'), findsNothing);
    expect(find.text('Comedy'), findsOneWidget);
  });

  testWidgets('pins and lists changed on another tab show on return', (
    tester,
  ) async {
    await pumpHome(tester);
    profile.add(_profile(['horror']));
    lists.add([
      _list('horror', 'Horror', [_movie(1, 'Scream')]),
    ]);
    await tester.pumpAndSettle();

    tab.value = 1;
    await tester.pumpAndSettle();
    profile.add(
      _profile(['horror', 'comedy', '${UserList.collectionIdPrefix}7']),
    );
    lists.add([
      _list('horror', 'Horror', [_movie(1, 'Scream')]),
      _list('comedy', 'Comedy', [_movie(2, 'Airplane!')]),
    ]);
    await tester.pumpAndSettle();

    tab.value = 0;
    await tester.pumpAndSettle();
    expect(find.text('Comedy'), findsOneWidget);
    expect(find.text('Saga 7'), findsOneWidget);
  });

  testWidgets('pins and lists change while a list sheet is open over Home', (
    tester,
  ) async {
    await pumpHome(tester);
    profile.add(_profile(['horror']));
    lists.add([
      _list('horror', 'Horror', [_movie(1, 'Scream')]),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Horror'));
    await tester.pumpAndSettle();

    profile.add(_profile(['horror', 'comedy']));
    lists.add([
      _list('horror', 'Horror', [_movie(1, 'Scream')]),
      _list('comedy', 'Comedy', [_movie(2, 'Airplane!')]),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Comedy'), findsOneWidget);
  });

  testWidgets('pins and lists change under a screen opened over Home', (
    tester,
  ) async {
    await pumpHome(tester);
    profile.add(_profile(['horror']));
    lists.add([
      _list('horror', 'Horror', [_movie(1, 'Scream')]),
    ]);
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const Text('Details')),
      ),
    );
    await tester.pumpAndSettle();

    profile.add(_profile(['horror', 'comedy']));
    lists.add([
      _list('horror', 'Horror', [_movie(1, 'Scream'), _movie(3, 'Hot Shots')]),
      _list('comedy', 'Comedy', [_movie(2, 'Airplane!')]),
    ]);
    await tester.pumpAndSettle();

    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Comedy'), findsOneWidget);
  });

  testWidgets('online, the TMDB rows come in order under their headings', (
    tester,
  ) async {
    await pumpHome(
      tester,
      tmdbRows: {
        trendingProvider: [_movie(1, 'Hero one'), _movie(2, 'Trending two')],
        moviesInTheatersProvider: [_movie(3, 'In theaters')],
        newMoviesOnStreamingProvider: [_movie(4, 'On streaming')],
        newSeriesProvider: [_movie(5, 'New series')],
        topRatedRecentSeriesProvider: [_movie(6, 'Top rated')],
      },
    );
    await tester.pump();

    final headings = [
      'Trending Now',
      'Movies in Theaters',
      'New Movies on Streaming',
      'New Series',
      'Top-Rated Recent Series',
    ];
    final tops = [
      for (final heading in headings) tester.getTopLeft(find.text(heading)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('a loved film and a loved series get their "like X" rows after '
      'Trending; with no loved title there is none', (tester) async {
    final severance = MediaItem(
      tmdbId: 95396,
      mediaType: MediaKind.tv,
      titleEn: 'Severance',
      updatedAt: DateTime.utc(2026),
    );
    await pumpHome(
      tester,
      tmdbRows: {
        trendingProvider: [_movie(1, 'Hero one'), _movie(2, 'Trending two')],
        moviesInTheatersProvider: [_movie(3, 'In theaters')],
      },
      lovedSuggestions: {
        MediaKind.movie: [_movie(10, 'Arrival')],
        MediaKind.tv: [
          MediaItem(
            tmdbId: 20,
            mediaType: MediaKind.tv,
            titleEn: 'Silo',
            updatedAt: DateTime.utc(2026),
          ),
        ],
      },
    );
    lists.add([]);
    await tester.pumpAndSettle();
    expect(find.textContaining(' Like '), findsNothing);

    lists.add([
      UserList(
        id: 'fav',
        userId: 'user-a',
        name: 'Favorites',
        type: ListType.favorites,
        createdAt: DateTime.utc(2026),
        items: [
          for (final t in [_movie(438631, 'Dune'), severance])
            UserListItem(
              listId: 'fav',
              mediaType: t.mediaType,
              tmdbId: t.tmdbId,
              addedAt: DateTime.utc(2026),
              media: t,
            ),
        ],
      ),
    ]);
    await tester.pumpAndSettle();

    final headings = [
      'Trending Now',
      'Movies Like Dune',
      'Series Like Severance',
      'Movies in Theaters',
    ];
    final tops = [
      for (final heading in headings) tester.getTopLeft(find.text(heading)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Silo'), findsOneWidget);
  });
}
