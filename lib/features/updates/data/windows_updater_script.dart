import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:path/path.dart' as p;

/// Builds the `.bat` that swaps the app files after the app has closed.
///
/// It runs as the current user, never as admin (SEC-03): the app lives in a
/// folder the user can write to, and elevating a script in a user-writable
/// folder would let any program running as the user gain admin rights.
///
/// The app starts it detached (no console window), so it uses `ping` to wait
/// and no `pause`: `timeout` and `pause` need a console.
///
/// - [appPid]: process to wait for (the running app).
/// - [sourceDir]: the extracted update.
/// - [appDir]: the folder the app runs from, overwritten with [sourceDir].
/// - [exePath]: restarted when the copy worked.
/// - [workDir]: deleted at the end, together with the script inside it.
///
/// Throws a [ValidationFailure] if a path contains `"` or a line break, which
/// would break out of the quoted batch strings.
String buildWindowsUpdaterScript({
  required int appPid,
  required String sourceDir,
  required String appDir,
  required String exePath,
  required String workDir,
}) {
  final exe = _batchText(p.windows.basename(exePath));
  final source = _batchText(sourceDir);
  final app = _batchText(appDir);
  final work = _batchText(workDir);
  return '''
@echo off
setlocal
echo Waiting for Cinemuse to close...
:wait_loop
tasklist /fi "PID eq $appPid" /nh | find /i "$exe" > nul
if %errorlevel% == 0 (
    ping -n 2 127.0.0.1 > nul
    goto wait_loop
)

echo Copying the new version...
xcopy /s /e /y /i "$source\\*" "$app" > "%TEMP%\\cinemuse_update_log.txt" 2>&1
if %errorlevel% neq 0 (
    echo The update could not copy the files. Details: %TEMP%\\cinemuse_update_log.txt
    exit /b 1
)

echo Restarting Cinemuse...
start "" "${_batchText(exePath)}"
(goto) 2>nul & rd /s /q "$work"
''';
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
