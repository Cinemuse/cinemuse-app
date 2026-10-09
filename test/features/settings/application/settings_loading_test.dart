import 'dart:async';

import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

User _user(String id) =>
    User(id: id, appMetadata: {}, userMetadata: {}, aud: '', createdAt: '');

Session _session(String userId) =>
    Session(accessToken: 'token', tokenType: 'bearer', user: _user(userId));

Profile _profile(String id, Map<String, dynamic> preferences) => Profile(
  id: id,
  preferences: preferences,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

// DATA-02: settings must never be saved before the user's stored settings
// are loaded, or the defaults overwrite their keys and addons.
void main() {
  late MockProfileRepository profileRepo;
  late StreamController<AuthState> authEvents;
  late ProviderContainer container;

  setUp(() {
    profileRepo = MockProfileRepository();
    authEvents = StreamController<AuthState>.broadcast();
    when(
      () => profileRepo.updateProfile(any(), any()),
    ).thenAnswer((_) async {});

    final auth = MockGoTrueClient();
    when(() => auth.currentSession).thenReturn(_session('user-a'));
    when(() => auth.onAuthStateChange).thenAnswer((_) => authEvents.stream);
    final client = MockSupabaseClient();
    when(() => client.auth).thenReturn(auth);

    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => AuthService(client)),
        profileRepositoryProvider.overrideWithValue(profileRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    authEvents.close();
  });

  test('does not save when loading the settings failed', () async {
    when(() => profileRepo.getProfile('user-a')).thenAnswer((_) async => null);

    final notifier = container.read(settingsProvider.notifier);

    await expectLater(
      notifier.updateSettings({'showSubtitles': false}),
      throwsException,
    );
    verifyNever(() => profileRepo.updateProfile(any(), any()));
  });

  test('a change made while loading waits and keeps stored keys', () async {
    final load = Completer<Profile?>();
    when(() => profileRepo.getProfile('user-a')).thenAnswer((_) => load.future);

    final notifier = container.read(settingsProvider.notifier);
    final update = notifier.updateSettings({'showSubtitles': false});

    load.complete(_profile('user-a', {'realDebridKey': 'stored-key'}));
    await update;

    final saved =
        verify(
              () => profileRepo.updateProfile('user-a', captureAny()),
            ).captured.single
            as Map<String, dynamic>;
    final prefs = saved['preferences'] as Map<String, dynamic>;
    expect(prefs['realDebridKey'], 'stored-key');
    expect(prefs['showSubtitles'], false);
  });

  test('switching account drops the previous user\'s settings', () async {
    when(() => profileRepo.getProfile('user-a')).thenAnswer(
      (_) async => _profile('user-a', {'realDebridKey': 'key-of-a'}),
    );
    when(() => profileRepo.getProfile('user-b')).thenAnswer((_) async => null);

    final notifier = container.read(settingsProvider.notifier);
    await notifier.initSettings();
    expect(container.read(settingsProvider).realDebridKey, 'key-of-a');

    authEvents.add(AuthState(AuthChangeEvent.signedIn, _session('user-b')));
    await pumpEventQueue();

    expect(container.read(settingsProvider).realDebridKey, '');
    await expectLater(
      notifier.updateSettings({'showSubtitles': false}),
      throwsException,
    );
    verifyNever(() => profileRepo.updateProfile('user-b', any()));
  });
}
