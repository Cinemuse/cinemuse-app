import 'dart:io';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/updates/data/windows_updater_script.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  String build({String appDir = r'C:\Users\me\Apps\Cinemuse'}) {
    return buildWindowsUpdaterScript(
      appPid: 4321,
      sourceDir: r'C:\Temp\cinemuse_update\files',
      appDir: appDir,
      exePath: '$appDir\\cinemuse_app.exe',
      workDir: r'C:\Temp\cinemuse_update',
      logPath: r'C:\Temp\cinemuse_update_log.txt',
    );
  }

  test('never asks for admin rights', () {
    final script = build().toLowerCase();

    expect(script, isNot(contains('runas')));
    expect(script, isNot(contains('getadmin')));
    expect(script, isNot(contains('shell.application')));
  });

  test('has Windows line endings only', () {
    final script = build();

    expect(script, contains('\r\n'));
    expect(script.replaceAll('\r\n', ''), isNot(contains('\n')));
  });

  test('waits for the app process, copies, restarts and cleans up', () {
    final script = build();

    expect(script, contains('tasklist /fi "PID eq 4321" /nh'));
    expect(script, contains('find /i "cinemuse_app.exe"'));
    expect(
      script,
      contains(
        r'xcopy /s /e /y /i "C:\Temp\cinemuse_update\files\*" '
        r'"C:\Users\me\Apps\Cinemuse" > "C:\Temp\cinemuse_update_log.txt"',
      ),
    );
    expect(
      script,
      contains(r'start "" "C:\Users\me\Apps\Cinemuse\cinemuse_app.exe"'),
    );
    expect(script, contains(r'rd /s /q "C:\Temp\cinemuse_update"'));
  });

  test('escapes % so a folder name is not read as a variable', () {
    final script = build(appDir: r'C:\Users\me\100% Films & Co');

    expect(script, contains(r'"C:\Users\me\100%% Films & Co" >'));
    expect(script, isNot(contains('100% ')));
  });

  test('refuses a path that would break out of the quotes', () {
    expect(
      () => build(appDir: 'C:\\evil" & del C:\\x & "'),
      throwsA(isA<ValidationFailure>()),
    );
    expect(
      () => build(appDir: 'C:\\evil\r\ndel C:\\x'),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test(
    'run for real: waits for the app, copies, cleans up, and ends',
    () async {
      // A space, a % and a &: no folder name may break the script.
      final root = Directory.systemTemp.createTempSync('updater test 100% & ');
      addTearDown(() => root.deleteSync(recursive: true));
      final work = p.join(root.path, 'work');
      final source = p.join(work, 'files');
      final appDir = p.join(root.path, 'app');
      final log = p.join(root.path, 'log.txt');
      // Harmless programs under the app's name: ping plays the running app
      // for about two seconds; the new copy is rundll32, which, started with
      // nothing to do, quits at once without a window.
      final system = p.join(Platform.environment['SystemRoot']!, 'System32');
      final ping = p.join(system, 'PING.EXE');
      File(p.join(source, 'data', 'app.so'))
        ..createSync(recursive: true)
        ..writeAsStringSync('new');
      File(
        p.join(system, 'rundll32.exe'),
      ).copySync(p.join(source, 'cinemuse_app.exe'));
      File(p.join(appDir, 'data', 'app.so'))
        ..createSync(recursive: true)
        ..writeAsStringSync('old');
      final running = Directory(p.join(root.path, 'running'))..createSync();
      final fakeApp = File(
        ping,
      ).copySync(p.join(running.path, 'cinemuse_app.exe'));

      final app = await Process.start(fakeApp.path, ['-n', '3', '127.0.0.1']);
      final startedAt = DateTime.now();
      final script = File(p.join(work, 'updater.bat'))
        ..writeAsStringSync(
          buildWindowsUpdaterScript(
            appPid: app.pid,
            sourceDir: source,
            appDir: appDir,
            exePath: p.join(appDir, 'cinemuse_app.exe'),
            workDir: work,
            logPath: log,
          ),
        );
      await startWindowsUpdater(script.path);

      while (Directory(work).existsSync()) {
        expect(
          DateTime.now().difference(startedAt).inSeconds,
          lessThan(30),
          reason: 'the script got stuck',
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await app.exitCode;

      expect(
        DateTime.now().difference(startedAt).inMilliseconds,
        greaterThan(1000),
        reason: 'it must not copy while the app is still running',
      );
      expect(File(p.join(appDir, 'data', 'app.so')).readAsStringSync(), 'new');
      expect(File(p.join(appDir, 'cinemuse_app.exe')).existsSync(), isTrue);
      expect(File(log).readAsStringSync(), isNotEmpty);
    },
    skip: Platform.isWindows ? false : 'Needs Windows',
  );
}
