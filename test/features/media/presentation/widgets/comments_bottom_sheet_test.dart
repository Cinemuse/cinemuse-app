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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCommentsRepository extends Mock implements CommentsRepository {}

// REV-201: offline, the sheet showed the raw "Exception: …" text.
void main() {
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
}
