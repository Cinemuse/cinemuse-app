import 'dart:async';

import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ids of the lists and TMDB collections pinned to Home. They are saved in
/// the account's preferences, so they show on every device and never on
/// another account (REV-95). Follows the live profile, so a pin made on
/// another device shows here too.
class PinnedListIdsNotifier extends Notifier<Set<String>> {
  static const _tag = 'PinnedListIdsNotifier';

  /// The `profiles.preferences` key holding the pinned ids.
  static const prefsKey = 'pinnedListIds';

  /// Where older builds kept the pins on the device, for every account.
  static const legacyKey = 'pinned_list_ids';

  final _importStartedFor = <String>{};

  @override
  Set<String> build() {
    final profile = ref.watch(profileStreamProvider).value;
    if (profile == null) return const {};
    final stored = profile.preferences[prefsKey];
    if (stored is List) return stored.whereType<String>().toSet();
    if (_importStartedFor.add(profile.id)) {
      unawaited(_importLegacyPins(profile.id)); // logs its own failure
    }
    return _defaultPins();
  }

  /// An account that never pinned anything has its Watchlist pinned. The
  /// first pin or unpin saves the pins, and the default stops applying.
  Set<String> _defaultPins() {
    // Only the Watchlist's id: an edit to any list must not rebuild the pins.
    final watchlistId = ref.watch(
      userListsProvider.select(
        (lists) => lists.value
            ?.where((list) => list.type == ListType.watchlist)
            .firstOrNull
            ?.id,
      ),
    );
    return {?watchlistId};
  }

  bool isPinned(String listId) => state.contains(listId);

  /// Pins or unpins [listId]. Shows the change at once; if the save fails
  /// the old pins come back and the error is rethrown for the UI.
  Future<void> togglePin(String listId) async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    final previous = state;
    final updated = previous.contains(listId)
        ? ({...previous}..remove(listId))
        : {...previous, listId};
    state = updated;
    try {
      await ref.read(profileRepositoryProvider).patchPreferences(userId, {
        prefsKey: updated.toList(),
      });
    } catch (_) {
      // Only undo this change if no newer change replaced it meanwhile.
      if (identical(state, updated)) state = previous;
      rethrow;
    }
  }

  /// Moves the pins an older build kept on this device to the account, once.
  /// The cached profile may be older than the server's, so the server is
  /// asked first: pins another device already saved are never overwritten.
  Future<void> _importLegacyPins(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getStringList(legacyKey);
      if (local == null) return;
      final profiles = ref.read(profileRepositoryProvider);
      final remote = await profiles.fetchPreferences(userId);
      if (remote[prefsKey] is! List && local.isNotEmpty) {
        await profiles.patchPreferences(userId, {prefsKey: local});
        if (ref.read(userIdProvider) == userId) state = local.toSet();
      }
      await prefs.remove(legacyKey);
    } catch (e, st) {
      // Safe to continue: the device copy stays, so the next start retries.
      AppLogger.warn(
        _tag,
        'Moving the pinned lists to the account failed',
        error: e,
        stackTrace: st,
      );
    }
  }
}

// Lives for the whole session: Home reads it on every visit.
final pinnedListIdsProvider =
    NotifierProvider<PinnedListIdsNotifier, Set<String>>(
      PinnedListIdsNotifier.new,
    );
