import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:cinemuse_app/shared/widgets/error_action.dart';
import 'package:cinemuse_app/shared/widgets/error_view_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/focus_helpers.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: AppTheme.darkTheme,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  final l10n = AppLocalizationsEn();

  // REV-237: the full-screen error had no focused button for the remote.
  testWidgets('shows the error and Retry has the focus', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        ErrorViewState(
          error: UserFriendlyError(
            message: 'No connection',
            hint: 'Check the Wi-Fi',
            kind: ErrorKind.network,
          ),
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('Check the Wi-Fi'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    expect(isFocused(find.text(l10n.commonRetry)), isTrue);

    await tester.tap(find.text(l10n.commonRetry));
    expect(retried, isTrue);
  });

  testWidgets('a main action takes the focus; Retry and extras stay', (
    tester,
  ) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      _wrap(
        ErrorViewState(
          error: UserFriendlyError(message: 'Blocked'),
          onRetry: () => pressed.add('retry'),
          extraActions: [
            ErrorAction(label: 'Go back', onPressed: () => pressed.add('back')),
          ],
          mainAction: ErrorAction(
            label: 'Open on YouTube',
            icon: Icons.open_in_new,
            onPressed: () => pressed.add('main'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(isFocused(find.text('Open on YouTube')), isTrue);
    await tester.tap(find.text('Go back'));
    await tester.tap(find.text(l10n.commonRetry));
    await tester.tap(find.text('Open on YouTube'));
    expect(pressed, ['back', 'retry', 'main']);
  });

  testWidgets('Retry is translated', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ErrorViewState(
          error: UserFriendlyError(message: 'x'),
          onRetry: () {},
        ),
        locale: const Locale('it'),
      ),
    );

    expect(find.text(AppLocalizationsIt().commonRetry), findsOneWidget);
  });
}
