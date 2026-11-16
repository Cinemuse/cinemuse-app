import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/create_list_sheet.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// REV-89: the sheet closed even when the new list wasn't saved.
void main() {
  final l10n = AppLocalizationsEn();

  for (final (name, isSaved, isOpenAfter) in [
    ('a saved list closes the sheet', true, false),
    ('a list not saved keeps the sheet open with the name', false, true),
  ]) {
    testWidgets(name, (tester) async {
      final created = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => CreateListSheet.show(
                  context,
                  onCreate: (name) async {
                    created.add(name);
                    return isSaved;
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Best Films');
      await tester.pump();
      await tester.tap(find.text(l10n.commonCreate));
      await tester.pumpAndSettle();

      expect(created, ['Best Films']);
      expect(
        find.widgetWithText(TextField, 'Best Films'),
        isOpenAfter ? findsOneWidget : findsNothing,
      );
    });
  }
}
