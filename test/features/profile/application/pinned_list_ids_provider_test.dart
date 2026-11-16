import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/profile/application/pinned_list_ids_provider.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

Profile _profile(String id, Map<String, dynamic> preferences) => Profile(
  id: id,
  preferences: preferences,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

// REV-95: the pins live on the account, not on the device.
void main() {
  late MockProfileRepository profiles;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    profiles = MockProfileRepository();
    when(
      () => profiles.patchPreferences(any(), any()),
    ).thenAnswer((_) async {});
  });

  Future<ProviderContainer> start(Profile profile) async {
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        userIdProvider.overrideWithValue(profile.id),
        profileStreamProvider.overrideWith((ref) => Stream.value(profile)),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
    addTearDown(container.dispose);
    container.listen(pinnedListIdsProvider, (_, _) {});
    await pumpEventQueue();
    return container;
  }

  test('each account sees the pins saved on it', () async {
    final a = await start(
      _profile('user-a', {
        PinnedListIdsNotifier.prefsKey: ['a-list', 'collection_10'],
      }),
    );
    final b = await start(
      _profile('user-b', {
        PinnedListIdsNotifier.prefsKey: ['b-list'],
      }),
    );

    expect(a.read(pinnedListIdsProvider), {'a-list', 'collection_10'});
    expect(b.read(pinnedListIdsProvider), {'b-list'});
  });

  test('a pin is saved on the account', () async {
    final container = await start(
      _profile('user-a', {
        PinnedListIdsNotifier.prefsKey: ['a'],
      }),
    );

    await container.read(pinnedListIdsProvider.notifier).togglePin('b');

    expect(container.read(pinnedListIdsProvider), {'a', 'b'});
    verify(
      () => profiles.patchPreferences('user-a', {
        PinnedListIdsNotifier.prefsKey: ['a', 'b'],
      }),
    ).called(1);
  });

  test('a failed save brings the old pins back and rethrows', () async {
    when(
      () => profiles.patchPreferences(any(), any()),
    ).thenThrow(const NetworkFailure('offline'));
    final container = await start(
      _profile('user-a', {
        PinnedListIdsNotifier.prefsKey: ['a'],
      }),
    );

    await expectLater(
      container.read(pinnedListIdsProvider.notifier).togglePin('a'),
      throwsA(isA<NetworkFailure>()),
    );
    expect(container.read(pinnedListIdsProvider), {'a'});
  });

  group('pins an older build kept on the device', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        PinnedListIdsNotifier.legacyKey: ['old'],
      });
    });

    test('move to an account that has none, once', () async {
      when(
        () => profiles.fetchPreferences('user-a'),
      ).thenAnswer((_) async => {});

      final container = await start(_profile('user-a', {}));

      expect(container.read(pinnedListIdsProvider), {'old'});
      verify(
        () => profiles.patchPreferences('user-a', {
          PinnedListIdsNotifier.prefsKey: ['old'],
        }),
      ).called(1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PinnedListIdsNotifier.legacyKey), isNull);
    });

    test('never replace pins another device already saved', () async {
      // The cached profile is older than the server's.
      when(() => profiles.fetchPreferences('user-a')).thenAnswer(
        (_) async => {
          PinnedListIdsNotifier.prefsKey: <String>['newer'],
        },
      );

      await start(_profile('user-a', {}));

      verifyNever(() => profiles.patchPreferences(any(), any()));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PinnedListIdsNotifier.legacyKey), isNull);
    });

    test('stay on the device when the server cannot be read', () async {
      when(
        () => profiles.fetchPreferences('user-a'),
      ).thenThrow(const NetworkFailure('offline'));

      final container = await start(_profile('user-a', {}));

      expect(container.read(pinnedListIdsProvider), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PinnedListIdsNotifier.legacyKey), ['old']);
    });
  });
}
