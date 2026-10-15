import 'package:cinemuse_app/core/application/locale_service.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/data/comments_repository_provider.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/comments_bottom_sheet.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/app_font.dart';
import '../../../../helpers/focus_helpers.dart';

class MockCommentsRepository extends Mock implements CommentsRepository {}

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
          overrides: [
            commentsRepositoryProvider.overrideWithValue(repository),
            // The app language, as the app sets it (error texts follow it).
            localeProvider.overrideWith(
              (ref) => LocaleNotifier()..setLocale(locale.languageCode),
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
            source: CommentSource.serializd,
          ),
        ];
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            commentsRepositoryProvider.overrideWithValue(repository),
            localeProvider.overrideWith(
              (ref) => LocaleNotifier()..setLocale(locale.languageCode),
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
            source: CommentSource.serializd,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [commentsRepositoryProvider.overrideWithValue(repository)],
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
    List<Comment> serializd(int page) => [
      for (var i = 1; i <= 6; i++)
        comment('Serializd $page.$i', CommentSource.serializd),
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
          overrides: [commentsRepositoryProvider.overrideWithValue(repository)],
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
        1: serializd(1),
        2: serializd(2),
        3: [
          comment('IMDb 1', CommentSource.imdb),
          comment('IMDb 2', CommentSource.imdb),
        ],
        4: [comment('IMDb 3', CommentSource.imdb)],
        5: serializd(5),
        6: [comment('IMDb 4', CommentSource.imdb)],
      });

      for (final text in ['IMDb 1', 'IMDb 2', 'IMDb 3']) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.textContaining('Serializd'), findsNothing);
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
      await pumpSheet(tester, {1: serializd(1), 2: serializd(2)});

      expect(find.text(l10n.tvTimeNoComments), findsOneWidget);
      expect(find.text(l10n.commentsLoadMore), findsNothing);
      expect(find.textContaining('Serializd'), findsNothing);
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
            source: CommentSource.serializd,
          ),
        for (var i = 1; i <= 6; i++)
          Comment(
            id: 'c$page.$i',
            author: const CommentAuthor(id: 'u1', username: 'alice'),
            text: 'Comment $page.$i',
            createdAt: DateTime.utc(2024),
            source: CommentSource.serializd,
          ),
      ];
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [commentsRepositoryProvider.overrideWithValue(repository)],
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
}
