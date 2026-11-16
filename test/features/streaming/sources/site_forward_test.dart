import 'package:cinemuse_app/features/streaming/sources/site_forward.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _listed = 'https://site.example';

Response<String> _homeForwardedTo(List<String> locations) => Response<String>(
  requestOptions: RequestOptions(path: '$_listed/'),
  statusCode: 200,
  data: '<html>',
  redirects: [
    for (final location in locations)
      RedirectRecord(302, 'GET', Uri.parse(location)),
  ],
);

void main() {
  group('addressAfterForward', () {
    test('a home page that stays put keeps the listed address', () {
      expect(addressAfterForward(_listed, _homeForwardedTo([])), _listed);
    });

    test('a new domain is the address for this visit, without its page', () {
      expect(
        addressAfterForward(
          _listed,
          _homeForwardedTo(['https://new.example/home']),
        ),
        'https://new.example',
      );
    });

    test('a page on the same domain is not a move', () {
      expect(
        addressAfterForward(
          _listed,
          _homeForwardedTo(['https://site.example/home']),
        ),
        _listed,
      );
      expect(
        addressAfterForward(_listed, _homeForwardedTo(['/home'])),
        _listed,
      );
    });

    test('a partial address continues from the forward before it', () {
      expect(
        addressAfterForward(
          _listed,
          _homeForwardedTo(['https://new.example/', '/home']),
        ),
        'https://new.example',
      );
    });

    test('the last stop counts: a forward that comes back is not a move', () {
      expect(
        addressAfterForward(
          _listed,
          _homeForwardedTo(['https://other.example/', 'https://site.example/']),
        ),
        _listed,
      );
    });

    test('a forward away from https is ignored', () {
      expect(
        addressAfterForward(_listed, _homeForwardedTo(['http://new.example/'])),
        _listed,
      );
    });
  });
}
