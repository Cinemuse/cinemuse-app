import 'package:cinemuse_app/features/explore/presentation/widgets/active_filters_list.dart';
import 'package:cinemuse_app/features/explore/domain/explore_filters.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// REV-253: a filter chip's × has a tooltip in the app's language.
void main() {
  for (final (locale, l10n) in [
    (const Locale('en'), AppLocalizationsEn()),
    (const Locale('it'), AppLocalizationsIt()),
  ]) {
    testWidgets('× tooltip in ${locale.languageCode}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ActiveFiltersList(
              filters: ExploreFilters(genres: const [28]),
              onChanged: (_) {},
              onClear: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.commonRemoveFilter), findsOneWidget);
    });
  }
}
