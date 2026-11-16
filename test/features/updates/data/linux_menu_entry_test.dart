import 'dart:io';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/updates/data/linux_menu_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('buildLinuxMenuEntry', () {
    test('points at the app and at the logo inside its folder', () {
      final entry = buildLinuxMenuEntry('/home/me/Cinemuse/cinemuse_app');

      expect(entry, startsWith('[Desktop Entry]\n'));
      expect(entry, contains('Exec="/home/me/Cinemuse/cinemuse_app"\n'));
      expect(
        entry,
        contains(
          'Icon=/home/me/Cinemuse/data/flutter_assets/assets/logo.png\n',
        ),
      );
    });

    test('quotes the special characters of a folder name', () {
      final entry = buildLinuxMenuEntry(r'/home/me/My "100%" $Films/app');

      expect(entry, contains(r'Exec="/home/me/My \\"100%%\\" \\$Films/app"'));
    });

    test('refuses a path with a line break', () {
      expect(
        () => buildLinuxMenuEntry('/home/me/evil\nExec=rm/app'),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('linuxDataHome', () {
    test('XDG_DATA_HOME first, as the Linux standard asks', () {
      expect(
        linuxDataHome({'XDG_DATA_HOME': '/data', 'HOME': '/home/me'}),
        '/data',
      );
    });

    test('else the home folder', () {
      expect(
        linuxDataHome({'XDG_DATA_HOME': '', 'HOME': '/home/me'}),
        '/home/me/.local/share',
      );
    });

    test('no home folder: nowhere to write', () {
      expect(linuxDataHome({}), isNull);
    });
  });

  group('addLinuxMenuEntry', () {
    late Directory dataHome;
    late File entryFile;

    setUp(() {
      dataHome = Directory.systemTemp.createTempSync('menu_entry_test');
      entryFile = File(
        p.join(dataHome.path, 'applications', 'cinemuse.desktop'),
      );
    });

    tearDown(() => dataHome.deleteSync(recursive: true));

    Future<void> add(String exePath) => addLinuxMenuEntry(
      exePath: exePath,
      environment: {'XDG_DATA_HOME': dataHome.path},
    );

    test('creates the entry and its folder', () async {
      await add('/home/me/Cinemuse/cinemuse_app');

      expect(
        entryFile.readAsStringSync(),
        buildLinuxMenuEntry('/home/me/Cinemuse/cinemuse_app'),
      );
    });

    test('the app folder moved: the entry follows it', () async {
      await add('/home/me/Old/cinemuse_app');
      await add('/home/me/New/cinemuse_app');

      expect(entryFile.readAsStringSync(), contains('/home/me/New/'));
    });

    test('a failed write only costs the entry, the app carries on', () async {
      // A file where the folder should be, so the entry can't be written.
      File(p.join(dataHome.path, 'applications')).createSync();

      await expectLater(add('/home/me/Cinemuse/cinemuse_app'), completes);
      expect(entryFile.existsSync(), isFalse);
    });

    test('a path with a line break is skipped, the app carries on', () async {
      await expectLater(add('/home/me/evil\n/cinemuse_app'), completes);
      expect(entryFile.existsSync(), isFalse);
    });
  });
}
