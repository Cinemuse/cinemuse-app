import 'package:cinemuse_app/features/updates/domain/release_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isNewerRelease', () {
    test('a higher x.y.z is newer', () {
      expect(isNewerRelease('v1.3.2', '1.3.1', '20'), isTrue);
      expect(isNewerRelease('v1.4.0', '1.3.9', '20'), isTrue);
      expect(isNewerRelease('v2.0.0', '1.9.9', '20'), isTrue);
    });

    test('a lower or equal x.y.z is not newer', () {
      expect(isNewerRelease('v1.3.1', '1.3.2', '1'), isFalse);
      expect(isNewerRelease('v1.3.2', '1.3.2', '20'), isFalse);
    });

    test('same x.y.z: the build number decides', () {
      expect(isNewerRelease('v1.3.2+21', '1.3.2', '20'), isTrue);
      expect(isNewerRelease('v1.3.2+20', '1.3.2', '20'), isFalse);
    });

    test('a pre-release name on the device no longer throws (CI-05)', () {
      expect(isNewerRelease('v1.3.2', '1.3.2-beta.1', '20'), isTrue);
      expect(isNewerRelease('v1.3.3', '1.3.2-beta', '20'), isTrue);
      expect(isNewerRelease('v1.3.1', '1.3.2-beta', '20'), isFalse);
    });

    test('a pre-release tag is older than the same normal release', () {
      expect(isNewerRelease('v1.3.2-beta+30', '1.3.2', '20'), isFalse);
      expect(isNewerRelease('v1.3.3-beta', '1.3.2', '20'), isTrue);
    });

    test('an unreadable version never offers an update', () {
      expect(isNewerRelease('nightly', '1.3.2', '20'), isFalse);
      expect(isNewerRelease('v1.3.2', 'dev', '20'), isFalse);
    });
  });

  group('isBelowMinimumVersion (REV-306)', () {
    test('an older x.y.z is below the minimum', () {
      expect(isBelowMinimumVersion('1.4.0', '1.3.9', '20'), isTrue);
      expect(isBelowMinimumVersion('2.0.0', '1.9.9', '20'), isTrue);
    });

    test('the same or a newer version is not below', () {
      expect(isBelowMinimumVersion('1.4.0', '1.4.0', '20'), isFalse);
      expect(isBelowMinimumVersion('1.4.0', '1.5.0', '1'), isFalse);
      expect(isBelowMinimumVersion('0.0.0', '1.0.0', '0'), isFalse);
    });

    test('a minimum with a build number: the build decides', () {
      expect(isBelowMinimumVersion('1.4.0+21', '1.4.0', '20'), isTrue);
      expect(isBelowMinimumVersion('1.4.0+21', '1.4.0', '21'), isFalse);
    });

    test('an unreadable version never blocks the app', () {
      expect(isBelowMinimumVersion('', '1.3.2', '20'), isFalse);
      expect(isBelowMinimumVersion('1.4.0', 'dev', '20'), isFalse);
    });
  });
}
