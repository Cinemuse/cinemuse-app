import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
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
      () => profileRepo.patchPreferences(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => profileRepo.updateUsername(any(), any()),
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
      notifier.updateSettings((s) => s.copyWith(showSubtitles: false)),
      throwsException,
    );
    verifyNever(() => profileRepo.patchPreferences(any(), any()));
  });

  test('a change made while loading waits for the stored settings', () async {
    final load = Completer<Profile?>();
    when(() => profileRepo.getProfile('user-a')).thenAnswer((_) => load.future);

    final notifier = container.read(settingsProvider.notifier);
    final update = notifier.updateSettings(
      (s) => s.copyWith(showSubtitles: false),
    );

    load.complete(_profile('user-a', {'realDebridKey': 'stored-key'}));
    await update;

    expect(container.read(settingsProvider).realDebridKey, 'stored-key');
    verify(
      () => profileRepo.patchPreferences('user-a', {'showSubtitles': false}),
    ).called(1);
  });

  // DATA-02b: a save writes only what changed, so values another device
  // saved meanwhile (or this one never loaded right) stay as stored.
  test('a save sends only the changed keys', () async {
    when(() => profileRepo.getProfile('user-a')).thenAnswer(
      (_) async => _profile('user-a', {
        'realDebridKey': 'stored-key',
        'installedAddons': [
          {'id': 'a', 'name': 'A', 'transportUrl': 'https://a', 'version': '1'},
        ],
      }),
    );

    final notifier = container.read(settingsProvider.notifier);
    await notifier.initSettings();
    await notifier.updateSettings((s) => s.copyWith(showSubtitles: false));

    // Exactly this map: the stored key and the addon list are not sent.
    verify(
      () => profileRepo.patchPreferences('user-a', {'showSubtitles': false}),
    ).called(1);
    verifyNever(() => profileRepo.updateUsername(any(), any()));
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
      notifier.updateSettings((s) => s.copyWith(showSubtitles: false)),
      throwsException,
    );
    verifyNever(() => profileRepo.patchPreferences('user-b', any()));
  });

  test('a failed save puts the old value back and rethrows (REV-78)', () async {
    when(
      () => profileRepo.getProfile('user-a'),
    ).thenAnswer((_) async => _profile('user-a', {'showSubtitles': true}));
    when(
      () => profileRepo.patchPreferences(any(), any()),
    ).thenThrow(const NetworkFailure('offline'));

    final notifier = container.read(settingsProvider.notifier);
    await notifier.initSettings();

    await expectLater(
      notifier.updateSettings((s) => s.copyWith(showSubtitles: false)),
      throwsA(isA<NetworkFailure>()),
    );
    expect(container.read(settingsProvider).showSubtitles, true);
  });

  test(
    'a stored value of the wrong type still lets the user save (REV-82)',
    () async {
      when(() => profileRepo.getProfile('user-a')).thenAnswer(
        (_) async => _profile('user-a', {
          'showSubtitles': 'true',
          'realDebridKey': 'stored-key',
        }),
      );

      final notifier = container.read(settingsProvider.notifier);
      await notifier.initSettings();
      await notifier.updateSettings((s) => s.copyWith(enableVixSrc: false));

      verify(
        () => profileRepo.patchPreferences('user-a', {'enableVixSrc': false}),
      ).called(1);
    },
  );

  test('a new display name is saved as the username', () async {
    when(
      () => profileRepo.getProfile('user-a'),
    ).thenAnswer((_) async => _profile('user-a', {}));

    final notifier = container.read(settingsProvider.notifier);
    await notifier.initSettings();
    await notifier.updateSettings((s) => s.copyWith(displayName: 'Ste'));

    verify(() => profileRepo.updateUsername('user-a', 'Ste')).called(1);
    verifyNever(() => profileRepo.patchPreferences(any(), any()));
  });
}
