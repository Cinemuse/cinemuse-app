import 'dart:async';
import 'dart:io';

import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/core/data/api_keys_repository.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

/// `select()` on `api_keys`: its rows, or the error a dropped connection
/// gives (the Supabase client throws a `SocketException`).
class _FakeKeysTable extends Fake implements SupabaseQueryBuilder {
  final List<Map<String, dynamic>>? rows;

  /// The columns of each `select()`, in call order.
  final selects = <String>[];

  _FakeKeysTable([this.rows]);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) {
    selects.add(columns);
    return _FakeSelect(rows);
  }
}

class _FakeSelect extends Fake
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  final List<Map<String, dynamic>>? rows;

  _FakeSelect(this.rows);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) {
    final rows = this.rows;
    final result = rows == null
        ? Future<List<Map<String, dynamic>>>.error(
            const SocketException('offline'),
          )
        : Future.value(rows);
    return result.then(onValue, onError: onError);
  }
}

const _tmdbRow = {'name': 'tmdb', 'value': 'server-key'};

void main() {
  late _MockSupabaseClient client;

  void serve(_FakeKeysTable table) {
    when(() => client.from('api_keys')).thenAnswer((_) => table);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _MockSupabaseClient();
  });

  group('ApiKeysRepository.tmdbKey', () {
    test('the server key is used and kept for offline starts', () async {
      serve(
        _FakeKeysTable([
          {'name': 'other', 'value': 'other-key'},
          _tmdbRow,
        ]),
      );
      expect(await ApiKeysRepository(client).tmdbKey(), 'server-key');

      serve(_FakeKeysTable());
      expect(await ApiKeysRepository(client).tmdbKey(), 'server-key');
    });

    test('a key gone from the server: the kept one is used', () async {
      serve(_FakeKeysTable([_tmdbRow]));
      await ApiKeysRepository(client).tmdbKey();

      serve(_FakeKeysTable([]));
      expect(await ApiKeysRepository(client).tmdbKey(), 'server-key');
    });

    test('offline with no kept key throws a network failure', () async {
      serve(_FakeKeysTable());
      await expectLater(
        ApiKeysRepository(client).tmdbKey(),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('no key on the server and none kept throws not found', () async {
      serve(
        _FakeKeysTable([
          {'name': 'tmdb', 'value': ''},
        ]),
      );
      await expectLater(
        ApiKeysRepository(client).tmdbKey(),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('tmdbApiKeyProvider', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        retry: noProviderRetry,
        overrides: [supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a good key is downloaded once per session', () async {
      final table = _FakeKeysTable([_tmdbRow]);
      serve(table);
      final c = container();

      await c.read(tmdbApiKeyProvider.future);
      await Future<void>.delayed(Duration.zero);
      await c.read(tmdbApiKeyProvider.future);

      expect(table.selects, ['name, value']);
    });

    test('a failed download is tried again at the next use', () async {
      serve(_FakeKeysTable());
      final c = container();

      await expectLater(
        c.read(tmdbApiKeyProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      await Future<void>.delayed(Duration.zero);
      serve(_FakeKeysTable([_tmdbRow]));

      expect(await c.read(tmdbApiKeyProvider.future), 'server-key');
    });
  });
}
