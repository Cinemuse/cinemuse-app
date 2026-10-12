import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Handles platform-aware storage for local playlist files.
///
/// Files live in `<appSupportDir>/data/playlists/` on every platform
/// (on Windows `<appSupportDir>` is `AppData\Roaming\<company>\<app>`).
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
  ///
  /// If a playlist with the same file name is already there, the copy gets a
  /// ` (1)`, ` (2)`, … suffix, so importing a second `playlist.m3u` never
  /// overwrites the first one.
  static Future<File> copyPlaylistFile(File source) async {
    return copyIntoDir(source, await getPlaylistsDir());
  }

  /// Copies [source] into [dir] under a file name that isn't taken yet.
  @visibleForTesting
  static Future<File> copyIntoDir(File source, Directory dir) {
    final name = p.basenameWithoutExtension(source.path);
    final extension = p.extension(source.path);
    var destPath = p.join(dir.path, '$name$extension');
    for (var i = 1; File(destPath).existsSync(); i++) {
      destPath = p.join(dir.path, '$name ($i)$extension');
    }
    return source.copy(destPath);
  }

  /// Deletes the copy of a removed playlist. A legacy absolute path is left
  /// alone: it may be the user's own file, not a copy.
  static Future<void> deletePlaylistFile(String filenameOrLegacyPath) async {
    if (p.isAbsolute(filenameOrLegacyPath)) return;
    await deleteFromDir(filenameOrLegacyPath, await getPlaylistsDir());
  }

  /// Deletes [fileName] from [dir], if it is there.
  @visibleForTesting
  static Future<void> deleteFromDir(String fileName, Directory dir) async {
    final file = File(p.join(dir.path, p.basename(fileName)));
    if (file.existsSync()) await file.delete();
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
