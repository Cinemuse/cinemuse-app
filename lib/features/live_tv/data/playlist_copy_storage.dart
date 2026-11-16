import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';

/// The last good download of each playlist, used when a later download
/// fails, so a failed start or Refresh still shows and plays its channels.
///
/// Kept in the app's own folder, not the temporary one the guides use: the
/// system can empty that, and the copy matters most when the app starts
/// offline. A file holds the playlist's URL on its first line, then the text.
class PlaylistCopyStorage {
  static const _tag = 'PlaylistCopyStorage';

  /// Folder that holds the copies. Tests pass a temporary folder.
  final Future<Directory> Function() _directory;

  PlaylistCopyStorage({Future<Directory> Function()? directory})
    : _directory = directory ?? _appDirectory;

  static Future<Directory> _appDirectory() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'data', 'playlist_copies'));
  }

  Future<File> _file(String playlistId) async =>
      File(p.join((await _directory()).path, '$playlistId.txt'));

  /// The saved text of the playlist, if it was saved for [url].
  Future<String?> load(String playlistId, {required String url}) async {
    try {
      final file = await _file(playlistId);
      if (!file.existsSync()) return null;
      final content = await file.readAsString();
      final firstLineEnd = content.indexOf('\n');
      if (firstLineEnd < 0 || content.substring(0, firstLineEnd) != url) {
        return null;
      }
      return content.substring(firstLineEnd + 1);
    } catch (e, s) {
      // Without the copy the playlist only shows as failed.
      AppLogger.warn(
        _tag,
        'Could not read a playlist copy',
        error: e.runtimeType,
        stackTrace: s,
      );
      return null;
    }
  }

  Future<void> save(String playlistId, String url, String text) async {
    try {
      final file = await _file(playlistId);
      await file.parent.create(recursive: true);
      await file.writeAsString('$url\n$text', flush: true);
    } catch (e, s) {
      // The next failed download finds an older copy, or none.
      AppLogger.warn(
        _tag,
        'Could not save a playlist copy',
        error: e.runtimeType,
        stackTrace: s,
      );
    }
  }

  /// Deletes a removed playlist's copy, if there is one.
  Future<void> delete(String playlistId) async {
    try {
      final file = await _file(playlistId);
      if (file.existsSync()) await file.delete();
    } catch (e, s) {
      // A leftover copy only takes space.
      AppLogger.warn(
        _tag,
        'Could not delete a playlist copy',
        error: e.runtimeType,
        stackTrace: s,
      );
    }
  }
}
