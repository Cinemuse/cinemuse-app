import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/shared/widgets/error_action.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/focus_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  final l10n = AppLocalizationsEn();

  // REV-45: the three error widgets each picked their own icon per type.
  final iconCases = <ErrorKind, IconData>{
    ErrorKind.network: Icons.wifi_off_rounded,
    ErrorKind.auth: Icons.lock_person_rounded,
    ErrorKind.server: Icons.cloud_off_rounded,
    ErrorKind.streaming: Icons.movie_filter_rounded,
    ErrorKind.validation: Icons.error_outline_rounded,
    ErrorKind.unknown: Icons.error_outline_rounded,
  };
  iconCases.forEach((kind, icon) {
    testWidgets('${kind.name} error → its icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ErrorCard(
            error: UserFriendlyError(message: 'x', kind: kind),
          ),
        ),
      );

      expect(find.byIcon(icon), findsOneWidget);
    });
  });

  // REV-237: Retry was an icon-only button and never took the focus.
  testWidgets('a text Retry button, focused only when asked', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        ErrorCard(
          error: UserFriendlyError(message: 'Could not load'),
          onRetry: () => retried = true,
          autofocus: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Could not load'), findsOneWidget);
    expect(isFocused(find.text(l10n.commonRetry)), isTrue);
    await tester.tap(find.text(l10n.commonRetry));
    expect(retried, isTrue);

    await tester.pumpWidget(
      _wrap(
        ErrorCard(
          key: UniqueKey(),
          error: UserFriendlyError(message: 'Could not load'),
          onRetry: () {},
        ),
      ),
    );
    await tester.pump();
    expect(isFocused(find.text(l10n.commonRetry)), isFalse);
  });

  testWidgets('an extra action shows next to Retry', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      _wrap(
        ErrorCard(
          error: UserFriendlyError(message: 'x'),
          onRetry: () {},
          extraAction: ErrorAction(
            label: 'Settings',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Settings'));
    expect(pressed, isTrue);
    expect(find.text(l10n.commonRetry), findsOneWidget);
  });
}
