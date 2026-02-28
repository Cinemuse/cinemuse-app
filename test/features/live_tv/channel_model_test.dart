import 'dart:io';

import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Channel.fromJson', () {
    test('extracts basic fields correctly', () {
      final json = {
        'lcn': 1,
        'name': 'Rai 1',
        'logo': 'rai1.svg',
        'hd': true,
        'type': 'hls',
        'url': 'http://example.com/stream.m3u8',
        'subtitle': 'General TV',
        'radio': false,
        'adult': false,
      };

      final channel = Channel.fromJson(json);

      expect(channel.lcn, 1);
      expect(channel.name, 'Rai 1');
      expect(channel.logo, 'rai1.svg');
      expect(channel.hd, true);
      expect(channel.uhd, false);
      expect(channel.type, 'hls');
      expect(channel.url, 'http://example.com/stream.m3u8');
      expect(channel.subtitle, 'General TV');
      expect(channel.isRadio, false);
      expect(channel.isAdult, false);
    });

    test('prioritizes geoblock.url over main url if available', () {
      final json = {
        'lcn': 2,
        'type': 'hls',
        'url': 'http://main.stream.com/stream.m3u8',
        'geoblock': {
          'url': 'http://geo.stream.com/stream.m3u8',
        },
      };

      final channel = Channel.fromJson(json);

      expect(channel.url, 'http://geo.stream.com/stream.m3u8');
      expect(channel.isGeoblocked, true);
    });

    test('falls back to fallback.url if others are missing', () {
      final json = {
        'lcn': 3,
        'type': 'hls',
        'fallback': {
          'url': 'http://fallback.stream.com/stream.m3u8',
        },
      };

      final channel = Channel.fromJson(json);

      expect(channel.url, 'http://fallback.stream.com/stream.m3u8');
    });

    test('filters out akamaized.net domains if a better URL is available', () {
      final json = {
        'lcn': 4,
        'type': 'hls',
        'geoblock': {
          'url': 'http://example.akamaized.net/stream.m3u8', // Should skip this
        },
        'url': 'http://better-host.com/stream.m3u8', // Should pick this
      };

      final channel = Channel.fromJson(json);

      expect(channel.url, 'http://better-host.com/stream.m3u8');
    });

    test('accepts akamaized.net as last resort if no other HTTP url exists', () {
      final json = {
        'lcn': 5,
        'type': 'hls',
        'url': 'http://only-choice.akamaized.net/stream.m3u8',
        'fallback': {
          'url': 'zappr://not-http',
        }
      };

      final channel = Channel.fromJson(json);

      expect(channel.url, 'http://only-choice.akamaized.net/stream.m3u8');
    });
  });

  group('Channel.isPlayable', () {
    test('is unplayable if disabled', () {
      final channel = Channel(
        lcn: 1,
        name: 'Test',
        logo: 'logo',
        type: 'hls',
        url: 'http://test',
        isDisabled: true,
      );

      expect(channel.isPlayable, false);
    });

    test('is unplayable if radio or adult', () {
      final radioItem = Channel(
        lcn: 1,
        name: 'Radio',
        logo: 'logo',
        type: 'hls',
        url: 'http://test',
        isRadio: true,
      );

      final adultItem = Channel(
        lcn: 2,
        name: 'Adult',
        logo: 'logo',
        type: 'hls',
        url: 'http://test',
        isAdult: true,
      );

      expect(radioItem.isPlayable, false);
      expect(adultItem.isPlayable, false);
    });

    test('is unplayable if url starts with zappr://', () {
      final channel = Channel(
        lcn: 1,
        name: 'Test',
        logo: 'logo',
        type: 'hls',
        url: 'zappr://fake-stream',
      );

      expect(channel.isPlayable, false);
    });

    test('handles HLS streams correctly', () {
      final channel = Channel(
        lcn: 1,
        name: 'HLS Stream',
        logo: 'logo',
        type: 'hls',
        url: 'http://test.m3u8',
      );

      expect(channel.isPlayable, true);
    });

    test('DASH streams are evaluated dynamically based on platform', () {
      final channel = Channel(
        lcn: 1,
        name: 'DASH Stream',
        logo: 'logo',
        type: 'dash',
        url: 'http://test.mpd',
      );

      if (Platform.isWindows) {
        // We expect it to be false on Windows specifically.
        expect(channel.isPlayable, false);
      } else {
        expect(channel.isPlayable, true);
      }
    });
  });

  group('Channel.logoUrl', () {
    test('sanitizes accents and replaces svg with png', () {
      final channel = Channel(
        lcn: 1,
        name: 'Test',
        logo: 'Caffè_e_TV_Papà.svg',
        type: 'hls',
        url: 'http://test',
      );

      final url = channel.logoUrl;
      
      expect(url, contains('.png'));
      expect(url, isNot(contains('.svg')));
      expect(url, isNot(contains('è')));
      expect(url, isNot(contains('à')));
      expect(url, contains('caffe_e_tv_papa.png'));
    });
  });
}
