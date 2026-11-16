import 'dart:async';

import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/application/title_marks_provider.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/data/lists_repository.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/shared/widgets/card_marks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:cinemuse_app/features/profile/presentation/widgets/title_list_actions.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_font.dart';
import '../../helpers/menu_helpers.dart';
import '../../helpers/offline_lists.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

// REV-203: offline, "Add to Watchlist" from a card's menu failed silently.
void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('offline "Add to Watchlist": a red message, not added', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: offlineListsOverrides(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(child: SizedBox(width: 160, child: _MovieCard())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(MediaCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.menuAddToWatchlist));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.failureNetwork), findsOneWidget);

    // The menu still offers to add it: it isn't in the Watchlist.
    await tester.longPress(find.byType(MediaCard));
    await tester.pumpAndSettle();
    expect(find.text(l10n.menuAddToWatchlist), findsOneWidget);
  });

  // REV-253: the card's ⋮ button has a tooltip in the app's language.
  for (final (locale, l10n) in [
    (const Locale('en'), AppLocalizationsEn()),
    (const Locale('it'), AppLocalizationsIt()),
  ]) {
    testWidgets('⋮ tooltip in ${locale.languageCode}', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: offlineListsOverrides(),
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Center(child: SizedBox(width: 160, child: _MovieCard())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.menuMoreOptions), findsOneWidget);
    });
  }

  testWidgets('right-click: the menu opens at the pointer (REV-248)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: offlineListsOverrides(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment(0.5, -0.9),
              child: SizedBox(width: 160, child: _MovieCard()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final at = tester.getCenter(find.byType(MediaCard));
    await rightClickAt(tester, at);
    expect(find.text(l10n.menuAddToWatchlist), findsOneWidget);
    expectMenuAt(tester, at);
  });

  group('marks', () {
    setUpAll(loadAppFont);

    Future<void> pumpCard(WidgetTester tester, CardMarks marks) =>
        tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                // A phone with three posters per row.
                child: SizedBox(
                  width: 100,
                  height: 200,
                  child: MediaCard(
                    title: 'Some Movie',
                    rating: 8.5,
                    releaseDate: '2024-03-01',
                    marks: marks,
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('watched and rated: the tick, then the score', (tester) async {
      await pumpCard(
        tester,
        const CardMarks(
          isWatched: true,
          ownScore: 8,
          isWatchlisted: true,
          isFavorite: true,
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      final tick = tester.getCenter(find.byIcon(Icons.check));
      expect(tick.dx, lessThan(tester.getCenter(find.text('8')).dx));
      // In the top-left corner of the poster.
      final card = tester.getRect(find.byType(MediaCard));
      expect(tick.dx, lessThan(card.left + 20));
      expect(tick.dy, lessThan(card.top + 20));
      // A screen reader says it in words, not "check, wreath, 8".
      expect(
        tester.getSemantics(find.byType(CardMarksBadge)).label,
        contains('${l10n.detailsWatched}, ${l10n.ownReviewScoreLabel(8)}'),
      );

      // Under the poster, on the score and year's line, at its right end.
      final bookmark = tester.getRect(find.byIcon(Icons.bookmark));
      final heart = tester.getRect(find.byIcon(Icons.favorite));
      expect(bookmark.center.dy, tester.getCenter(find.text('2024')).dy);
      expect(heart.left, greaterThan(bookmark.right));
      expect(heart.right, closeTo(card.right, 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('rated but not finished: only the score', (tester) async {
      await pumpCard(tester, const CardMarks(ownScore: 6));

      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('nothing of yours: no patch, no icons', (tester) async {
      await pumpCard(tester, CardMarks.none);

      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.bookmark), findsNothing);
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.text('2024'), findsOneWidget);
    });
  });

  group('the Watchlist message', () {
    late StreamController<List<UserList>> lists;
    late _MockListsRepository repo;

    setUp(() {
      lists = StreamController<List<UserList>>.broadcast();
      repo = _MockListsRepository();
    });
    tearDown(() => lists.close());

    Future<void> pumpCard(WidgetTester tester, {required bool listed}) async {
      var current = _watchlist(listed: listed);
      when(() => repo.syncUserLists(any())).thenAnswer((_) async {});
      when(() => repo.watchUserLists(any())).thenAnswer(
        (_) => Stream.multi((c) {
          c.add(current);
          c.addStream(lists.stream);
        }),
      );
      void emit(bool isListed) {
        current = _watchlist(listed: isListed);
        lists.add(current);
      }

      when(
        () => repo.addItemToList(
          listId: any(named: 'listId'),
          tmdbId: any(named: 'tmdbId'),
          mediaType: any(named: 'mediaType'),
        ),
      ).thenAnswer((_) async => emit(true));
      when(
        () => repo.removeItemFromList(
          listId: any(named: 'listId'),
          tmdbId: any(named: 'tmdbId'),
          mediaType: any(named: 'mediaType'),
        ),
      ).thenAnswer((_) async => emit(false));
      final media = _MockMediaRepository();
      when(
        () => media.getMediaItem(any(), any()),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            authProvider.overrideWithBuild(
              (ref, notifier) => AsyncData(
                User(
                  id: 'user-a',
                  appMetadata: {},
                  userMetadata: {},
                  aud: '',
                  createdAt: '',
                ),
              ),
            ),
            listsRepositoryProvider.overrideWithValue(repo),
            mediaRepositoryProvider.overrideWithValue(media),
            watchHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
            allOwnReviewsProvider.overrideWith((ref) async => {}),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(width: 160, height: 300, child: _MarkedCard()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUpAll(() {
      registerFallbackValue(MediaKind.movie);
    });

    testWidgets('added: a message without Undo, the bookmark shows', (
      tester,
    ) async {
      await pumpCard(tester, listed: false);
      expect(find.byIcon(Icons.bookmark), findsNothing);

      await tester.longPress(find.byType(MediaCard));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.menuAddToWatchlist));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(l10n.watchlistAdded), findsOneWidget);
      expect(find.text(l10n.commonUndo), findsNothing);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('removed: a message with Undo, which keeps it', (tester) async {
      await pumpCard(tester, listed: true);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);

      await tester.longPress(find.byType(MediaCard));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.menuRemoveFromWatchlist));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining(l10n.watchlistRemoved), findsOneWidget);
      // Gone from the poster while the message counts down.
      expect(find.byIcon(Icons.bookmark), findsNothing);

      await tester.tap(find.text(l10n.commonUndo));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      verifyNever(
        () => repo.removeItemFromList(
          listId: any(named: 'listId'),
          tmdbId: any(named: 'tmdbId'),
          mediaType: any(named: 'mediaType'),
        ),
      );
    });
  });
}

class _MockListsRepository extends Mock implements ListsRepository {}

class _MockMediaRepository extends Mock implements MediaRepository {}

final _someMovie = MediaItem(
  tmdbId: 1,
  mediaType: MediaKind.movie,
  titleEn: 'Some Movie',
  updatedAt: DateTime(2026),
);

List<UserList> _watchlist({required bool listed}) => [
  UserList(
    id: 'watchlist',
    userId: 'user-a',
    name: 'Watchlist',
    type: ListType.watchlist,
    createdAt: DateTime.utc(2026),
    items: [
      if (listed)
        UserListItem(
          listId: 'watchlist',
          mediaType: MediaKind.movie,
          tmdbId: 1,
          addedAt: DateTime.utc(2026),
        ),
    ],
  ),
];

/// A movie card with its menu and its marks, as the app's screens wire it.
class _MarkedCard extends ConsumerWidget {
  const _MarkedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MediaCard(
    title: 'Some Movie',
    releaseDate: '2024',
    listActions: TitleListActions(context, ref, _someMovie),
    marks: ref.watch(
      titleMarksProvider((
        tmdbId: 1,
        mediaType: MediaKind.movie,
        place: MarksPlace.anywhere,
      )),
    ),
  );
}

/// A movie card wired to the real lists, as the app's screens wire it.
class _MovieCard extends ConsumerWidget {
  const _MovieCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MediaCard(
    title: 'Some Movie',
    listActions: TitleListActions(
      context,
      ref,
      MediaItem(
        tmdbId: 1,
        mediaType: MediaKind.movie,
        titleEn: 'Some Movie',
        updatedAt: DateTime(2026),
      ),
    ),
  );
}
