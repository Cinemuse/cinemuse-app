import 'dart:convert';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/stremio_addon.dart';
import 'package:cinemuse_app/core/utils/url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserSettings Parsing', () {
    test('UserSettings.fromProfile handles installedAddons as List of Maps', () {
      final profile = Profile(
        id: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        preferences: {
          'installedAddons': [
            {
              'id': 'torrentio',
              'name': 'Torrentio',
              'baseUrl': 'https://torrentio.strem.io',
              'enabled': true,
            }
          ],
        },
      );

      final settings = UserSettings.fromProfile(profile);
      expect(settings.installedAddons.length, 1);
      expect(settings.installedAddons[0].id, 'torrentio');
    });

    test('UserSettings.fromProfile handles installedAddons as List of JSON Strings', () {
      final profile = Profile(
        id: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        preferences: {
          'installedAddons': [
            jsonEncode({
              'id': 'torrentio',
              'name': 'Torrentio',
              'baseUrl': 'https://torrentio.strem.io',
              'enabled': true,
            })
          ],
        },
      );

      final settings = UserSettings.fromProfile(profile);
      expect(settings.installedAddons.length, 1);
      expect(settings.installedAddons[0].id, 'torrentio');
    });

    test('UserSettings.fromProfile handles mixed Maps and Strings', () {
      final profile = Profile(
        id: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        preferences: {
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
            })
          ],
        },
      );

      final settings = UserSettings.fromProfile(profile);
      expect(settings.installedAddons.length, 2);
      expect(settings.installedAddons.any((a) => a.id == 'map_addon'), isTrue);
      expect(settings.installedAddons.any((a) => a.id == 'string_addon'), isTrue);
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
  });

  group('UrlUtils Tests', () {
    test('splitStremioUrl splits correctly', () {
      const url = 'https://torrentio.strem.fun/config|key=val/manifest.json?apikey=abc';
      final parts = UrlUtils.splitStremioUrl(url);
      
      expect(parts.baseUrl, equals('https://torrentio.strem.fun/config|key=val'));
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
