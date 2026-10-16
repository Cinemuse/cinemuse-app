import 'package:cinemuse_app/core/application/locale_service.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/features/settings/data/user_secrets_repository.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/identity_settings.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockUserSecretsRepository extends Mock implements UserSecretsRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

// REV-260, REV-86: offline, saving the display name said "something went
// wrong" or showed "Exception: â€¦".
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (locale, l10n) in [
    (const Locale('en'), AppLocalizationsEn()),
    (const Locale('it'), AppLocalizationsIt()),
  ]) {
    testWidgets('offline (${locale.languageCode}): saving the display name '
        'says there is no connection', (tester) async {
      final user = User(
        id: 'user-a',
        appMetadata: {},
        userMetadata: {},
        aud: '',
        createdAt: '',
      );
      final auth = MockGoTrueClient();
      when(() => auth.currentSession).thenReturn(
        Session(accessToken: 'token', tokenType: 'bearer', user: user),
      );
      when(
        () => auth.onAuthStateChange,
      ).thenAnswer((_) => const Stream.empty());
      final client = MockSupabaseClient();
      when(() => client.auth).thenReturn(auth);

      // The settings load (they were stored before), then the save fails.
      final profiles = MockProfileRepository();
      when(() => profiles.getProfile('user-a')).thenAnswer(
        (_) async => Profile(
          id: 'user-a',
          username: 'Old name',
          preferences: {'appLanguage': locale.languageCode},
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      when(
        () => profiles.updateUsername(any(), any()),
      ).thenThrow(const NetworkFailure('offline'));
      final secrets = MockUserSecretsRepository();
      when(() => secrets.getSecrets('user-a')).thenAnswer((_) async => {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthService(client)),
            profileRepositoryProvider.overrideWithValue(profiles),
            userSecretsRepositoryProvider.overrideWithValue(secrets),
            localeProvider.overrideWith(
              (ref) => LocaleNotifier()..setLocale(locale.languageCode),
            ),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: IdentitySettings()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Old name'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'New name');
      await tester.pump(); // Save turns on once the text changed
      await tester.tap(find.text(l10n.settingsSave));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // REV-261: the error is red text under the box, not a snackbar.
      final error = find.descendant(
        of: find.byType(TextField),
        matching: find.text(l10n.settingsErrorSaving(l10n.failureNetwork)),
      );
      expect(error, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('Failure'), findsNothing);

      // Typing again clears it.
      await tester.enterText(find.byType(TextField), 'Newer name');
      await tester.pump();
      expect(error, findsNothing);
    });
  }
}
