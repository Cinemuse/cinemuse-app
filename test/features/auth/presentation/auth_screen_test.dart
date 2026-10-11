import 'dart:async';

import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/auth/presentation/auth_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

/// Same gate as `main.dart`: a spinner while the auth state is loading.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(authProvider)
        .when(
          data: (_) => const AuthScreen(),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const AuthScreen(),
        );
  }
}

void main() {
  late MockGoTrueClient goTrue;
  late StreamController<AuthState> authStates;

  setUp(() {
    goTrue = MockGoTrueClient();
    authStates = StreamController<AuthState>.broadcast();
    when(() => goTrue.currentSession).thenReturn(null);
    when(() => goTrue.currentUser).thenReturn(null);
    when(() => goTrue.onAuthStateChange).thenAnswer((_) => authStates.stream);
  });

  tearDown(() => authStates.close());

  testWidgets('a wrong password keeps the screen and shows the error', (
    tester,
  ) async {
    final client = MockSupabaseClient();
    when(() => client.auth).thenReturn(goTrue);
    final answer = Completer<AuthResponse>();
    when(
      () => goTrue.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => answer.future);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthService(client)),
          localizationsProvider.overrideWithValue(
            lookupAppLocalizations(const Locale('en')),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const _AuthGate(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'me@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-pass');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // While waiting, the button shows its spinner inside the same screen.
    expect(find.byType(AuthScreen), findsOneWidget);

    answer.completeError(AuthException('Invalid login credentials'));
    await tester.pumpAndSettle();

    expect(find.text('me@test.com'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
