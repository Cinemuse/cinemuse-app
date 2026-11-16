import 'dart:async';

import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

Profile _profile(String username) => Profile(
  id: 'user-a',
  username: username,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late AppDatabase database;
  late StreamController<Profile?> remote;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    remote = StreamController<Profile?>();
    final repository = _MockProfileRepository();
    when(
      () => repository.watchProfile('user-a'),
    ).thenAnswer((_) => remote.stream);
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        userIdProvider.overrideWithValue('user-a'),
        appDatabaseProvider.overrideWithValue(database),
        profileRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await remote.close();
      await database.close();
    });
  });

  Future<AsyncValue<Profile?>> next() async {
    await pumpEventQueue();
    return container.read(profileStreamProvider);
  }

  group('profileStreamProvider', () {
    // REV-285: the first realtime error ended the updates until a restart.
    test('keeps the updates coming after a stream error', () async {
      container.listen(profileStreamProvider, (_, _) {});

      remote.add(_profile('first'));
      expect((await next()).value?.username, 'first');

      remote.addError(Exception('channel error'));
      expect((await next()).value?.username, 'first');

      remote.add(_profile('after reconnect'));
      final state = await next();
      expect(state.hasError, isFalse);
      expect(state.value?.username, 'after reconnect');
    });

    // REV-90: with nothing to show, an error must not load forever.
    test('shows the error when there is no profile yet', () async {
      container.listen(profileStreamProvider, (_, _) {});

      remote.addError(Exception('offline'));
      expect((await next()).hasError, isTrue);

      remote.add(_profile('back online'));
      expect((await next()).value?.username, 'back online');
    });
  });
}
