import 'dart:io';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:path/path.dart' as p;

/// Builds the `.bat` that swaps the app files after the app has closed.
///
/// It runs as the current user, never as admin (SEC-03): the app lives in a
/// folder the user can write to, and elevating a script in a user-writable
/// folder would let any program running as the user gain admin rights.
///
/// It runs in a console nobody sees (see [startWindowsUpdater]), so it shows
/// no messages: a failed copy is written to [logPath]. It waits with `ping`,
/// not `timeout` or `pause`, which wait for a key press.
///
/// - [appPid]: process to wait for (the running app).
/// - [sourceDir]: the extracted update.
/// - [appDir]: the folder the app runs from, overwritten with [sourceDir].
/// - [exePath]: restarted when the copy worked.
/// - [workDir]: deleted at the end, together with the script inside it.
/// - [logPath]: what the copy printed, and why it failed.
///
/// Throws a [ValidationFailure] if a path contains `"` or a line break, which
/// would break out of the quoted batch strings.
String buildWindowsUpdaterScript({
  required int appPid,
  required String sourceDir,
  required String appDir,
  required String exePath,
  required String workDir,
  required String logPath,
}) {
  final exe = _batchText(p.windows.basename(exePath));
  final source = _batchText(sourceDir);
  final app = _batchText(appDir);
  final work = _batchText(workDir);
  final log = _batchText(logPath);
  // Windows line endings: with bare line feeds `cmd` can miss a `goto` label.
  return '''
@echo off
setlocal
:wait_loop
tasklist /fi "PID eq $appPid" /nh | find /i "$exe" > nul
if %errorlevel% == 0 (
    ping -n 2 127.0.0.1 > nul
    goto wait_loop
)

xcopy /s /e /y /i "$source\\*" "$app" > "$log" 2>&1
if %errorlevel% neq 0 (
    echo The update could not copy the files. >> "$log"
    exit /b 1
)

start "" "${_batchText(exePath)}"
(goto) 2>nul & rd /s /q "$work"
'''
      .replaceAll('\n', '\r\n');
}

/// Starts the script at [scriptPath] and leaves it running after the app
/// exits.
///
/// Not detached: a detached script has no console, so Windows opens a window
/// for each command in it, and `tasklist | find` never ends.
/// Started this way it gets a console of its own with no window.
Future<void> startWindowsUpdater(String scriptPath) async {
  await Process.start(scriptPath, []);
}

/// [value] made safe inside a double-quoted batch string.
String _batchText(String value) {
  if (value.contains('"') || value.contains('\n') || value.contains('\r')) {
    throw ValidationFailure('Path not allowed in the updater script: $value');
  }
  // Inside quotes `&`, `|`, `<`, `>` and `^` are plain text; only `%` still
  // expands variables, so it is doubled.
  return value.replaceAll('/', '\\').replaceAll('%', '%%');
}
