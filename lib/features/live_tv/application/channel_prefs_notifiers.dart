import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';

/// A choice saved on this device as a list of strings.
abstract class _SavedListNotifier<T> extends Notifier<T> {
  String get _key;
  T get _empty;
  T _fromList(List<String> saved);
  List<String> _toList(T value);

  /// Changes wait for it, so the load can't overwrite them (REV-122).
  late Future<void> _loaded;

  @override
  T build() {
    // After build: the load sets `state`, which build can't do.
    _loaded = Future.microtask(_load);
    return _empty;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    if (saved != null) state = _fromList(saved);
  }

  /// Shows the change at once and saves it once; if the save fails, puts
  /// the old value back and throws, so the UI can say so (REV-122).
  Future<void> _update(T Function(T current) change) async {
    await _loaded;
    final previous = state;
    final next = change(previous);
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _toList(next);
      if (list.isEmpty) {
        await prefs.remove(_key);
      } else {
        await prefs.setStringList(_key, list);
      }
    } catch (e, s) {
      // Only if no newer change came in meanwhile.
      if (identical(state, next)) state = previous;
      throw UnknownFailure('Could not save $_key', cause: e, stackTrace: s);
    }
  }
}

// ---------------------------------------------------------------------------
// Category filter
// ---------------------------------------------------------------------------

/// Filter state applied from the filter sheet.
class ChannelFilter {
  final Set<String> selectedCategories;

  const ChannelFilter({this.selectedCategories = const {}});

  bool get isActive => selectedCategories.isNotEmpty;
}

class ChannelFilterNotifier extends _SavedListNotifier<ChannelFilter> {
  @override
  String get _key => 'live_tv_selected_categories';
  @override
  ChannelFilter get _empty => const ChannelFilter();
  @override
  ChannelFilter _fromList(List<String> saved) =>
      ChannelFilter(selectedCategories: saved.toSet());
  @override
  List<String> _toList(ChannelFilter value) =>
      value.selectedCategories.toList();

  Future<void> toggleCategory(String category) => _update((current) {
    final next = Set<String>.from(current.selectedCategories);
    if (!next.remove(category)) next.add(category);
    return ChannelFilter(selectedCategories: next);
  });

  Future<void> selectAll() => clear();

  Future<void> clear() => _update((_) => const ChannelFilter());
}

/// The current filter state (set via the filter sheet).
final channelFilterProvider =
    NotifierProvider<ChannelFilterNotifier, ChannelFilter>(
      ChannelFilterNotifier.new,
    );

// ---------------------------------------------------------------------------
// Favorites
// ---------------------------------------------------------------------------

class FavoriteChannelsNotifier extends _SavedListNotifier<Set<String>> {
  @override
  String get _key => 'live_tv_favorites';
  @override
  Set<String> get _empty => const {};
  @override
  Set<String> _fromList(List<String> saved) => saved.toSet();
  @override
  List<String> _toList(Set<String> value) => value.toList();

  Future<void> toggle(String channelId) => _update((current) {
    final next = Set<String>.from(current);
    if (!next.remove(channelId)) next.add(channelId);
    return next;
  });

  bool isFavorite(String channelId) => state.contains(channelId);
}

final favoriteChannelIdsProvider =
    NotifierProvider<FavoriteChannelsNotifier, Set<String>>(
      FavoriteChannelsNotifier.new,
    );

// ---------------------------------------------------------------------------
// Recently Watched
// ---------------------------------------------------------------------------

class RecentChannelsNotifier extends _SavedListNotifier<List<String>> {
  static const _maxRecents = 15;
  static const _tag = 'RecentChannelsNotifier';

  @override
  String get _key => 'live_tv_recents';
  @override
  List<String> get _empty => const [];
  @override
  List<String> _fromList(List<String> saved) => saved;
  @override
  List<String> _toList(List<String> value) => value;

  /// Recents are saved while a channel starts playing, so a failed save is
  /// only logged: no error popup over the player.
  Future<void> push(String channelId) async {
    try {
      await _update(
        (current) => [
          channelId,
          ...current.where((id) => id != channelId),
        ].take(_maxRecents).toList(),
      );
    } catch (e, s) {
      AppLogger.warn(
        _tag,
        'Could not save the recent channels',
        error: e,
        stackTrace: s,
      );
    }
  }
}

final recentChannelIdsProvider =
    NotifierProvider<RecentChannelsNotifier, List<String>>(
      RecentChannelsNotifier.new,
    );
