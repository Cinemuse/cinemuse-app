import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/streaming/stremio_addon_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late StremioAddonService service;

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    dio = _MockDio();
    service = StremioAddonService(dio);
  });

  void answerWith(Object? data) {
    when(
      () => dio.get<dynamic>(any(), options: any(named: 'options')),
    ).thenAnswer(
      (inv) async => Response<dynamic>(
        requestOptions: RequestOptions(path: inv.positionalArguments.first),
        statusCode: 200,
        data: data,
      ),
    );
  }

  // REV-29: these used to be plain English `Exception`s shown in the UI.
  group('fetchManifest failures', () {
    test('an error answer from the add-on is a ServerFailure', () {
      final request = RequestOptions(path: '/manifest.json');
      when(
        () => dio.get<dynamic>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: request, statusCode: 404),
        ),
      );

      expect(
        service.fetchManifest('https://addon.test/manifest.json'),
        throwsA(
          isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('text that is not a link is a ValidationFailure (REV-240)', () {
      expect(
        service.fetchManifest('not a url'),
        throwsA(isA<ValidationFailure>()),
      );
      verifyNever(
        () => dio.get<dynamic>(any(), options: any(named: 'options')),
      );
    });

    test('a manifest without id or name is a ValidationFailure', () {
      answerWith({'name': 'No id'});

      expect(
        service.fetchManifest('https://addon.test/manifest.json'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('no connection is a NetworkFailure', () {
      when(
        () => dio.get<dynamic>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/manifest.json'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        service.fetchManifest('https://addon.test/manifest.json'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  test('a valid manifest becomes an add-on', () async {
    answerWith({'id': 'org.test', 'name': 'Test', 'version': '1.0.0'});

    final addon = await service.fetchManifest(
      'https://addon.test/manifest.json',
    );

    expect(addon.id, 'org.test');
    expect(addon.baseUrl, 'https://addon.test');
  });
}
