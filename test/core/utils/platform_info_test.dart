import 'package:cinemuse_app/core/utils/platform_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => PlatformInfo.setTvForTesting(null));
  tearDown(() => PlatformInfo.setTvForTesting(null));

  group('PlatformInfo', () {
    test('defaults to false for isTV in test environment', () {
      expect(PlatformInfo.isTV, isFalse);
    });

    test('respects setTvForTesting override', () {
      PlatformInfo.setTvForTesting(true);
      expect(PlatformInfo.isTV, isTrue);

      PlatformInfo.setTvForTesting(false);
      expect(PlatformInfo.isTV, isFalse);
    });
  });
}
