import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/streaming/debrid/real_debrid_service.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

const _api = 'https://api.real-debrid.com/rest/1.0';

Response<dynamic> _ok(dynamic data) => Response(
  requestOptions: RequestOptions(path: ''),
  data: data,
);

final _candidate = StreamCandidate(
  kind: StreamSourceKind.vod,
  title: 'Inception 1080p',
  infoHash: 'hash123',
  magnet: 'magnet:?xt=urn:btih:hash123',
  provider: 'Torrentio',
);

void main() {
  late MockDio dio;
  late RealDebridService service;
  late void Function(String) oldSink;

  setUp(() {
    dio = MockDio();
    service = RealDebridService(dio, 'test_key');
    oldSink = AppLogger.sink;
    AppLogger.sink = (_) {};

    when(
      () => dio.post(
        '$_api/torrents/addMagnet',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _ok({'id': 'T1'}));
    when(
      () => dio.post(
        '$_api/torrents/selectFiles/T1',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _ok(null));
    when(
      () => dio.delete(
        '$_api/torrents/delete/T1',
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _ok(null));
  });

  tearDown(() => AppLogger.sink = oldSink);

  void stubInfo(List<Map<String, dynamic>> answers) {
    var call = 0;
    when(
      () => dio.get('$_api/torrents/info/T1', options: any(named: 'options')),
    ).thenAnswer((_) async {
      final i = call < answers.length ? call : answers.length - 1;
      call++;
      return _ok(answers[i]);
    });
  }

  Future<Response<dynamic>> deleteCall() =>
      dio.delete('$_api/torrents/delete/T1', options: any(named: 'options'));

  void verifyDeleted(int times) {
    if (times == 0) {
      verifyNever(deleteCall);
    } else {
      verify(deleteCall).called(times);
    }
  }

  const movieFile = {
    'id': 1,
    'path': '/Inception.1080p.mkv',
    'bytes': 2000,
    'selected': 0,
  };

  test(
    'checkAvailability makes no network call (RD endpoint is disabled)',
    () async {
      final result = await service.checkAvailability(['hash1', 'hash2']);

      expect(result, isEmpty);
      verifyZeroInteractions(dio);
    },
  );

  test(
    'uncached torrent: returns null and deletes it from the account',
    () async {
      stubInfo([
        {
          'status': 'waiting_files_selection',
          'files': [movieFile],
          'links': [],
        },
        {
          'status': 'downloading',
          'files': [movieFile],
          'links': [],
        },
      ]);

      final result = await service.resolve(_candidate);

      expect(result, isNull);
      verifyDeleted(1);
    },
  );

  test('cached torrent: returns the link and keeps the torrent', () async {
    stubInfo([
      {
        'status': 'downloaded',
        'files': [
          {...movieFile, 'selected': 1},
        ],
        'links': ['https://real-debrid.com/d/ABC'],
      },
    ]);
    when(
      () => dio.post(
        '$_api/unrestrict/link',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => _ok({
        'download': 'https://cdn.rd/inception.mkv',
        'mimeType': 'video/x-matroska',
        'filename': 'Inception.1080p.mkv',
      }),
    );

    final result = await service.resolve(_candidate);

    expect(result, isNotNull);
    expect(result!.url, 'https://cdn.rd/inception.mkv');
    expect(result.activeFileId, 1);
    verifyDeleted(0);
  });

  test('torrent with no video file: returns null and deletes it', () async {
    stubInfo([
      {
        'status': 'waiting_files_selection',
        'files': [
          {'id': 1, 'path': '/readme.txt', 'bytes': 10, 'selected': 0},
        ],
        'links': [],
      },
    ]);

    final result = await service.resolve(_candidate);

    expect(result, isNull);
    verifyDeleted(1);
    verifyNever(
      () => dio.post(
        '$_api/torrents/selectFiles/T1',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    );
  });

  test('RD error after adding: throws AuthFailure and still deletes', () async {
    when(
      () => dio.get('$_api/torrents/info/T1', options: any(named: 'options')),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 401,
        ),
      ),
    );

    await expectLater(service.resolve(_candidate), throwsA(isA<AuthFailure>()));
    verifyDeleted(1);
  });

  test('no internet when adding: throws NetworkFailure', () async {
    when(
      () => dio.post(
        '$_api/torrents/addMagnet',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ),
    );

    await expectLater(
      service.resolve(_candidate),
      throwsA(isA<NetworkFailure>()),
    );
    verifyDeleted(0);
  });

  test(
    'torrent blocked by RD (451): returns null, nothing to delete',
    () async {
      when(
        () => dio.post(
          '$_api/torrents/addMagnet',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 451,
          ),
        ),
      );

      expect(await service.resolve(_candidate), isNull);
      verifyDeleted(0);
    },
  );

  test('a failed cleanup does not hide the result', () async {
    stubInfo([
      {
        'status': 'downloading',
        'files': [
          {...movieFile, 'selected': 1},
        ],
        'links': [],
      },
    ]);
    when(
      () => dio.delete(
        '$_api/torrents/delete/T1',
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ),
    );

    final result = await service.resolve(_candidate);

    expect(result, isNull);
  });
}
