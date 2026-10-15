import 'package:cinemuse_app/features/media/application/person_providers.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
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
}
