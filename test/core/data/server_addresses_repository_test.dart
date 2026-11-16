import 'dart:async';
import 'dart:io';

import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

/// `select()` on `server_addresses`: its rows, or the error a dropped connection
/// gives (the Supabase client throws a `SocketException`).
class _FakeSitesTable extends Fake implements SupabaseQueryBuilder {
  final List<Map<String, dynamic>>? rows;

  /// The columns of each `select()`, in call order.
  final selects = <String>[];

  _FakeSitesTable([this.rows]);

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

void main() {
  late _MockSupabaseClient client;

  void serve(_FakeSitesTable table) {
    when(() => client.from('server_addresses')).thenAnswer((_) => table);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _MockSupabaseClient();
  });

  group('ServerAddressesRepository.load (STR-08)', () {
    test('a server list is used and kept for offline starts', () async {
      serve(
        _FakeSitesTable([
          {
            'key': ServerAddress.movieSite.key,
            'address': 'https://movies.example',
            'display_name': 'Movie Site',
          },
        ]),
      );
      final first = await ServerAddressesRepository(client).load();
      expect(first.baseUrl(ServerAddress.movieSite), 'https://movies.example');

      serve(_FakeSitesTable());
      final offline = await ServerAddressesRepository(client).load();
      expect(
        offline.baseUrl(ServerAddress.movieSite),
        'https://movies.example',
      );
      expect(offline.name(ServerAddress.movieSite), 'Movie Site');
    });

    test('a copy saved before the names came counts as none', () async {
      SharedPreferences.setMockInitialValues({
        'scraper_sites':
            '{"${ServerAddress.movieSite.key}": "https://movies.example"}',
      });
      serve(_FakeSitesTable());

      await expectLater(
        ServerAddressesRepository(client).load(),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a site removed on the server is gone from the kept list', () async {
      serve(
        _FakeSitesTable([
          {
            'key': ServerAddress.movieSite.key,
            'address': 'https://movies.example',
          },
        ]),
      );
      await ServerAddressesRepository(client).load();
      serve(_FakeSitesTable([]));
      await ServerAddressesRepository(client).load();

      serve(_FakeSitesTable());
      final offline = await ServerAddressesRepository(client).load();
      expect(offline.address(ServerAddress.movieSite), isNull);
    });

    test('offline with no kept list throws a network failure', () async {
      serve(_FakeSitesTable());
      await expectLater(
        ServerAddressesRepository(client).load(),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('serverAddressesProvider (STR-08)', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        retry: noProviderRetry,
        overrides: [supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a good list is downloaded once per session', () async {
      final table = _FakeSitesTable([
        {
          'key': ServerAddress.movieSite.key,
          'address': 'https://movies.example',
        },
      ]);
      serve(table);
      final c = container();

      await c.read(serverAddressesProvider.future);
      await Future<void>.delayed(Duration.zero);
      await c.read(serverAddressesProvider.future);

      expect(table.selects, ['key, address, display_name']);
    });

    test('a failed download is tried again at the next use', () async {
      final offline = _FakeSitesTable();
      serve(offline);
      final c = container();

      await expectLater(
        c.read(serverAddressesProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      await Future<void>.delayed(Duration.zero);
      serve(
        _FakeSitesTable([
          {
            'key': ServerAddress.movieSite.key,
            'address': 'https://movies.example',
          },
        ]),
      );

      final sites = await c.read(serverAddressesProvider.future);
      expect(sites.baseUrl(ServerAddress.movieSite), 'https://movies.example');
    });
  });
}
