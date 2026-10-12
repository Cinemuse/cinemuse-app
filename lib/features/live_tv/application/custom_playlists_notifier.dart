import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/live_tv/data/local_playlist_storage.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';

/// The user's playlists, saved on this device.
class CustomPlaylistsNotifier extends Notifier<List<LiveTvPlaylist>> {
  static const _key = 'live_tv_custom_playlists';
  static const _tag = 'CustomPlaylistsNotifier';

  /// Saved entries this version can't read (e.g. a newer playlist type).
  /// Saved back unchanged, so one bad entry can't wipe the list (REV-114).
  final _unreadable = <String>[];

  /// Changes wait for it, so the load can't overwrite them (REV-114).
  late Future<void> _loaded;

  @override
  List<LiveTvPlaylist> build() {
    // After build: the load sets `state`, which build can't do.
    _loaded = Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final playlists = <LiveTvPlaylist>[];
    for (final entry in prefs.getStringList(_key) ?? const <String>[]) {
      try {
        playlists.add(LiveTvPlaylist.decode(entry));
      } catch (e, s) {
        // Kept as text and saved back; the other playlists still load.
        // Only the type is logged: the text can hold a playlist URL with
        // credentials.
        AppLogger.warn(
          _tag,
          'Skipping a saved playlist that could not be read',
          error: e.runtimeType,
          stackTrace: s,
        );
        _unreadable.add(entry);
      }
    }
    state = playlists;
  }

  Future<void> addPlaylist(LiveTvPlaylist playlist) async {
    await _loaded;
    await _update([...state, playlist]);
  }

  /// Copies the picked file into the app's playlist folder and adds it.
  /// Throws an [AppFailure] if the copy or the save fails (REV-136).
  Future<void> addLocalPlaylist(File source) async {
    final File copy;
    try {
      copy = await LocalPlaylistStorage.copyPlaylistFile(source);
    } catch (e, s) {
      throw UnknownFailure(
        'Could not copy the playlist file',
        cause: e,
        stackTrace: s,
      );
    }
    await addPlaylist(
      LiveTvPlaylist(
        name: source.uri.pathSegments.last,
        urlOrPath: copy.uri.pathSegments.last, // basename only
        isLocal: true,
        type: PlaylistType.fromPath(source.path),
      ),
    );
  }

  /// Removes the playlist; a local one's copied file is deleted too
  /// (REV-136), only once the list is saved.
  Future<void> removePlaylist(String id) async {
    await _loaded;
    final removed = state.where((p) => p.id == id).firstOrNull;
    await _update(state.where((p) => p.id != id).toList());
    if (removed == null || !removed.isLocal) return;
    try {
      await LocalPlaylistStorage.deletePlaylistFile(removed.urlOrPath);
    } catch (e, s) {
      // The playlist is already gone; a leftover file only takes space.
      AppLogger.warn(
        _tag,
        'Could not delete a removed playlist file',
        error: e.runtimeType,
        stackTrace: s,
      );
    }
  }

  Future<void> togglePlaylistEnabled(String id) async {
    await _loaded;
    await _update([
      for (final p in state)
        p.id == id ? p.copyWith(isEnabled: !p.isEnabled) : p,
    ]);
  }

  /// Shows [next] at once; if the save fails, puts the old list back and
  /// throws, so the UI can say so (REV-222).
  Future<void> _update(List<LiveTvPlaylist> next) async {
    final previous = state;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [
        ...next.map((p) => p.encode()),
        ..._unreadable,
      ]);
    } catch (e, s) {
      state = previous;
      throw UnknownFailure(
        'Could not save the playlists',
        cause: e,
        stackTrace: s,
      );
    }
  }
}

// Not autoDispose: channelsProvider lives for the whole session and reads it.
final customPlaylistsProvider =
    NotifierProvider<CustomPlaylistsNotifier, List<LiveTvPlaylist>>(
      CustomPlaylistsNotifier.new,
    );
