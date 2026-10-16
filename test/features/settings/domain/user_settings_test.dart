import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

// REV-80: AnimeTosho is on only with a debrid service that has a key.
void main() {
  test('AnimeTosho is off without a debrid service', () {
    const settings = UserSettings(enableAnimeTosho: true);

    expect(settings.isAnimeToshoActive, false);
  });

  test('AnimeTosho is off when the debrid service has no key', () {
    const settings = UserSettings(
      enableAnimeTosho: true,
      enableRealDebrid: true,
      realDebridKey: '  ',
    );

    expect(settings.isAnimeToshoActive, false);
  });

  test('TorBox alone is enough for AnimeTosho', () {
    const settings = UserSettings(
      enableAnimeTosho: true,
      enableTorBox: true,
      torBoxKey: 'key',
    );

    expect(settings.isAnimeToshoActive, true);
  });

  test('the user can still switch AnimeTosho off', () {
    const settings = UserSettings(
      enableAnimeTosho: false,
      enableRealDebrid: true,
      realDebridKey: 'key',
    );

    expect(settings.isAnimeToshoActive, false);
  });
}
