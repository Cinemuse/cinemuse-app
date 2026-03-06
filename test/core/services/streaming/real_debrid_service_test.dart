import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/core/services/streaming/debrid/real_debrid_service.dart';

class MockDio extends Mock implements Dio {}
class MockResponse<T> extends Mock implements Response<T> {}

class FakeOptions extends Fake implements Options {}
class FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  late RealDebridService service;
  late MockDio mockDio;

  setUpAll(() {
    registerFallbackValue(FakeOptions());
    registerFallbackValue(FakeRequestOptions());
  });

  setUp(() {
    mockDio = MockDio();
    service = RealDebridService(mockDio, 'test_key');
  });

  group('RealDebridService.checkAvailability', () {
    test('Should return correct availability map', () async {
      final response = MockResponse<Map<String, dynamic>>();
      when(() => response.data).thenReturn({
        'hash1': {
          'rd': [
            {'1': {}}
          ]
        },
        'hash2': {}
      });

      when(() => mockDio.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          )).thenAnswer((_) async => response);

      final result = await service.checkAvailability(['hash1', 'hash2']);

      expect(result['hash1'], isTrue);
      expect(result['hash2'], isFalse);
    });

    test('Should handle errors gracefully', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any(), options: any(named: 'options')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      final result = await service.checkAvailability(['hash1']);
      expect(result['hash1'], isFalse);
    });
  });

  group('RealDebridService.resolve', () {
    test('Should resolve magnet successfully', () async {
      // 1. Add Magnet
      final addResp = MockResponse<Map<String, dynamic>>();
      when(() => addResp.data).thenReturn({'id': 'torrent_id'});
      when(() => mockDio.post<Map<String, dynamic>>(
        any(that: contains('/addMagnet')),
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).thenAnswer((_) async => addResp);

      // 2. Get Info
      final infoResp = MockResponse<Map<String, dynamic>>();
      when(() => infoResp.data).thenReturn({
        'status': 'downloaded',
        'files': [
          {'id': 1, 'path': '/Movie.1080p.mkv', 'selected': 1, 'bytes': 1000}
        ],
        'links': ['https://rd-link']
      });
      when(() => mockDio.get<Map<String, dynamic>>(
        any(that: contains('/info/torrent_id')),
        options: any(named: 'options'),
      )).thenAnswer((_) async => infoResp);

      // 3. Unrestrict
      final unrestrictResp = MockResponse<Map<String, dynamic>>();
      when(() => unrestrictResp.data).thenReturn({'download': 'https://final-stream-url'});
      when(() => mockDio.post<Map<String, dynamic>>(
        any(that: contains('/unrestrict/link')),
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).thenAnswer((_) async => unrestrictResp);

      final result = await service.resolve('magnet_link');

      expect(result?['url'], equals('https://final-stream-url'));
    });
  });
}
