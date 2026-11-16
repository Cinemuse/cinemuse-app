import 'dart:async';

import 'package:cinemuse_app/core/application/locale_service.dart';
import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/data/comments_repository_provider.dart';
import 'package:cinemuse_app/features/media/data/own_reviews_repository.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/comments_bottom_sheet.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/own_review_editor.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/own_review_tile.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/app_font.dart';
import '../../../../helpers/cursor_helpers.dart';
import '../../../../helpers/focus_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class MockCommentsRepository extends Mock implements CommentsRepository {}

/// The series review site's name, as the server's list gives it.
final _seriesSite = serverAddressesProvider.overrideWith(
  (ref) async => ServerAddresses.fromRows([
    {
      'key': ServerAddress.reviews.key,
      'address': 'https://reviews.example',
      'display_name': 'Series Site',
    },
  ]),
);

// REV-201: offline, the sheet showed the raw "Exception: …" text.
void main() {
  setUpAll(loadAppFont);

  const request = EpisodeCommentsRequest(
    tmdbShowId: 100,
    seasonNumber: 1,
    episodeNumber: 1,
  );

  for (final (locale, l10n) in [
    (const Locale('en'), AppLocalizationsEn()),
    (const Locale('it'), AppLocalizationsIt()),
  ]) {
    testWidgets('offline (${locale.languageCode}): a short translated '
        '"no connection" text', (tester) async {
      final repository = MockCommentsRepository();
      when(
        () => repository.fetchComments(request, page: any(named: 'page')),
      ).thenThrow(const NetworkFailure('offline'));

      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            commentsRepositoryProvider.overrideWithValue(repository),
            _seriesSite,
            // The app language, as the app sets it (error texts follow it).
            localeProvider.overrideWithBuild(
              (ref, notifier) => Locale(locale.languageCode),
            ),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: CommentsBottomSheet(request: request)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(l10n.tvTimeCommentsError), findsOneWidget);
      expect(find.textContaining(l10n.failureNetwork), findsOneWidget);
      expect(find.textContaining('offline'), findsNothing);
      expect(find.textContaining('Failure'), findsNothing);
    });

    // REV-209: the "Load more" button is in the app's language.
    testWidgets('more pages (${locale.languageCode}): a translated '
        '"Load more" button', (tester) async {
      final repository = MockCommentsRepository();
      // One comment per page, a new one on every page: there is always more.
      when(
        () => repository.fetchComments(request, page: any(named: 'page')),
      ).thenAnswer((invocation) async {
        final page = invocation.namedArguments[#page] as int;
        return [
          Comment(
            id: 'c$page',
            author: const CommentAuthor(id: 'u1', username: 'alice'),
            text: 'Comment $page',
            createdAt: DateTime.utc(2024),
            source: CommentSource.seriesReviews,
          ),
        ];
      });

      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            commentsRepositoryProvider.overrideWithValue(repository),
            _seriesSite,
            localeProvider.overrideWithBuild(
              (ref, notifier) => Locale(locale.languageCode),
            ),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: CommentsBottomSheet(request: request)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.commentsLoadMore), findsOneWidget);
      // The review's label (in capitals) and the filter use the name from
      // the list.
      expect(find.text('SERIES SITE'), findsWidgets);
      await tester.tap(find.byIcon(Icons.layers_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Series Site'), findsOneWidget);
    });
  }

  // REV-20: on a wide window the sheet is 600 px wide with the filters beside
  // the title; on a phone it fills the width with the filters under it.
  for (final (width, isPhone) in const [(400.0, true), (1280.0, false)]) {
    testWidgets('${width}px window: ${isPhone ? 'phone' : 'wide'} sheet', (
      tester,
    ) async {
      final l10n = AppLocalizationsEn();
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = MockCommentsRepository();
      when(
        () => repository.fetchComments(request, page: any(named: 'page')),
      ).thenAnswer(
        (_) async => [
          Comment(
            id: 'c1',
            author: const CommentAuthor(id: 'u1', username: 'alice'),
            text: 'Great episode',
            createdAt: DateTime.utc(2024),
            source: CommentSource.seriesReviews,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            commentsRepositoryProvider.overrideWithValue(repository),
            _seriesSite,
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showCommentsBottomSheet(context, request),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(CommentsBottomSheet)).width,
        isPhone ? width : 600,
      );
      final title = tester.getCenter(find.text(l10n.detailsTvTimeComments));
      final filter = tester.getCenter(find.byIcon(Icons.layers_outlined));
      if (isPhone) {
        expect(filter.dy, greaterThan(title.dy + 20));
      } else {
        expect(filter.dy, moreOrLessEquals(title.dy, epsilon: 4));
      }
    });
  }

  // REV-209: a source filter only hid the loaded comments, and more pages
  // loaded only on scroll, so a filtered list said "No comments" for good.
  group('source filter (REV-209)', () {
    final l10n = AppLocalizationsEn();

    Comment comment(String text, CommentSource source) => Comment(
      id: text,
      author: const CommentAuthor(id: 'u1', username: 'alice'),
      text: text,
      createdAt: DateTime.utc(2024),
      source: source,
    );
    List<Comment> seriesReviews(int page) => [
      for (var i = 1; i <= 6; i++)
        comment('Show review $page.$i', CommentSource.seriesReviews),
    ];

    Future<void> pumpSheet(
      WidgetTester tester,
      Map<int, List<Comment>> pages,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = MockCommentsRepository();
      when(
        () => repository.fetchComments(request, page: any(named: 'page')),
      ).thenAnswer(
        (call) async => pages[call.namedArguments[#page] as int] ?? const [],
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            commentsRepositoryProvider.overrideWithValue(repository),
            _seriesSite,
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: CommentsBottomSheet(request: request)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.layers_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commentsSourceImdb).last);
      await tester.pumpAndSettle();
    }

    testWidgets('IMDb: its comments from later pages show, then "Load more" '
        'works with Enter', (tester) async {
      await pumpSheet(tester, {
        1: seriesReviews(1),
        2: seriesReviews(2),
        3: [
          comment('IMDb 1', CommentSource.imdb),
          comment('IMDb 2', CommentSource.imdb),
        ],
        4: [comment('IMDb 3', CommentSource.imdb)],
        5: seriesReviews(5),
        6: [comment('IMDb 4', CommentSource.imdb)],
      });

      for (final text in ['IMDb 1', 'IMDb 2', 'IMDb 3']) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.textContaining('Show review'), findsNothing);
      expect(find.text(l10n.tvTimeNoComments), findsNothing);
      expect(find.text('IMDb 4'), findsNothing);

      final loadMore = find.text(l10n.commentsLoadMore);
      expect(loadMore, findsOneWidget);
      // At the bottom, under the last comment.
      expect(
        tester.getTopLeft(loadMore).dy,
        greaterThan(tester.getBottomLeft(find.text('IMDb 3')).dy),
      );
      await tabTo(tester, loadMore);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('IMDb 4'), findsOneWidget);
    });

    testWidgets('a source with no comments: "No comments yet." once the '
        'pages ran out', (tester) async {
      await pumpSheet(tester, {1: seriesReviews(1), 2: seriesReviews(2)});

      expect(find.text(l10n.tvTimeNoComments), findsOneWidget);
      expect(find.text(l10n.commentsLoadMore), findsNothing);
      expect(find.textContaining('Show review'), findsNothing);
    });
  });

  // REV-210: tiles were kept alive only to remember a revealed spoiler; now
  // the sheet remembers it, for as long as it is open.
  testWidgets('a revealed spoiler stays revealed as more pages load; '
      'reopened, it is hidden again (REV-210)', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockCommentsRepository();
    when(
      () => repository.fetchComments(request, page: any(named: 'page')),
    ).thenAnswer((call) async {
      final page = call.namedArguments[#page] as int;
      if (page > 5) return const [];
      return [
        if (page == 1)
          Comment(
            id: 'spoiler',
            author: const CommentAuthor(id: 'u1', username: 'alice'),
            text: 'Big twist',
            isSpoiler: true,
            createdAt: DateTime.utc(2024),
            source: CommentSource.seriesReviews,
          ),
        for (var i = 1; i <= 6; i++)
          Comment(
            id: 'c$page.$i',
            author: const CommentAuthor(id: 'u1', username: 'alice'),
            text: 'Comment $page.$i',
            createdAt: DateTime.utc(2024),
            source: CommentSource.seriesReviews,
          ),
      ];
    });
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          commentsRepositoryProvider.overrideWithValue(repository),
          _seriesSite,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCommentsBottomSheet(context, request),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    final l10n = AppLocalizationsEn();
    final list = find.descendant(
      of: find.byType(CommentsBottomSheet),
      matching: find.byType(Scrollable),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Big twist'), findsNothing);
    await tester.tap(find.text(l10n.commentsSpoilerWarning));
    await tester.pumpAndSettle();
    expect(find.text('Big twist'), findsOneWidget);

    // Down to the last page (the spoiler's tile scrolls away), then back up.
    await tester.scrollUntilVisible(
      find.text('Comment 5.6'),
      500,
      scrollable: list.first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Big twist'), findsNothing);
    await tester.drag(list.first, const Offset(0, 100000));
    await tester.pumpAndSettle();
    expect(find.text('Big twist'), findsOneWidget);
    expect(find.text(l10n.commentsSpoilerWarning), findsNothing);

    // Closed and opened again: hidden.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(CommentsBottomSheet), findsNothing);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.commentsSpoilerWarning), findsOneWidget);
    expect(find.text('Big twist'), findsNothing);
  });

  // REV-246: the two filters (source and order) showed the arrow cursor.
  testWidgets('the source and order filters: the hand', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockCommentsRepository();
    when(
      () => repository.fetchComments(request, page: any(named: 'page')),
    ).thenAnswer(
      (_) async => [
        Comment(
          id: 'c1',
          author: const CommentAuthor(id: 'u1', username: 'alice'),
          text: 'Nice episode',
          createdAt: DateTime.utc(2024),
          source: CommentSource.imdb,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          commentsRepositoryProvider.overrideWithValue(repository),
          _seriesSite,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: CommentsBottomSheet(request: request)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nice episode'), findsOneWidget);
    await expectHandOver(tester, find.byIcon(Icons.layers_outlined));
    await expectHandOver(tester, find.byIcon(Icons.sort));
  });

  // On the TV the filters showed no ring, and the comments were no stops:
  // the remote couldn't scroll through them.
  testWidgets('every stop shows the ring; Down goes from comment to comment, '
      'Enter reveals a spoiler', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FocusRing.debugWatchKeys();
    final repository = MockCommentsRepository();
    when(
      () => repository.fetchComments(request, page: any(named: 'page')),
    ).thenAnswer((call) async {
      if (call.namedArguments[#page] as int > 1) return const [];
      return [
        for (var i = 1; i <= 3; i++)
          Comment(
            id: 'c$i',
            author: const CommentAuthor(id: 'u1', username: 'alice'),
            text: 'Comment $i',
            isSpoiler: i == 3,
            createdAt: DateTime.utc(2024),
            source: CommentSource.imdb,
          ),
      ];
    });
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          commentsRepositoryProvider.overrideWithValue(repository),
          _seriesSite,
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: CommentsBottomSheet(request: request)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(await stopsWithoutRing(tester), isEmpty);

    await tabTo(tester, find.text('Comment 1'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(isFocused(find.text('Comment 2')), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('Comment 3'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Comment 3'), findsOneWidget);
  });

  // On the Fire Stick Up got stuck on a comment taller than the screen:
  // Down had shown its end, and the comment above was then too far to be
  // built.
  testWidgets('a comment taller than the screen: Down shows its start and '
      'scrolls through it, Up goes back to the filters', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockCommentsRepository();
    when(
      () => repository.fetchComments(request, page: any(named: 'page')),
    ).thenAnswer((call) async {
      if (call.namedArguments[#page] as int > 1) return const [];
      return [
        for (var i = 1; i <= 4; i++)
          Comment(
            id: 'c$i',
            author: const CommentAuthor(id: 'u1', username: 'alice'),
            text: 'Comment $i ${'and more words ' * (i == 2 ? 300 : 3)}',
            createdAt: DateTime.utc(2024),
            source: CommentSource.imdb,
          ),
      ];
    });
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          commentsRepositoryProvider.overrideWithValue(repository),
          _seriesSite,
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: CommentsBottomSheet(request: request)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byType(CommentsBottomSheet),
      matching: find.byType(Scrollable),
    );
    final listTop = tester.getTopLeft(list).dy;
    final longComment = find.textContaining('Comment 2 ');
    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    await tabTo(tester, find.textContaining('Comment 1 '));
    await press(LogicalKeyboardKey.arrowDown);
    expect(isFocused(longComment), isTrue);
    expect(tester.getTopLeft(longComment).dy, greaterThan(listTop));

    // Down scrolls through it, then moves on.
    var presses = 0;
    while (isFocused(longComment)) {
      final top = tester.getTopLeft(longComment).dy;
      await press(LogicalKeyboardKey.arrowDown);
      if (isFocused(longComment)) {
        expect(tester.getTopLeft(longComment).dy, lessThan(top));
      }
      expect(++presses, lessThan(20));
    }
    expect(presses, greaterThan(2));
    expect(isFocused(find.textContaining('Comment 3 ')), isTrue);

    // Up all the way back, to the source filter.
    for (
      var i = 0;
      i < 20 && !isFocused(find.byIcon(Icons.layers_outlined));
      i++
    ) {
      await press(LogicalKeyboardKey.arrowUp);
    }
    expect(isFocused(find.byIcon(Icons.layers_outlined)), isTrue);
  });

  group('your own review', () {
    final l10n = AppLocalizationsEn();
    const title = (tmdbId: 438631, mediaType: MediaKind.movie);
    const reviewsRequest = MediaReviewsRequest(
      tmdbId: 438631,
      mediaType: MediaKind.movie,
    );
    final watch = WatchLog(
      tmdbId: title.tmdbId,
      mediaType: title.mediaType,
      loggedAt: DateTime.utc(2026, 1, 1),
    );
    final saved = OwnReview(
      tmdbId: title.tmdbId,
      mediaType: title.mediaType,
      rating: 9,
      text: 'My own words',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    final outsideReview = Comment(
      id: 'c1',
      author: const CommentAuthor(id: 'u1', username: 'alice'),
      text: 'An outside review',
      createdAt: DateTime.utc(2024),
      source: CommentSource.imdb,
    );

    late _MockOwnReviews reviews;
    late MockCommentsRepository comments;

    final addButton = find.text(l10n.ownReviewAdd);
    final editButton = find.text(l10n.ownReviewEdit);
    final notWatchedLine = find.text(l10n.ownReviewNotWatched);
    final saveButton = find.text(l10n.ownReviewSave);
    final cancelButton = find.text(l10n.commonCancel);
    final removeButton = find.text(l10n.ownReviewRemove);
    final reviewBox = find.byType(TextField);
    final ownTile = find.text('My own words');

    bool isOnSlider() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<Slider>() !=
        null;

    bool isTyping() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;

    int bigWreathScore(WidgetTester tester) =>
        tester.widget<Wreath>(find.byType(Wreath)).score;

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    setUpAll(() {
      registerFallbackValue(title);
      registerFallbackValue(saved);
      registerFallbackValue(reviewsRequest);
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      reviews = _MockOwnReviews();
      comments = MockCommentsRepository();
      when(() => reviews.get(any(), any())).thenAnswer((_) async => null);
      when(
        () => reviews.save(
          any(),
          any(),
          rating: any(named: 'rating'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((call) async {
        return OwnReview(
          tmdbId: title.tmdbId,
          mediaType: title.mediaType,
          rating: call.namedArguments[#rating] as int,
          text: call.namedArguments[#text] as String?,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 2),
        );
      });
      when(() => reviews.remove(any(), any())).thenAnswer((_) async {});
      when(() => reviews.restore(any(), any())).thenAnswer((_) async {});
      when(
        () => comments.fetchComments(any(), page: any(named: 'page')),
      ).thenAnswer((call) async {
        return call.namedArguments[#page] == 1 ? [outsideReview] : const [];
      });
    });

    /// Opens the sheet of a real title, in the app's own message host.
    Future<void> openSheet(
      WidgetTester tester, {
      Size size = const Size(1280, 900),
      Locale locale = const Locale('en'),
      List<WatchLog>? logs,
      CommentsRequest request = reviewsRequest,
      bool settle = true,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: noProviderRetry,
          overrides: [
            commentsRepositoryProvider.overrideWithValue(comments),
            _seriesSite,
            userIdProvider.overrideWithValue('me'),
            ownReviewsRepositoryProvider.overrideWithValue(reviews),
            movieWatchLogsProvider.overrideWith2(
              (id) => _FakeMovieLogs(id, logs ?? [watch]),
            ),
            seriesWatchLogsProvider.overrideWith2(
              (id) => _FakeSeriesLogs(id, logs ?? [watch]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => AppSnackBarHost(child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showCommentsBottomSheet(context, request),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
    }

    Future<void> openEditor(WidgetTester tester, Finder button) async {
      await tabTo(tester, button);
      await press(tester, LogicalKeyboardKey.enter);
    }

    group('what shows under the title', () {
      testWidgets('an episode\'s reviews: none of this', (tester) async {
        await openSheet(tester, request: request);

        expect(addButton, findsNothing);
        expect(notWatchedLine, findsNothing);
        expect(find.byType(Wreath), findsNothing);
      });

      testWidgets('not watched yet: the line and an empty wreath, which the '
          'remote skips', (tester) async {
        await openSheet(tester, logs: const []);

        expect(notWatchedLine, findsOneWidget);
        expect(bigWreathScore(tester), 0);
        expect(addButton, findsNothing);
        for (var i = 0; i < 8; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(isFocused(notWatchedLine), isFalse);
          expect(isFocused(find.byType(Wreath)), isFalse);
        }
      });

      testWidgets('watched and not rated: "Add a review", and no review of '
          'yours in the list', (tester) async {
        await openSheet(tester);

        expect(addButton, findsOneWidget);
        expect(notWatchedLine, findsNothing);
        expect(find.byType(OwnReviewTile), findsNothing);
      });

      testWidgets('a series counts with one watched episode', (tester) async {
        await openSheet(
          tester,
          request: const MediaReviewsRequest(
            tmdbId: 438631,
            mediaType: MediaKind.tv,
          ),
        );

        expect(addButton, findsOneWidget);
      });

      testWidgets('rated: "Edit review", and your review comes first', (
        tester,
      ) async {
        when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
        await openSheet(tester);

        expect(editButton, findsOneWidget);
        expect(find.byType(OwnReviewTile), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(OwnReviewTile),
            matching: find.text(l10n.ownReviewEditorTitle),
          ),
          findsOneWidget,
        );
        expect(tester.widget<Wreath>(find.byType(Wreath)).score, saved.rating);
        expect(
          tester.getTopLeft(ownTile).dy,
          lessThan(tester.getTopLeft(find.text(outsideReview.text)).dy),
        );
      });

      testWidgets('every watch removed: the rating is kept but hidden', (
        tester,
      ) async {
        when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
        await openSheet(tester, logs: const []);

        expect(notWatchedLine, findsOneWidget);
        expect(ownTile, findsNothing);
        expect(editButton, findsNothing);
      });

      testWidgets('your rating can\'t be read: a message and Retry', (
        tester,
      ) async {
        when(
          () => reviews.get(any(), any()),
        ).thenThrow(const NetworkFailure('offline'));
        await openSheet(tester);

        expect(find.text(l10n.ownReviewLoadError), findsOneWidget);
        expect(addButton, findsNothing);

        when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
        await tabTo(tester, find.text(l10n.commonRetry));
        await press(tester, LogicalKeyboardKey.enter);
        expect(editButton, findsOneWidget);
      });
    });

    group('the list\'s own states never hide your review', () {
      setUp(() {
        when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
      });

      testWidgets('while the outside reviews load', (tester) async {
        final never = Completer<List<Comment>>();
        addTearDown(() => never.complete(const []));
        when(
          () => comments.fetchComments(any(), page: any(named: 'page')),
        ).thenAnswer((_) => never.future);
        await openSheet(tester, settle: false);

        expect(ownTile, findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('when they fail', (tester) async {
        when(
          () => comments.fetchComments(any(), page: any(named: 'page')),
        ).thenThrow(const NetworkFailure('offline'));
        await openSheet(tester);

        expect(ownTile, findsOneWidget);
        expect(find.textContaining(l10n.tvTimeCommentsError), findsOneWidget);
      });

      testWidgets('when there are none', (tester) async {
        when(
          () => comments.fetchComments(any(), page: any(named: 'page')),
        ).thenAnswer((_) async => const []);
        await openSheet(tester);

        expect(ownTile, findsOneWidget);
        expect(find.text(l10n.tvTimeNoComments), findsOneWidget);
      });

      testWidgets('whatever the source filter', (tester) async {
        await openSheet(tester);
        await tester.tap(find.byIcon(Icons.layers_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.commentsSourceLetterboxd).last);
        await tester.pumpAndSettle();

        expect(find.text(outsideReview.text), findsNothing);
        expect(ownTile, findsOneWidget);
        expect(find.text(l10n.tvTimeNoComments), findsOneWidget);
      });
    });

    group('the editor', () {
      testWidgets('it replaces the filters and reviews; a new rating starts '
          'at 5, on the slider, with no Remove', (tester) async {
        await openSheet(tester);
        await openEditor(tester, addButton);

        expect(find.text(l10n.ownReviewEditorTitle), findsOneWidget);
        expect(bigWreathScore(tester), 5);
        expect(isOnSlider(), isTrue);
        expect(saveButton, findsOneWidget);
        expect(cancelButton, findsOneWidget);
        expect(removeButton, findsNothing);
        expect(find.byIcon(Icons.layers_outlined), findsNothing);
        expect(find.text(outsideReview.text), findsNothing);
      });

      testWidgets('with the remote: slider, Down to the box, Enter to type, '
          'Down to Save, and the focus returns to the button', (tester) async {
        await openSheet(tester);
        await openEditor(tester, addButton);

        // Left and right change the score, and the wreath follows.
        for (var i = 0; i < 4; i++) {
          await press(tester, LogicalKeyboardKey.arrowRight);
        }
        expect(bigWreathScore(tester), 9);
        expect(isOnSlider(), isTrue);

        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(isFocused(reviewBox), isTrue);
        expect(isTyping(), isFalse);

        await press(tester, LogicalKeyboardKey.enter);
        expect(isTyping(), isTrue);
        await tester.enterText(reviewBox, '**Great**');
        await press(tester, LogicalKeyboardKey.escape);
        expect(isFocused(reviewBox), isTrue);
        expect(isTyping(), isFalse);
        expect(find.text(l10n.ownReviewEditorTitle), findsOneWidget);

        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(isFocused(saveButton), isTrue);
        await press(tester, LogicalKeyboardKey.enter);

        verify(
          () => reviews.save('me', title, rating: 9, text: '**Great**'),
        ).called(1);
        expect(find.byType(OwnReviewEditor), findsNothing);
        expect(find.text('Great'), findsOneWidget);
        expect(find.byType(OwnReviewTile), findsOneWidget);
        expect(isFocused(editButton), isTrue);
      });

      for (final size in const [Size(1280, 900), Size(960, 540)]) {
        testWidgets('${size.width} wide: Up goes back through the box to the '
            'slider, and Down comes back the same way', (tester) async {
          await openSheet(tester, size: size);
          await openEditor(tester, addButton);
          await press(tester, LogicalKeyboardKey.arrowDown);
          await press(tester, LogicalKeyboardKey.arrowDown);
          expect(isFocused(saveButton), isTrue);

          await press(tester, LogicalKeyboardKey.arrowUp);
          expect(isFocused(reviewBox), isTrue);
          await press(tester, LogicalKeyboardKey.arrowUp);
          expect(isOnSlider(), isTrue);

          await press(tester, LogicalKeyboardKey.arrowDown);
          expect(isFocused(reviewBox), isTrue);
          await press(tester, LogicalKeyboardKey.arrowDown);
          expect(isFocused(saveButton), isTrue);
        });

        testWidgets('${size.width} wide: every button can be reached from '
            'Save, and Up from each one lands on the box or a button above', (
          tester,
        ) async {
          when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
          await openSheet(tester, size: size);
          await openEditor(tester, editButton);
          await press(tester, LogicalKeyboardKey.arrowDown);
          await press(tester, LogicalKeyboardKey.arrowDown);

          await press(tester, LogicalKeyboardKey.arrowLeft);
          expect(isFocused(cancelButton), isTrue);
          await press(tester, LogicalKeyboardKey.arrowUp);
          expect(isFocused(reviewBox), isTrue);

          await tabTo(tester, removeButton);
          await press(tester, LogicalKeyboardKey.arrowUp);
          expect(
            isFocused(reviewBox) ||
                isFocused(cancelButton) ||
                isFocused(saveButton),
            isTrue,
          );
        });
      }

      testWidgets('only the editor\'s controls take the focus, and every one '
          'shows the ring', (tester) async {
        FocusRing.debugWatchKeys();
        when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
        await openSheet(tester);
        await openEditor(tester, editButton);

        expect(await stopsWithoutRing(tester), isEmpty);
        for (var i = 0; i < 8; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(isFocused(find.text('open')), isFalse);
        }
      });

      testWidgets('saving a score only leaves no review text', (tester) async {
        await openSheet(tester);
        await openEditor(tester, addButton);
        await tabTo(tester, saveButton);
        await press(tester, LogicalKeyboardKey.enter);

        verify(
          () => reviews.save('me', title, rating: 5, text: null),
        ).called(1);
        expect(find.byType(OwnReviewTile), findsOneWidget);
      });

      testWidgets('a failed save stays in the editor, with what was typed', (
        tester,
      ) async {
        when(
          () => reviews.save(
            any(),
            any(),
            rating: any(named: 'rating'),
            text: any(named: 'text'),
          ),
        ).thenThrow(const NetworkFailure('offline'));
        await openSheet(tester);
        await openEditor(tester, addButton);
        await tester.enterText(reviewBox, 'Not lost');
        await tester.tap(saveButton);
        await tester.pump();

        expect(find.text(l10n.failureNetwork), findsOneWidget);
        expect(find.text('Not lost'), findsOneWidget);
        expect(saveButton, findsOneWidget);
      });

      for (final (name, leave, focused)
          in <(String, Future<void> Function(WidgetTester), Finder)>[
            (
              'Back',
              (tester) => press(tester, LogicalKeyboardKey.escape),
              editButton,
            ),
            (
              'Cancel',
              (tester) async {
                await tabTo(tester, cancelButton);
                await press(tester, LogicalKeyboardKey.enter);
              },
              find.text(l10n.commonUndo),
            ),
          ]) {
        testWidgets('$name returns to the reviews without saving or closing '
            'the sheet', (tester) async {
          FocusRing.debugWatchKeys();
          when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
          await openSheet(tester);
          await openEditor(tester, editButton);
          await press(tester, LogicalKeyboardKey.arrowLeft);
          expect(bigWreathScore(tester), 8);

          await leave(tester);

          expect(find.byType(CommentsBottomSheet), findsOneWidget);
          expect(find.byType(OwnReviewEditor), findsNothing);
          expect(ownTile, findsOneWidget);
          expect(find.text(outsideReview.text), findsOneWidget);
          expect(isFocused(focused), isTrue);
          verifyNever(
            () => reviews.save(
              any(),
              any(),
              rating: any(named: 'rating'),
              text: any(named: 'text'),
            ),
          );
        });
      }

      testWidgets('reopened, it shows the saved score and text', (
        tester,
      ) async {
        when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
        await openSheet(tester);
        await openEditor(tester, editButton);

        expect(bigWreathScore(tester), 9);
        expect(find.text('My own words'), findsOneWidget);
      });

      testWidgets('Back outside the editor still closes the sheet', (
        tester,
      ) async {
        await openSheet(tester);
        await press(tester, LogicalKeyboardKey.escape);

        expect(find.byType(CommentsBottomSheet), findsNothing);
      });
    });

    group('unsaved text', () {
      const typed = 'A long text I would hate to lose';

      setUp(() {
        when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
      });

      /// Opens the editor and changes both the score and the text.
      Future<void> startEditing(WidgetTester tester) async {
        await openSheet(tester);
        await openEditor(tester, editButton);
        await press(tester, LogicalKeyboardKey.arrowLeft);
        await tester.enterText(reviewBox, typed);
        await tester.pump();
      }

      Future<void> expectUnsavedShows(WidgetTester tester) async {
        await openEditor(tester, editButton);
        expect(bigWreathScore(tester), 8);
        expect(find.text(typed), findsOneWidget);
      }

      Future<void> expectSavedShows(WidgetTester tester) async {
        await openEditor(tester, editButton);
        expect(bigWreathScore(tester), 9);
        expect(find.text('My own words'), findsOneWidget);
      }

      Future<void> cancel(WidgetTester tester) async {
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();
      }

      Future<void> letMessageClose(WidgetTester tester) async {
        await tester.pump(AppSnackBar.defaultUndoDuration);
        await tester.pumpAndSettle();
      }

      testWidgets('Back keeps it for the next opening', (tester) async {
        await startEditing(tester);
        // The first Back only stops typing.
        await press(tester, LogicalKeyboardKey.escape);
        await press(tester, LogicalKeyboardKey.escape);

        expect(
          find.textContaining(l10n.ownReviewChangesDiscarded),
          findsNothing,
        );
        await expectUnsavedShows(tester);
      });

      testWidgets('a tap outside the sheet keeps it', (tester) async {
        await startEditing(tester);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byType(CommentsBottomSheet), findsOneWidget);

        // That tap counted as Back; a second one closes the sheet.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byType(CommentsBottomSheet), findsNothing);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await expectUnsavedShows(tester);
      });

      testWidgets('it comes back after the app was closed', (tester) async {
        await startEditing(tester);
        await tester.pumpWidget(const SizedBox());

        await openSheet(tester);
        await expectUnsavedShows(tester);
      });

      testWidgets('a new rating keeps it too', (tester) async {
        when(() => reviews.get(any(), any())).thenAnswer((_) async => null);
        await openSheet(tester);
        await openEditor(tester, addButton);
        await tester.enterText(reviewBox, typed);
        await tester.pump();
        await tester.pumpWidget(const SizedBox());

        await openSheet(tester);
        await openEditor(tester, addButton);
        expect(find.text(typed), findsOneWidget);
        expect(bigWreathScore(tester), 5);
      });

      testWidgets('Save deletes it', (tester) async {
        await startEditing(tester);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());

        await openSheet(tester);
        await expectSavedShows(tester);
      });

      testWidgets('Remove deletes it', (tester) async {
        await startEditing(tester);
        await tester.tap(removeButton);
        await tester.pumpAndSettle();
        await letMessageClose(tester);
        await tester.pumpWidget(const SizedBox());

        await openSheet(tester);
        await expectSavedShows(tester);
      });

      testWidgets('Cancel with nothing changed shows no message', (
        tester,
      ) async {
        await openSheet(tester);
        await openEditor(tester, editButton);
        await cancel(tester);

        expect(find.byType(OwnReviewEditor), findsNothing);
        expect(find.text(l10n.commonUndo), findsNothing);
      });

      testWidgets('a score moved and put back counts as nothing changed', (
        tester,
      ) async {
        await openSheet(tester);
        await openEditor(tester, editButton);
        await press(tester, LogicalKeyboardKey.arrowLeft);
        await press(tester, LogicalKeyboardKey.arrowRight);
        await cancel(tester);

        expect(find.text(l10n.commonUndo), findsNothing);
      });

      testWidgets('Cancel with changes: the saved rating shows, with the '
          'message, and it is deleted when the message closes', (tester) async {
        await startEditing(tester);
        await cancel(tester);

        expect(find.byType(OwnReviewEditor), findsNothing);
        expect(ownTile, findsOneWidget);
        expect(find.text(typed), findsNothing);
        expect(
          find.textContaining(l10n.ownReviewChangesDiscarded),
          findsOneWidget,
        );
        expect(find.text(l10n.commonUndo), findsOneWidget);

        await letMessageClose(tester);
        expect(find.text(l10n.commonUndo), findsNothing);
        await expectSavedShows(tester);
      });

      testWidgets('Undo keeps it for the next opening and doesn\'t reopen the '
          'editor', (tester) async {
        await startEditing(tester);
        await cancel(tester);
        await tester.tap(find.text(l10n.commonUndo));
        await tester.pumpAndSettle();

        expect(find.byType(OwnReviewEditor), findsNothing);
        expect(ownTile, findsOneWidget);
        await expectUnsavedShows(tester);
      });

      testWidgets('with the Undo time Off it is deleted at once, with no '
          'message', (tester) async {
        AppSnackBar.undoDuration = Duration.zero;
        addTearDown(
          () => AppSnackBar.undoDuration = AppSnackBar.defaultUndoDuration,
        );
        await startEditing(tester);
        await cancel(tester);

        expect(find.text(l10n.commonUndo), findsNothing);
        await expectSavedShows(tester);
      });

      testWidgets('with the remote: the focus goes to Undo, then back to the '
          'button', (tester) async {
        FocusRing.debugWatchKeys();
        await startEditing(tester);
        await tabTo(tester, cancelButton);
        await press(tester, LogicalKeyboardKey.enter);

        expect(isFocused(find.text(l10n.commonUndo)), isTrue);
        await press(tester, LogicalKeyboardKey.arrowUp);
        expect(isFocused(editButton), isTrue);
      });
    });

    group('removing', () {
      setUp(() {
        when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
      });

      Future<void> remove(WidgetTester tester) async {
        await openSheet(tester);
        await openEditor(tester, editButton);
        await tester.tap(removeButton);
        await tester.pumpAndSettle();
      }

      testWidgets('it goes at once, with the Undo message, back in the '
          'reviews', (tester) async {
        await remove(tester);

        verify(() => reviews.remove('me', title)).called(1);
        expect(find.textContaining(l10n.ownReviewRemoved), findsOneWidget);
        expect(find.text(l10n.commonUndo), findsOneWidget);
        expect(find.byType(OwnReviewEditor), findsNothing);
        expect(ownTile, findsNothing);
        expect(addButton, findsOneWidget);
      });

      testWidgets('Undo puts it back', (tester) async {
        await remove(tester);
        await tester.tap(find.text(l10n.commonUndo));
        await tester.pumpAndSettle();

        verify(() => reviews.restore('me', saved)).called(1);
        expect(ownTile, findsOneWidget);
        expect(editButton, findsOneWidget);
      });

      testWidgets('Undo still works after the sheet closed', (tester) async {
        await remove(tester);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byType(CommentsBottomSheet), findsNothing);

        await tester.tap(find.text(l10n.commonUndo));
        await tester.pumpAndSettle();

        verify(() => reviews.restore('me', saved)).called(1);
      });

      testWidgets('with the remote: the focus goes to Undo, then back to the '
          'button', (tester) async {
        FocusRing.debugWatchKeys();
        await openSheet(tester);
        await openEditor(tester, editButton);
        await tabTo(tester, removeButton);
        await press(tester, LogicalKeyboardKey.enter);

        expect(isFocused(find.text(l10n.commonUndo)), isTrue);
        await press(tester, LogicalKeyboardKey.arrowUp);
        expect(isFocused(addButton), isTrue);
      });

      testWidgets('a failed removal keeps the rating and says so', (
        tester,
      ) async {
        when(
          () => reviews.remove(any(), any()),
        ).thenThrow(const NetworkFailure('offline'));
        await remove(tester);

        expect(find.text(l10n.failureNetwork), findsOneWidget);
        expect(ownTile, findsOneWidget);
        expect(editButton, findsOneWidget);
      });
    });

    group('sizes', () {
      for (final (name, size, isSideBySide) in const [
        ('a Fire Stick at 100%', Size(960, 540), true),
        ('a TV at 67%', Size(1433, 806), false),
        ('a phone', Size(390, 844), false),
        ('the smallest phone', Size(320, 568), false),
      ]) {
        for (final (locale, strings) in [
          (const Locale('en'), AppLocalizationsEn()),
          (const Locale('it'), AppLocalizationsIt()),
        ]) {
          testWidgets('$name (${locale.languageCode}): the editor fits, and '
              'Save can be reached', (tester) async {
            when(
              () => reviews.get(any(), any()),
            ).thenAnswer((_) async => saved);
            await openSheet(tester, size: size, locale: locale);
            await tabTo(tester, find.text(strings.ownReviewEdit));
            await press(tester, LogicalKeyboardKey.enter);

            final wreath = tester.getRect(find.byType(Wreath));
            final slider = tester.getRect(find.byType(Slider));
            if (isSideBySide) {
              expect(wreath.right, lessThan(slider.left));
            } else {
              expect(wreath.bottom, lessThanOrEqualTo(slider.top));
            }

            await tabTo(tester, find.text(strings.ownReviewSave));
            await tester.pumpAndSettle();
            final save = tester.getRect(find.text(strings.ownReviewSave));
            expect(save.bottom, lessThanOrEqualTo(size.height));
          });
        }
      }

      testWidgets('a Fire Stick at 100%: everything shows without scrolling', (
        tester,
      ) async {
        when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
        await openSheet(tester, size: const Size(960, 540));
        await openEditor(tester, editButton);

        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(OwnReviewEditor),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scroll.position.maxScrollExtent, 0);
      });

      for (final (name, size) in const [
        ('a Fire Stick at 100%', Size(960, 540)),
        ('a TV at 67%', Size(1433, 806)),
      ]) {
        testWidgets('$name: no focus ring in the editor is cut off', (
          tester,
        ) async {
          when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
          await openSheet(tester, size: size);
          await openEditor(tester, editButton);

          // The editor scrolls, so it cuts what is drawn past its edges.
          final visible = tester.getRect(
            find
                .descendant(
                  of: find.byType(OwnReviewEditor),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          final rings = find.descendant(
            of: find.byType(OwnReviewEditor),
            matching: find.byType(FocusRing),
          );
          expect(rings, findsAtLeast(5));
          for (final element in rings.evaluate()) {
            final focusRing = element.widget as FocusRing;
            if (focusRing.isInside) continue;
            final ring = tester
                .getRect(find.byElementPredicate((e) => e == element))
                .inflate(AppTheme.focusRingGap + AppTheme.focusRingWidth);
            expect(
              visible.expandToInclude(ring),
              visible,
              reason: 'the ring around ${focusRing.child} is cut off',
            );
          }
        });
      }

      testWidgets('a phone: the button, then the filters, then the reviews', (
        tester,
      ) async {
        when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
        await openSheet(tester, size: const Size(390, 844));

        final button = tester.getRect(editButton);
        final filter = tester.getRect(find.byIcon(Icons.layers_outlined));
        expect(button.bottom, lessThan(filter.top));
        expect(filter.bottom, lessThan(tester.getTopLeft(ownTile).dy));
      });

      testWidgets('a TV: the button under the title and filters', (
        tester,
      ) async {
        when(() => reviews.get(any(), any())).thenAnswer((_) async => saved);
        await openSheet(tester, size: const Size(960, 540));

        final button = tester.getRect(editButton);
        final filter = tester.getRect(find.byIcon(Icons.layers_outlined));
        expect(filter.bottom, lessThan(button.top));
      });
    });
  });
}

class _MockOwnReviews extends Mock implements OwnReviewsRepository {}

class _FakeMovieLogs extends OptimisticMovieLogs {
  _FakeMovieLogs(super.tmdbId, this._logs);

  final List<WatchLog> _logs;

  @override
  Stream<List<WatchLog>> build() => Stream.value(_logs);
}

class _FakeSeriesLogs extends OptimisticSeriesLogs {
  _FakeSeriesLogs(super.tmdbId, this._logs);

  final List<WatchLog> _logs;

  @override
  Stream<List<WatchLog>> build() => Stream.value(_logs);
}
