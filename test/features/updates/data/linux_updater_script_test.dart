import 'dart:io';

import 'package:cinemuse_app/features/updates/data/linux_updater_script.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('never asks for admin rights', () {
    for (final word in ['sudo', 'pkexec', 'su ', 'apt', 'dpkg']) {
      expect(linuxUpdaterScript, isNot(contains(word)), reason: word);
    }
  });

  test('has no Windows line endings, which sh can\'t run', () {
    expect(linuxUpdaterScript, isNot(contains('\r')));
  });

  group(
    'run for real',
    () {
      late Directory root;
      late String source;
      late String appDir;
      late String exe;
      late String work;
      late String log;
      late String restarted;

      setUp(() {
        // A space, a quote and a dollar: no folder name may break the script.
        root = Directory.systemTemp.createTempSync("updater test 'it' \$HOME ");
        work = p.join(root.path, 'work');
        source = p.join(work, 'files');
        appDir = p.join(root.path, 'app');
        exe = p.join(appDir, 'cinemuse_app');
        log = p.join(root.path, 'log.txt');
        restarted = p.join(root.path, 'restarted.txt');

        File(p.join(appDir, 'lib', 'old.so'))
          ..createSync(recursive: true)
          ..writeAsStringSync('old');
        File(exe).writeAsStringSync('old app');

        // The new app only says it was started, next to its own folder.
        // Neither copy has the "can be run" mark, as after unpacking.
        File(p.join(source, 'cinemuse_app'))
          ..createSync(recursive: true)
          ..writeAsStringSync(
            '#!/bin/sh\n'
            'echo started > "\$(dirname "\$0")/../restarted.txt"\n',
          );
        File(p.join(source, 'lib', 'old.so'))
          ..createSync(recursive: true)
          ..writeAsStringSync('new');
      });

      tearDown(() => root.deleteSync(recursive: true));

      Future<int> runUpdater(int appPid, {String? appFolder}) async {
        final script = File(p.join(root.path, 'updater.sh'))
          ..writeAsStringSync(linuxUpdaterScript);
        final result = await Process.run('sh', [
          script.path,
          '$appPid',
          source,
          appFolder ?? appDir,
          exe,
          work,
          log,
        ]);
        return result.exitCode;
      }

      test('waits for the app, swaps the files, restarts, cleans up', () async {
        final app = await Process.start('sleep', ['2']);
        final startedAt = DateTime.now();

        expect(await runUpdater(app.pid), 0);

        expect(
          DateTime.now().difference(startedAt).inMilliseconds,
          greaterThan(1000),
          reason: 'it must not copy while the app is still running',
        );
        expect(File(restarted).readAsStringSync().trim(), 'started');
        expect(File(p.join(appDir, 'lib', 'old.so')).readAsStringSync(), 'new');
        expect(Directory(work).existsSync(), isFalse);
      });

      test(
        'a failed copy keeps the update files and does not restart',
        () async {
          final missingFolder = p.join(root.path, 'missing', 'app');

          expect(await runUpdater(999999, appFolder: missingFolder), isNot(0));

          expect(File(restarted).existsSync(), isFalse);
          expect(Directory(work).existsSync(), isTrue);
          expect(File(log).readAsStringSync(), isNotEmpty);
        },
      );
    },
    skip: Platform.isLinux ? false : 'Needs Linux: runs in WSL and in CI',
  );
}
