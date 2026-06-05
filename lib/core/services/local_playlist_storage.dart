import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Handles platform-aware storage for local playlist files.
///
/// - **Windows**: `AppData\Roaming\<app>\playlists\`
/// - **Android / other**: `<appSupportDir>/playlists/`
///
/// Playlists are stored by **basename only** in SharedPreferences, so paths
/// remain valid across OTA updates and app reinstalls that preserve app data.
/// Legacy entries that contain an absolute path are returned as-is (best-effort).
class LocalPlaylistStorage {
  LocalPlaylistStorage._();

  static const _subfolderPath = ['data', 'playlists'];

  /// Returns (and creates if necessary) the playlists directory.
  static Future<Directory> getPlaylistsDir() async {
    final baseDir = await getApplicationSupportDirectory();
    final dir = Directory(p.joinAll([baseDir.path, ..._subfolderPath]));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies [source] into the playlists directory and returns the destination file.
  static Future<File> copyPlaylistFile(File source) async {
    final dir = await getPlaylistsDir();
    final destPath = p.join(dir.path, p.basename(source.path));
    return source.copy(destPath);
  }

  /// Resolves a stored [filenameOrLegacyPath] to a full, absolute file path.
  ///
  /// - If [filenameOrLegacyPath] is already absolute (legacy entry), it is
  ///   returned unchanged so old playlists keep working until removed.
  /// - Otherwise it is treated as a plain filename and joined with the
  ///   current playlists directory.
  static Future<String> resolveToAbsolutePath(
    String filenameOrLegacyPath,
  ) async {
    if (p.isAbsolute(filenameOrLegacyPath)) return filenameOrLegacyPath;
    final dir = await getPlaylistsDir();
    return p.join(dir.path, filenameOrLegacyPath);
  }
}
