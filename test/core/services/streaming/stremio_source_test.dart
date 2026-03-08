import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/services/streaming/sources/stremio_source.dart';

void main() {
  group('StremioSource URL Cleaning', () {
    test('cleanBaseUrl should strip /manifest.json and everything after it', () {
      final testCases = {
        "https://addon.com/manifest.json": "https://addon.com",
        "https://addon.com/manifest.json/": "https://addon.com",
        "https://addon.com/manifest.json/stream/movie/tt123.json": "https://addon.com",
        "https://addon.com/": "https://addon.com",
        "https://addon.com": "https://addon.com",
        "https://mediafusion.elfhosted.com/D-hzHx.../manifest.json/stream/series/tt...": "https://mediafusion.elfhosted.com/D-hzHx...",
      };

      testCases.forEach((input, expected) {
        expect(StremioSource.cleanBaseUrl(input), equals(expected));
      });
    });
  });
}
