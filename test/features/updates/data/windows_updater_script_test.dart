import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/updates/data/windows_updater_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String build({String appDir = r'C:\Users\me\Apps\Cinemuse'}) {
    return buildWindowsUpdaterScript(
      appPid: 4321,
      sourceDir: r'C:\Temp\cinemuse_update\files',
      appDir: appDir,
      exePath: '$appDir\\cinemuse_app.exe',
      workDir: r'C:\Temp\cinemuse_update',
    );
  }

  test('never asks for admin rights', () {
    final script = build().toLowerCase();

    expect(script, isNot(contains('runas')));
    expect(script, isNot(contains('getadmin')));
    expect(script, isNot(contains('shell.application')));
  });

  test('waits for the app process, copies, restarts and cleans up', () {
    final script = build();

    expect(script, contains('tasklist /fi "PID eq 4321" /nh'));
    expect(script, contains('find /i "cinemuse_app.exe"'));
    expect(
      script,
      contains(
        r'xcopy /s /e /y /i "C:\Temp\cinemuse_update\files\*" '
        r'"C:\Users\me\Apps\Cinemuse" >',
      ),
    );
    expect(
      script,
      contains(r'start "" "C:\Users\me\Apps\Cinemuse\cinemuse_app.exe"'),
    );
    expect(script, contains(r'rd /s /q "C:\Temp\cinemuse_update"'));
    expect(script, contains(r'"%TEMP%\cinemuse_update_log.txt"'));
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
}
