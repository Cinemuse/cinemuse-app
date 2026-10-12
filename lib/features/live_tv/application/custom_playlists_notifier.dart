import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
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

  Future<void> removePlaylist(String id) async {
    await _loaded;
    await _update(state.where((p) => p.id != id).toList());
  }

  Future<void> togglePlaylistEnabled(String id) async {
    await _loaded;
    await _update([
      for (final p in state)
        p.id == id ? p.copyWith(isEnabled: !p.isEnabled) : p,
    ]);
  }

  Future<void> _update(List<LiveTvPlaylist> next) async {
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [
      ...next.map((p) => p.encode()),
      ..._unreadable,
    ]);
  }
}

// Not autoDispose: channelsProvider lives for the whole session and reads it.
final customPlaylistsProvider =
    NotifierProvider<CustomPlaylistsNotifier, List<LiveTvPlaylist>>(
      CustomPlaylistsNotifier.new,
    );
