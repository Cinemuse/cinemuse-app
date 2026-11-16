import 'dart:io';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:path/path.dart' as p;

/// Puts Cinemuse in the user's own applications menu, which needs no password.
///
/// On Linux the app is a folder the user unpacked, so nothing else adds it to
/// the menu. It runs at every start: moving the folder would otherwise leave
/// the entry pointing at nothing. A failure only costs the menu entry, so it
/// is logged and the app carries on.
Future<void> addLinuxMenuEntry({
  required String exePath,
  required Map<String, String> environment,
}) async {
  try {
    final dataHome = linuxDataHome(environment);
    if (dataHome == null) {
      AppLogger.warn('LinuxMenuEntry', 'No home folder: not adding the entry');
      return;
    }
    final file = File(p.join(dataHome, 'applications', 'cinemuse.desktop'));
    final entry = buildLinuxMenuEntry(exePath);
    if (file.existsSync() && await file.readAsString() == entry) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(entry);
  } on FileSystemException catch (e) {
    AppLogger.warn('LinuxMenuEntry', 'Entry not written', error: e);
  } on ValidationFailure catch (e) {
    AppLogger.warn('LinuxMenuEntry', 'Entry not written', error: e);
  }
}

/// Where the user's own menu entries live: `XDG_DATA_HOME` when it is set, as
/// the Linux standard asks, else `~/.local/share`.
String? linuxDataHome(Map<String, String> environment) {
  final dataHome = environment['XDG_DATA_HOME'];
  if (dataHome != null && dataHome.isNotEmpty) return dataHome;
  final home = environment['HOME'];
  if (home == null || home.isEmpty) return null;
  return p.posix.join(home, '.local', 'share');
}

/// The menu entry for the app at [exePath]; its logo is inside the app's own
/// folder. Throws a [ValidationFailure] for a path with a line break, which
/// would start a new line in the entry.
String buildLinuxMenuEntry(String exePath) {
  if (exePath.contains('\n') || exePath.contains('\r')) {
    throw ValidationFailure('Path not allowed in the menu entry: $exePath');
  }
  final icon = p.posix.join(
    p.posix.dirname(exePath),
    'data',
    'flutter_assets',
    'assets',
    'logo.png',
  );
  return '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=Cinemuse\n'
      'Comment=Modern media browser and player\n'
      'Exec=${_execValue(exePath)}\n'
      'Icon=${icon.replaceAll(r'\', r'\\')}\n'
      'Terminal=false\n'
      'Categories=AudioVideo;Player;Video;\n'
      'StartupWMClass=com.example.cinemuse_app\n'
      'Keywords=movies;tv;shows;streaming;anime;player;\n';
}

/// [path] quoted the way the menu entry standard asks: first the characters
/// that are special inside its quotes, then every backslash doubled, because
/// the whole line is read once more as plain text. `%` starts a placeholder.
String _execValue(String path) {
  final quoted = path.replaceAllMapped(
    RegExp(r'["`$\\]'),
    (match) => '\\${match[0]}',
  );
  return '"${quoted.replaceAll(r'\', r'\\').replaceAll('%', '%%')}"';
}
