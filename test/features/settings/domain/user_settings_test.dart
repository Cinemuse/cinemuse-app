import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

// REV-80: the anime torrent feed is on only with a debrid service that has a key.
void main() {
  test('the torrent feed is off without a debrid service', () {
    const settings = UserSettings(enableAnimeTorrents: true);

    expect(settings.isAnimeTorrentsActive, false);
  });

  test('the torrent feed is off when the debrid service has no key', () {
    const settings = UserSettings(
      enableAnimeTorrents: true,
      enableRealDebrid: true,
      realDebridKey: '  ',
    );

    expect(settings.isAnimeTorrentsActive, false);
  });

  test('TorBox alone is enough for the torrent feed', () {
    const settings = UserSettings(
      enableAnimeTorrents: true,
      enableTorBox: true,
      torBoxKey: 'key',
    );

    expect(settings.isAnimeTorrentsActive, true);
  });

  test('the user can still switch the torrent feed off', () {
    const settings = UserSettings(
      enableAnimeTorrents: false,
      enableRealDebrid: true,
      realDebridKey: 'key',
    );

    expect(settings.isAnimeTorrentsActive, false);
  });
}
