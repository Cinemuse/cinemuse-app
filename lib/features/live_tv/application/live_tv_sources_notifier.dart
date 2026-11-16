import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/live_tv/data/local_playlist_storage.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_source.dart';

/// The Cinemuse entry first, then the user's own, saved on this device. The
/// playlists and the guides are both kept this way.
abstract class LiveTvSourcesNotifier<T extends LiveTvSource>
    extends Notifier<List<T>> {
  /// Where the user's own entries are saved.
  String get savedKey;

  /// Where the Cinemuse entry's on/off is saved.
  String get builtInEnabledKey;

  String get logTag;

  /// The Cinemuse entry's link; watched, so a new one reloads the list.
  String watchBuiltInUrl();

  T builtIn(String url, {required bool isEnabled});
  T decode(String saved);
  T withEnabled(T source, bool isEnabled);

  /// A new entry for a file copied in as [storedName].
  T fromLocalFile(String fileName, String storedName);

  /// Called once a removed entry is saved as gone.
  Future<void> onRemoved(T source) async {}

  /// Saved entries this version can't read (e.g. a newer playlist type).
  /// Saved back unchanged, so one bad entry can't wipe the list (REV-114).
  final _unreadable = <String>[];

  /// Changes wait for it, so the load can't overwrite them (REV-114).
  late Future<void> _loaded;

  @override
  List<T> build() {
    final builtInUrl = watchBuiltInUrl();
    // After build: the load sets `state`, which build can't do.
    _loaded = Future.microtask(() => _load(builtInUrl));
    return const [];
  }

  Future<void> _load(String builtInUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final sources = <T>[
      // First, so its channel numbers (Rai 1 = 1…) and its programmes are
      // the ones kept.
      builtIn(builtInUrl, isEnabled: prefs.getBool(builtInEnabledKey) ?? true),
    ];
    for (final entry in prefs.getStringList(savedKey) ?? const <String>[]) {
      try {
        sources.add(decode(entry));
      } catch (e, s) {
        // Kept as text and saved back; the others still load. Only the type
        // is logged: the text can hold a URL with credentials.
        AppLogger.warn(
          logTag,
          'Skipping a saved entry that could not be read',
          error: e.runtimeType,
          stackTrace: s,
        );
        _unreadable.add(entry);
      }
    }
    state = sources;
  }

  Future<void> add(T source) async {
    await _loaded;
    await _update([...state, source]);
  }

  /// Copies the picked file into the app's playlist folder and adds it.
  /// Throws an [AppFailure] if the copy or the save fails (REV-136).
  Future<void> addLocalFile(File source) async {
    final File copy;
    try {
      copy = await LocalPlaylistStorage.copyPlaylistFile(source);
    } catch (e, s) {
      throw UnknownFailure(
        'Could not copy the picked file',
        cause: e,
        stackTrace: s,
      );
    }
    await add(
      fromLocalFile(
        source.uri.pathSegments.last,
        copy.uri.pathSegments.last, // basename only
      ),
    );
  }

  /// Removes the entry at once; the Cinemuse entry stays. If [undone] ends
  /// true, the entry goes back where it was. Otherwise a local one's copied
  /// file (REV-136) and a downloaded one's saved copy are deleted, only then.
  Future<void> remove(String id, {Future<bool>? undone}) async {
    await _loaded;
    final index = state.indexWhere((s) => s.id == id);
    if (index < 0 || state[index].isBuiltIn) return;
    final removed = state[index];
    await _update([...state]..removeAt(index));
    if (undone != null && await undone) {
      // Other entries may have been removed meanwhile.
      await _update([...state]..insert(min(index, state.length), removed));
      return;
    }
    await onRemoved(removed);
    if (!removed.isLocal) return;
    try {
      await LocalPlaylistStorage.deletePlaylistFile(removed.urlOrPath);
    } catch (e, s) {
      // The entry is already gone; a leftover file only takes space.
      AppLogger.warn(
        logTag,
        'Could not delete a removed file',
        error: e.runtimeType,
        stackTrace: s,
      );
    }
  }

  Future<void> toggleEnabled(String id) async {
    await _loaded;
    await _update([
      for (final s in state) s.id == id ? withEnabled(s, !s.isEnabled) : s,
    ]);
  }

  /// Shows [next] at once; if the save fails, puts the old list back and
  /// throws, so the UI can say so (REV-222).
  Future<void> _update(List<T> next) async {
    final previous = state;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(savedKey, [
        for (final s in next)
          if (!s.isBuiltIn) s.encode(),
        ..._unreadable,
      ]);
      final cinemuse = next.where((s) => s.isBuiltIn).firstOrNull;
      if (cinemuse != null) {
        await prefs.setBool(builtInEnabledKey, cinemuse.isEnabled);
      }
    } catch (e, s) {
      state = previous;
      throw UnknownFailure('Could not save the list', cause: e, stackTrace: s);
    }
  }
}
