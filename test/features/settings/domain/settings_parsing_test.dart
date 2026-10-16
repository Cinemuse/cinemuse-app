import 'dart:convert';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/models/stremio_addon.dart';
import 'package:cinemuse_app/core/utils/url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _profile(Map<String, dynamic> preferences) => Profile(
  id: 'user1',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  preferences: preferences,
);

void main() {
  group('UserSettings Parsing', () {
    test(
      'UserSettings.fromProfile handles installedAddons as List of Maps',
      () {
        final settings = UserSettings.fromProfile(
          _profile(const {}),
          secrets: {
            'installedAddons': [
              {
                'id': 'torrentio',
                'name': 'Torrentio',
                'baseUrl': 'https://torrentio.strem.io',
                'enabled': true,
              },
            ],
          },
        );
        expect(settings.installedAddons.length, 1);
        expect(settings.installedAddons[0].id, 'torrentio');
      },
    );

    test(
      'UserSettings.fromProfile handles installedAddons as List of JSON Strings',
      () {
        final settings = UserSettings.fromProfile(
          _profile(const {}),
          secrets: {
            'installedAddons': [
              jsonEncode({
                'id': 'torrentio',
                'name': 'Torrentio',
                'baseUrl': 'https://torrentio.strem.io',
                'enabled': true,
              }),
            ],
          },
        );
        expect(settings.installedAddons.length, 1);
        expect(settings.installedAddons[0].id, 'torrentio');
      },
    );

    test('UserSettings.fromProfile handles mixed Maps and Strings', () {
      final settings = UserSettings.fromProfile(
        _profile(const {}),
        secrets: {
          'installedAddons': [
            {
              'id': 'map_addon',
              'name': 'Map Addon',
              'baseUrl': 'https://map.io',
              'enabled': true,
            },
            jsonEncode({
              'id': 'string_addon',
              'name': 'String Addon',
              'baseUrl': 'https://string.io',
              'enabled': true,
            }),
          ],
        },
      );
      expect(settings.installedAddons.length, 2);
      expect(settings.installedAddons.any((a) => a.id == 'map_addon'), isTrue);
      expect(
        settings.installedAddons.any((a) => a.id == 'string_addon'),
        isTrue,
      );
    });

    test('StremioAddon.fromJson handles shorthand resources and catalogs', () {
      final json = {
        'id': 'shorthand_test',
        'name': 'Shorthand Test',
        'baseUrl': 'https://test.io',
        'resources': ['stream', 'meta'],
        'catalogs': ['movie.top', 'tv.top'],
      };

      final addon = StremioAddon.fromJson(json);

      expect(addon.resources.length, 2);
      expect(addon.resources[0]['name'], 'stream');
      expect(addon.resources[1]['name'], 'meta');

      expect(addon.catalogs.length, 2);
      expect(addon.catalogs[0]['name'], 'movie.top');
      expect(addon.catalogs[1]['name'], 'tv.top');

      expect(addon.isStreamingAddon, isTrue);
    });

    test('StremioAddon.fromJson normalizes series to tv', () {
      final json = {
        'id': 'series_test',
        'name': 'Series Test',
        'baseUrl': 'https://test.io',
        'types': ['series', 'movie'],
        'resources': ['stream'],
      };

      final addon = StremioAddon.fromJson(json);
      expect(addon.types, contains('tv'));
      expect(addon.types, contains('movie'));
      expect(addon.types, isNot(contains('series')));
    });

    test('StremioAddon.fromJson parses queryParams correctly', () {
      final json = {
        'id': 'qp_test',
        'name': 'QP Test',
        'baseUrl': 'https://test.io/config',
        'queryParams': 'apikey=123&user=456',
        'resources': ['stream'],
      };

      final addon = StremioAddon.fromJson(json);
      expect(addon.queryParams, equals('apikey=123&user=456'));
      expect(addon.baseUrl, equals('https://test.io/config'));
    });

    // REV-82: one stored value of the wrong type must not fail the whole
    // load (that blocked every save); it falls back to its default.
    test('UserSettings.fromProfile ignores values of the wrong type', () {
      final profile = Profile(
        id: 'user_bad',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        preferences: {
          'showSubtitles': 'false',
          'appLanguage': 7,
          'liveTvBufferSize': '1024',
          'liveTvQuality': true,
          'enableTorBox': true,
        },
      );

      final settings = UserSettings.fromProfile(
        profile,
        secrets: {
          'torBoxKey': 7,
          'installedAddons': [
            42,
            {
              'id': 'torrentio',
              'name': 'Torrentio',
              'baseUrl': 'https://torrentio.strem.io',
            },
          ],
        },
      );
      expect(settings.showSubtitles, isTrue);
      expect(settings.appLanguage, 'en');
      expect(settings.liveTvBufferSize, 512);
      expect(settings.liveTvQuality, StreamQuality.hd);
      expect(settings.installedAddons.map((a) => a.id), ['torrentio']);
      expect(settings.enableTorBox, isTrue);
      expect(settings.torBoxKey, '');
    });

    test('UserSettings handles TorBox preferences and serialization', () {
      final profile = Profile(
        id: 'user_tb',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        preferences: {
          'enableTorBox': true,
          'torBoxKey': 'stale_key_in_preferences',
          'preferredDebridProvider': 'torbox',
        },
      );

      final settings = UserSettings.fromProfile(
        profile,
        secrets: {'torBoxKey': 'test_tb_key'},
      );
      expect(settings.enableTorBox, isTrue);
      expect(settings.torBoxKey, equals('test_tb_key'));
      expect(settings.preferredDebridProvider, equals('torbox'));

      final json = settings.toPreferencesJson();
      expect(json['enableTorBox'], isTrue);
      expect(json['preferredDebridProvider'], equals('torbox'));
      expect(settings.toSecretsJson()['torBoxKey'], equals('test_tb_key'));
    });

    // SEC-04: keys and addons are saved only to the owner-only row.
    test('keys and addons never go into the preferences', () {
      final settings = const UserSettings().copyWith(
        realDebridKey: 'secret-rd',
        torBoxKey: 'secret-tb',
        openSubtitlesKey: 'secret-os',
        installedAddons: [
          StremioAddon.fromJson(const {'id': 'secret-addon'}),
        ],
      );

      expect(settings.preferencesChangedSince(const UserSettings()), isEmpty);
      expect(
        jsonEncode(settings.toPreferencesJson()),
        isNot(contains('secret')),
      );
      expect(settings.secretsChangedSince(const UserSettings()).keys, [
        'realDebridKey',
        'torBoxKey',
        'openSubtitlesKey',
        'installedAddons',
      ]);
    });
  });

  group('UrlUtils Tests', () {
    test('splitStremioUrl splits correctly', () {
      const url =
          'https://torrentio.strem.fun/config|key=val/manifest.json?apikey=abc';
      final parts = UrlUtils.splitStremioUrl(url);

      expect(
        parts.baseUrl,
        equals('https://torrentio.strem.fun/config|key=val'),
      );
      expect(parts.queryParams, equals('apikey=abc'));
    });

    test('splitStremioUrl handles stremio:// protocol', () {
      const url = 'stremio://torrentio.strem.fun/manifest.json';
      final parts = UrlUtils.splitStremioUrl(url);

      expect(parts.baseUrl, equals('https://torrentio.strem.fun'));
      expect(parts.queryParams, isNull);
    });
  });
}
