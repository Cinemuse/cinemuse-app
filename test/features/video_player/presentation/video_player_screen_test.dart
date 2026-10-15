import 'package:cinemuse_app/core/application/locale_service.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/focus_helpers.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

/// A player whose load ended with [error], or still loading without one.
class FakePlayerController extends StateNotifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  FakePlayerController(Object? error)
    : super(
        error == null
            ? const AsyncValue.loading()
            : AsyncValue.error(error, StackTrace.empty),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// REV-164: offline, the error screen said "All sources failed".
void main() {
  for (final (locale, l10n) in [
    (const Locale('en'), AppLocalizationsEn()),
    (const Locale('it'), AppLocalizationsIt()),
  ]) {
    testWidgets('offline (${locale.languageCode}): "can\'t reach the server", '
        'Retry focused; Enter loads again', (tester) async {
      var isOnline = false;
      var loads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(FakeSettingsNotifier.new),
            localeProvider.overrideWith(
              (ref) => LocaleNotifier()..setLocale(locale.languageCode),
            ),
            playerControllerProvider.overrideWith((ref, params) {
              loads++;
              return FakePlayerController(
                isOnline ? null : const NetworkFailure('offline'),
              );
            }),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const VideoPlayerScreen(queryId: '550', type: 'movie'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(l10n.failureNetwork), findsOneWidget);
      expect(find.text(l10n.playerAllSourcesExhausted), findsNothing);
      expect(isFocused(find.text(l10n.commonRetry)), isTrue);

      isOnline = true;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(loads, 2);
      expect(find.text(l10n.failureNetwork), findsNothing);
    });
  }
}
