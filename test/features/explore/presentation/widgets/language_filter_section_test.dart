import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/explore/application/explore_providers.dart';
import 'package:cinemuse_app/features/explore/presentation/widgets/language_filter_section.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/focus_helpers.dart';

void main() {
  Future<void> pumpSection(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FocusRing.debugWatchKeys();
    final container = ProviderContainer(retry: noProviderRetry);
    addTearDown(container.dispose);
    container.read(exploreFiltersProvider.notifier).addLanguage('it');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: LanguageFilterSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a language row under the mouse: the brand purple', (
    tester,
  ) async {
    await pumpSection(tester);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final row = tester.widget<InkWell>(
      find.ancestor(of: find.text('Spanish'), matching: find.byType(InkWell)),
    );
    final hover =
        row.hoverColor ??
        Theme.of(tester.element(find.text('Spanish'))).hoverColor;
    expect(hover, AppTheme.accentHoverBg);
  });

  // On the TV the language rows and a picked language showed no ring.
  testWidgets('every language row and the "x" show the ring', (tester) async {
    await pumpSection(tester);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Spanish'), findsOneWidget);

    expect(await stopsWithoutRing(tester), isEmpty);
  });
}
