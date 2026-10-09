import 'package:cinemuse_app/core/services/streaming/debrid/base_debrid_service.dart';
import 'package:cinemuse_app/core/services/streaming/debrid/composite_debrid_service.dart';
import 'package:cinemuse_app/core/services/streaming/debrid/torbox_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockDebridService extends Mock implements BaseDebridService {}

void main() {
  group('TorBoxService Tests', () {
    late MockDio mockDio;
    late TorBoxService torBoxService;

    setUp(() {
      mockDio = MockDio();
      torBoxService = TorBoxService(mockDio, 'test_api_key');
    });

    test('isEnabled is true when apiKey is present', () {
      expect(torBoxService.isEnabled, isTrue);
      expect(TorBoxService(mockDio, '').isEnabled, isFalse);
    });

    test('checkAvailability parses cached object response properly', () async {
      when(
        () => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {
            'success': true,
            'data': {
              'HASH1': true,
              'HASH2': false,
              'HASH3': {'id': 10, 'name': 'Cached Movie.mkv'},
            },
          },
        ),
      );

      final result = await torBoxService.checkAvailability([
        'hash1',
        'hash2',
        'hash3',
      ]);
      expect(result['hash1'], isTrue);
      expect(result['hash2'], isFalse);
      expect(result['hash3'], isTrue);
    });

    test(
      'resolve successfully adds torrent and requests download link',
      () async {
        final candidate = StreamCandidate(
          kind: StreamSourceKind.vod,
          title: 'Inception 1080p',
          infoHash: 'hash123',
          magnet: 'magnet:?xt=urn:btih:hash123&dn=Inception',
          provider: 'AnimeTosho',
        );

        when(
          () => mockDio.post(
            'https://api.torbox.app/v1/api/torrents/createtorrent',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: ''),
            data: {
              'success': true,
              'data': {'torrent_id': 42},
            },
          ),
        );

        when(
          () => mockDio.get(
            'https://api.torbox.app/v1/api/torrents/mylist',
            queryParameters: {'id': 42},
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: ''),
            data: {
              'success': true,
              'data': {
                'id': 42,
                'name': 'Inception.1080p.mkv',
                'files': [
                  {'id': 1, 'name': 'Inception.1080p.mkv', 'size': 2000000000},
                ],
              },
            },
          ),
        );

        when(
          () => mockDio.get(
            'https://api.torbox.app/v1/api/torrents/requestdl',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: ''),
            data: {
              'success': true,
              'data': 'https://cdn.torbox.app/download/inception.mkv',
            },
          ),
        );

        final resolved = await torBoxService.resolve(candidate);
        expect(resolved, isNotNull);
        expect(
          resolved!.url,
          equals('https://cdn.torbox.app/download/inception.mkv'),
        );
        expect(resolved.provider, equals('TorBox'));
        expect(resolved.activeFileId, equals(1));
      },
    );
  });

  group('CompositeDebridService Tests', () {
    late MockDebridService serviceA;
    late MockDebridService serviceB;

    setUp(() {
      serviceA = MockDebridService();
      serviceB = MockDebridService();

      when(() => serviceA.name).thenReturn('Real-Debrid');
      when(() => serviceA.isEnabled).thenReturn(true);
      when(() => serviceB.name).thenReturn('TorBox');
      when(() => serviceB.isEnabled).thenReturn(true);
    });

    test('checkDetailedAvailability merges results across providers', () async {
      when(
        () => serviceA.checkAvailability(['hash1', 'hash2']),
      ).thenAnswer((_) async => {'hash1': true, 'hash2': false});

      when(
        () => serviceB.checkAvailability(['hash1', 'hash2']),
      ).thenAnswer((_) async => {'hash1': false, 'hash2': true});

      final composite = CompositeDebridService([serviceA, serviceB]);
      final detailed = await composite.checkDetailedAvailability([
        'hash1',
        'hash2',
      ]);

      expect(detailed['hash1'], contains('Real-Debrid'));
      expect(detailed['hash1'], isNot(contains('TorBox')));
      expect(detailed['hash2'], contains('TorBox'));
      expect(detailed['hash2'], isNot(contains('Real-Debrid')));
    });

    test(
      'resolve fails over to secondary provider when preferred provider fails',
      () async {
        final candidate = StreamCandidate(
          kind: StreamSourceKind.vod,
          title: 'Dune Part Two',
          infoHash: 'dune_hash',
          magnet: 'magnet:?xt=urn:btih:dune_hash',
          provider: 'Torrentio',
          cachedOn: {'Real-Debrid': true, 'TorBox': true},
        );

        // Service A (Real-Debrid) fails/rejects due to copyright or error
        when(
          () => serviceA.resolve(candidate),
        ).thenThrow(Exception('Copyright takedown / 403'));

        // Service B (TorBox) succeeds
        final fallbackStream = ResolvedStream(
          url: 'https://cdn.torbox.app/dune.mkv',
          provider: 'TorBox',
          candidate: candidate,
        );
        when(
          () => serviceB.resolve(candidate),
        ).thenAnswer((_) async => fallbackStream);

        final composite = CompositeDebridService([
          serviceA,
          serviceB,
        ], preferredProvider: 'Real-Debrid');

        final result = await composite.resolve(candidate);
        expect(result, isNotNull);
        expect(result!.url, equals('https://cdn.torbox.app/dune.mkv'));
        expect(result.provider, equals('TorBox'));
        verify(() => serviceA.resolve(candidate)).called(1);
        verify(() => serviceB.resolve(candidate)).called(1);
      },
    );
  });
}
