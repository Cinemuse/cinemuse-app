import 'package:cinemuse_app/features/media/application/person_providers.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/person_filmography_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// REV-214: the birthday was shown as TMDB's raw "1974-03-12" in every language.
void main() {
  setUpAll(initializeDateFormatting);

  Widget app(Locale locale) => ProviderScope(
    overrides: [
      personDetailsProvider.overrideWith(
        (ref, id) async =>
            const PersonDetails(id: 1, name: 'Someone', birthday: '1974-03-12'),
      ),
      watchHistoryStoreProvider.overrideWith((ref) => Stream.value(const {})),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PersonDetailsScreen(personId: 1),
    ),
  );

  testWidgets('birthday is a date in the app language (Italian)', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Locale('it')));
    await tester.pumpAndSettle();

    expect(find.text('12 mar 1974'), findsOneWidget);
    expect(find.text('1974-03-12'), findsNothing);
  });

  testWidgets('birthday is a date in the app language (English)', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Mar 12, 1974'), findsOneWidget);
  });

  testWidgets('a movie and a show with the same id: two titles, each once, '
      'only the watched one seen (REV-195)', (tester) async {
    final movie = PersonCredit(
      id: 1399,
      mediaType: MediaKind.movie,
      title: 'A Movie',
      releaseDate: DateTime(2020, 1, 1),
    );
    final show = PersonCredit(
      id: 1399,
      mediaType: MediaKind.tv,
      title: 'A Show',
      releaseDate: DateTime(2011, 4, 17),
    );
    final watched = WatchHistory(
      userId: 'user-a',
      tmdbId: 1399,
      mediaType: MediaKind.tv,
      status: WatchStatus.completed,
      progressSeconds: 0,
      lastWatchedAt: DateTime.utc(2026, 10, 1),
    );
    // Tall, so the filmography is built too.
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personDetailsProvider.overrideWith(
            (ref, id) async => PersonDetails(
              id: 1,
              name: 'Someone',
              cast: [movie, show],
              // Acted in and directed the movie: still one title.
              crew: [movie],
            ),
          ),
          watchHistoryStoreProvider.overrideWith(
            (ref) => Stream.value({watched.titleKey: watched}),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PersonDetailsScreen(personId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('(1/2)', findRichText: true), findsOneWidget);
    Finder inFilmography(String title) => find.descendant(
      of: find.byType(PersonFilmographyList),
      matching: find.text(title),
    );
    expect(inFilmography('A Movie'), findsOneWidget);
    expect(inFilmography('A Show'), findsOneWidget);
  });
}
