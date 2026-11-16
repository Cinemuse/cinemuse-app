import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServerAddresses (STR-08)', () {
    test('hidden sites have random codes and no built-in copy', () {
      const hidden = [
        ServerAddress.movieSite,
        ServerAddress.animeSite,
        ServerAddress.sportSchedule,
        ServerAddress.animeTorrents,
        ServerAddress.reviews,
      ];

      for (final site in hidden) {
        expect(site.key, matches(RegExp(r'^[a-z0-9]{12}$')));
        expect(site.key, matches(RegExp(r'\d')));
        expect(site.builtIn, isNull);
      }
      final keys = ServerAddress.values.map((site) => site.key);
      expect(keys.toSet(), hasLength(ServerAddress.values.length));
    });

    test("the server's address wins over the built-in copy", () {
      final addresses = ServerAddresses.fromRows([
        {'key': ServerAddress.kitsu.key, 'address': 'https://kitsu.example/'},
      ]);

      expect(addresses.baseUrl(ServerAddress.kitsu), 'https://kitsu.example');
      expect(
        addresses.baseUrl(ServerAddress.updateRepo),
        'https://api.github.com/repos/Cinemuse/cinemuse-app',
      );
    });

    test('keeps only https rows with a host', () {
      final sites = ServerAddresses.fromRows([
        {
          'key': ServerAddress.movieSite.key,
          'address': ' https://movies.example/ ',
        },
        {'key': ServerAddress.animeSite.key, 'address': 'http://anime.example'},
        {'key': ServerAddress.sportSchedule.key, 'address': null},
        'not a row',
      ]);

      expect(sites.address(ServerAddress.movieSite), 'https://movies.example/');
      expect(sites.address(ServerAddress.animeSite), isNull);
      expect(sites.address(ServerAddress.sportSchedule), isNull);
    });

    test('the name shown comes from the row, empty when it has none', () {
      final sites = ServerAddresses.fromRows([
        {
          'key': ServerAddress.movieSite.key,
          'address': 'https://movies.example',
          'display_name': ' Movie Site ',
        },
        {
          'key': ServerAddress.animeSite.key,
          'address': 'https://anime.example',
          'display_name': '',
        },
      ]);

      expect(sites.name(ServerAddress.movieSite), 'Movie Site');
      expect(sites.name(ServerAddress.animeSite), '');
      expect(sites.name(ServerAddress.reviews), '');
      expect(
        ServerAddresses.fromRows(sites.toRows()).name(ServerAddress.movieSite),
        'Movie Site',
      );
    });

    test('baseUrl drops the trailing slash, address keeps the page', () {
      final sites = ServerAddresses.fromRows([
        {
          'key': ServerAddress.movieSite.key,
          'address': 'https://movies.example/',
        },
        {
          'key': ServerAddress.sportSchedule.key,
          'address': 'https://sport.example/guida-tv/',
        },
      ]);

      expect(sites.baseUrl(ServerAddress.movieSite), 'https://movies.example');
      expect(
        sites.address(ServerAddress.sportSchedule),
        'https://sport.example/guida-tv/',
      );
    });
  });
}
