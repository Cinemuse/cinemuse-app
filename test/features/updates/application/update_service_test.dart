import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _builtIn = 'https://api.github.com/repos/Cinemuse/cinemuse-app';

String _repoFrom(String address) => releasesRepo(
  ServerAddresses.fromRows([
    {'key': ServerAddress.updateRepo.key, 'address': address},
  ]),
);

void main() {
  group('linuxUpdateUrl', () {
    Map<String, String> asset(String name) => {
      'name': name,
      'browser_download_url': 'https://example.test/$name',
    };

    test('the compressed folder, even with the .deb first in the list', () {
      expect(
        linuxUpdateUrl([
          asset('app-x86_64-release.apk'),
          asset('cinemuse_2.0.0_amd64.deb'),
          asset('cinemuse-windows.zip'),
          asset('cinemuse-linux-x64.tar.gz'),
          asset('SHA256SUMS'),
        ]),
        'https://example.test/cinemuse-linux-x64.tar.gz',
      );
    });

    test('a release without it: no update link, not the .deb', () {
      expect(linuxUpdateUrl([asset('cinemuse_2.0.0_amd64.deb')]), isNull);
    });
  });

  group('releasesRepo', () {
    test("a GitHub repo on the server's list is used", () {
      expect(
        _repoFrom('https://api.github.com/repos/Cinemuse/cinemuse-next/'),
        'https://api.github.com/repos/Cinemuse/cinemuse-next',
      );
    });

    test('no address on the list: the built-in repo', () {
      expect(releasesRepo(ServerAddresses.empty), _builtIn);
    });

    test('any other address: the built-in repo', () {
      for (final address in [
        'https://evil.example/repos/Cinemuse/cinemuse-app',
        'https://api.github.com.evil.example/repos/a/b',
        'https://api.github.com/users/Cinemuse',
        'https://api.github.com/repos/Cinemuse',
        'https://api.github.com/repos/a/b/releases',
        'https://api.github.com/repos/a/b?x=1',
      ]) {
        expect(_repoFrom(address), _builtIn, reason: address);
      }
    });
  });
}
