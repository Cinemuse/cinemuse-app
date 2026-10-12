import 'package:cinemuse_app/features/live_tv/data/m3u_parser.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Channel quality helpers', () {
    test('quality returns highest from links', () {
      final channel = Channel(
        lcn: 1,
        name: 'Test',
        logo: 'logo',
        links: [
          StreamLink(url: 'http://a', quality: StreamQuality.sd),
          StreamLink(url: 'http://b', quality: StreamQuality.fhd),
        ],
      );

      expect(channel.quality, StreamQuality.fhd);
    });
  });

  group('StreamLink.fromJson', () {
    test('parses flat format (quality/codec at root)', () {
      final json = {
        'url': 'http://stream.com/live.ts',
        'quality': 'FHD',
        'codec': 'H.265',
      };

      final link = StreamLink.fromJson(json);

      expect(link.url, 'http://stream.com/live.ts');
      expect(link.quality, StreamQuality.fhd);
      expect(link.codec, 'H.265');
    });

    test('parses nested format (quality inside metadata)', () {
      final json = {
        'url': 'http://stream.com/live.ts',
        'metadata': {'quality': 'HD', 'codec': 'H.264'},
      };

      final link = StreamLink.fromJson(json);

      expect(link.url, 'http://stream.com/live.ts');
      expect(link.quality, StreamQuality.hd);
      expect(link.codec, 'H.264');
    });

    test('flat format takes priority over nested when both present', () {
      final json = {
        'url': 'http://stream.com/live.ts',
        'quality': '4K',
        'codec': '',
        'metadata': {'quality': 'SD', 'codec': 'H.264'},
      };

      final link = StreamLink.fromJson(json);

      expect(link.quality, StreamQuality.uhd);
      // Empty codec at root means null
      expect(link.codec, isNull);
    });

    test('defaults to SD when no quality provided', () {
      final json = {'url': 'http://stream.com/live.ts'};

      final link = StreamLink.fromJson(json);

      expect(link.quality, StreamQuality.sd);
      expect(link.codec, isNull);
    });
  });

  group('M3uParser', () {
    test(
      'merges multiple streams for the same channel with provider and quality attributes',
      () {
        const m3u = '''#EXTM3U
#EXTINF:-1 tvg-id="dlhd_862" tvg-name="Sky Cinema Comedy HD" tvg-logo="https://logo.png" group-title="Cinema" quality="FHD" provider="IPTV 1080p",Sky Cinema Comedy HD
http://0g7h1ljf4wx.sasa24.xyz/live/mariopollena/sasy/24744.ts
#EXTINF:-1 tvg-id="dlhd_862" tvg-name="Sky Cinema Comedy HD" tvg-logo="https://logo.png" group-title="Cinema" quality="HD" provider="CDN Fallback",Sky Cinema Comedy HD
https://enfaqgwmuytoxkxgqqvp.supabase.co/functions/v1/live-tv-resolver/stream?channel=dlhd_862
''';

        final channels = M3uParser.parse(m3u);
        expect(channels.length, 1);
        final ch = channels.first;
        expect(ch.name, 'Sky Cinema Comedy HD');
        expect(ch.epgId, 'dlhd_862');
        expect(ch.links.length, 2);
        expect(ch.links[0].provider, 'IPTV 1080p');
        expect(ch.links[0].quality, StreamQuality.fhd);
        expect(ch.links[1].provider, 'CDN Fallback');
        expect(ch.links[1].quality, StreamQuality.hd);
      },
    );

    test('extracts tvg-chno and preserves explicit LCN', () {
      const m3u = '''#EXTM3U
#EXTINF:-1 tvg-id="rai1" tvg-chno="1" tvg-name="Rai 1 HD" tvg-logo="https://logo.png" group-title="Nazionali",Rai 1 HD
http://stream.com/rai1.m3u8
#EXTINF:-1 tvg-id="dlhd_870" tvg-chno="202" tvg-name="Sky Sport Calcio HD" tvg-logo="https://logo.png" group-title="Sky Sport",Sky Sport Calcio HD
http://stream.com/skysportcalcio.m3u8
''';

      final channels = M3uParser.parse(m3u);
      expect(channels.length, 2);
      expect(channels[0].lcn, 1);
      expect(channels[1].lcn, 202);
    });
  });

  group('Channel.copyWith', () {
    test('updates links and fields properly', () {
      final original = Channel(
        lcn: 1,
        name: 'Channel A',
        logo: 'logo1.png',
        links: [StreamLink(url: 'http://a.com/1.m3u8')],
      );

      final updated = original.copyWith(
        links: [
          StreamLink(url: 'http://a.com/1.m3u8'),
          StreamLink(url: 'http://a.com/2.ts', provider: 'IPTV'),
        ],
      );

      expect(updated.lcn, 1);
      expect(updated.name, 'Channel A');
      expect(updated.links.length, 2);
      expect(updated.links[1].provider, 'IPTV');
    });
  });

  group('Channel.uniqueId (REV-113)', () {
    test('does not change when the channel number changes', () {
      const a = Channel(lcn: 2000, name: 'Rai 1 HD', logo: '');
      const b = Channel(lcn: 2001, name: 'Rai 1', logo: '');
      expect(a.uniqueId, b.uniqueId);
      expect(a.uniqueId, 'name:rai 1');
    });

    test('uses the guide id when there is one', () {
      const channel = Channel(
        lcn: 1,
        name: 'Rai 1',
        logo: '',
        epgId: ' Rai1.it ',
      );
      expect(channel.uniqueId, 'epg:rai1.it');
    });
  });
}
