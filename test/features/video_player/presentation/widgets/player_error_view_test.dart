import 'package:cinemuse_app/features/video_player/presentation/widgets/player_error_view.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('a YouTube error explains it and offers to open YouTube', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(PlayerErrorView(youtubeVideoId: 'abc', onRetry: () {})),
    );

    expect(find.text(l10n.playerYoutubeBlocked), findsOneWidget);
    final openButton = find.ancestor(
      of: find.text(l10n.playerOpenOnYoutube),
      matching: find.bySubtype<ButtonStyleButton>(),
    );
    expect(openButton, findsOneWidget);
    // The main button has the focus, so a remote can press it at once.
    expect(
      Focus.of(tester.element(find.text(l10n.playerOpenOnYoutube))).hasFocus,
      isTrue,
    );
  });

  testWidgets('another error shows its message and no YouTube button', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(PlayerErrorView(message: 'Boom', onRetry: () => retried = true)),
    );

    expect(find.text('Boom'), findsOneWidget);
    expect(find.text(l10n.playerOpenOnYoutube), findsNothing);
    await tester.tap(find.text(l10n.commonRetry));
    expect(retried, isTrue);
  });
}
