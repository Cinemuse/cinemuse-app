// Re-exported so the widgets keep one import.
export 'package:cinemuse_app/features/live_tv/application/playlists_notifier.dart';
export 'package:cinemuse_app/features/live_tv/application/guides_notifier.dart';
export 'package:cinemuse_app/features/live_tv/application/channel_prefs_notifiers.dart';
export 'package:cinemuse_app/features/live_tv/application/channel_number_entry_notifier.dart';

import 'dart:async';

import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/application/guides_notifier.dart';
import 'package:cinemuse_app/features/live_tv/application/channel_prefs_notifiers.dart';
import 'package:cinemuse_app/features/live_tv/application/playlists_notifier.dart';
import 'package:cinemuse_app/features/live_tv/application/minute_clock_provider.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_channel_matcher.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_source.dart';
import 'package:cinemuse_app/core/application/settable_notifier.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

// Shared client: timeouts + retries, so a dead server can't hang (REV-117).
final liveTvRepositoryProvider = Provider<LiveTvRepository>((ref) {
  return LiveTvRepository(
    ref.watch(dioProvider),
    epgStorage: ref.watch(epgStorageProvider),
    playlistCopies: ref.watch(playlistCopyStorageProvider),
  );
});

// ---------------------------------------------------------------------------
// Data Providers
// ---------------------------------------------------------------------------

/// The channels of the playlists that are on, and the playlists that failed.
final channelsLoadProvider = FutureProvider<LiveTvLoad<List<Channel>>>((
  ref,
) async {
  final repo = ref.watch(liveTvRepositoryProvider);
  final playlists = ref.watch(playlistsProvider);
  return repo.fetchChannels(
    playlists: playlists.where((p) => p.isEnabled).toList(),
  );
});

/// All playable channels, sorted by LCN.
final channelsProvider = FutureProvider<List<Channel>>(
  (ref) async => (await ref.watch(channelsLoadProvider.future)).data,
);

/// The programmes of the guides that are on, and the guides that failed.
class GuidesLoadNotifier
    extends AsyncNotifier<LiveTvLoad<Map<String, List<EpgProgram>>>> {
  @override
  Future<LiveTvLoad<Map<String, List<EpgProgram>>>> build() {
    final repo = ref.watch(liveTvRepositoryProvider);
    // Empty until the saved list is loaded, so nothing is downloaded twice.
    final guides = ref.watch(guidesProvider);
    return repo.fetchEpg(guides: guides.where((g) => g.isEnabled).toList());
  }

  /// Downloads every guide that is on again, skipping their caches.
  Future<void> refresh() async {
    // A first load still running would overwrite the refreshed guide.
    await future;
    final guides = ref.read(guidesProvider).where((g) => g.isEnabled);
    final load = await ref
        .read(liveTvRepositoryProvider)
        .fetchEpg(guides: guides.toList(), forceRefresh: true);
    if (ref.mounted) state = AsyncData(load);
  }
}

// Not autoDispose: like the channels, the guide is kept for the session.
final guidesLoadProvider =
    AsyncNotifierProvider<
      GuidesLoadNotifier,
      LiveTvLoad<Map<String, List<EpgProgram>>>
    >(GuidesLoadNotifier.new);

/// Full EPG data keyed by channel identifier → programs.
final epgDataProvider = FutureProvider<Map<String, List<EpgProgram>>>(
  (ref) async => (await ref.watch(guidesLoadProvider.future)).data,
);

/// The playlists that failed on their last load, by id.
final playlistFailuresProvider =
    Provider.autoDispose<Map<String, LiveTvSourceFailure>>(
      (ref) => ref.watch(channelsLoadProvider).value?.failures ?? const {},
    );

/// The guides that failed on their last load, by id.
final guideFailuresProvider =
    Provider.autoDispose<Map<String, LiveTvSourceFailure>>(
      (ref) => ref.watch(guidesLoadProvider).value?.failures ?? const {},
    );

/// The names of the playlists and the guides that failed.
typedef FailedLiveTvSources = ({List<String> playlists, List<String> guides});

/// The playlists and guides that failed on their last load; loading until
/// both have loaded.
final failedLiveTvSourcesProvider =
    Provider.autoDispose<AsyncValue<FailedLiveTvSources>>((ref) {
      final channels = ref.watch(channelsLoadProvider);
      final guides = ref.watch(guidesLoadProvider);
      if (channels.isLoading || guides.isLoading) return const AsyncLoading();
      final playlistFailures = ref.watch(playlistFailuresProvider);
      final guideFailures = ref.watch(guideFailuresProvider);
      return AsyncData((
        playlists: [
          for (final p in ref.watch(playlistsProvider))
            if (playlistFailures.containsKey(p.id)) p.name,
        ],
        guides: [
          for (final g in ref.watch(guidesProvider))
            if (guideFailures.containsKey(g.id)) g.name,
        ],
      ));
    });

// ---------------------------------------------------------------------------
// UI State — Tabs & Filters
// ---------------------------------------------------------------------------

/// The three navigation tabs on the channel list panel.
enum LiveTvTab { all, favorites, recents }

/// Which tab is currently active. Like the other values the Live TV screens
/// set below, kept for the session: going back to Live TV finds it unchanged.
final liveTvTabProvider =
    NotifierProvider<SettableNotifier<LiveTvTab>, LiveTvTab>(
      () => SettableNotifier(LiveTvTab.all),
    );

/// The currently selected / playing channel.
final selectedChannelProvider =
    NotifierProvider<SelectedChannelNotifier, Channel?>(
      SelectedChannelNotifier.new,
    );

/// Holds the selected channel and drops it when it leaves the channel list
/// (its playlist was removed or disabled), so no screen keeps showing or
/// playing it (REV-271).
class SelectedChannelNotifier extends Notifier<Channel?> {
  @override
  Channel? build() {
    ref.listen(channelsProvider, (_, next) {
      final channels = next.value;
      final current = state;
      if (channels == null || current == null) return;
      final id = current.uniqueId;
      if (!channels.any((c) => c.uniqueId == id)) state = null;
    });
    return null;
  }

  void select(Channel? channel) => state = channel;
}

/// The active search query for filtering channels.
final channelSearchQueryProvider =
    NotifierProvider<SettableNotifier<String>, String>(
      () => SettableNotifier(''),
    );

/// Whether the slide-in channel list overlay is currently open in full-window or OS fullscreen mode.
final liveTvChannelOverlayProvider =
    NotifierProvider<SettableNotifier<bool>, bool>(
      () => SettableNotifier(false),
    );

/// Saved scroll offset for the Live TV channel list overlay drawer.
final liveTvOverlayScrollOffsetProvider =
    NotifierProvider<SettableNotifier<double?>, double?>(
      () => SettableNotifier(null),
    );

/// Action to focus the live preview player from the channel list via D-Pad Right.
final livePlayerFocusActionProvider =
    NotifierProvider<SettableNotifier<void Function()?>, void Function()?>(
      () => SettableNotifier(null),
    );

// ---------------------------------------------------------------------------
// Derived: channels shown in the list
// ---------------------------------------------------------------------------

/// The channels of the active tab, after the categories and the search.
/// Always in the playlist's LCN order: categories only filter, never group
/// (REV-279).
final filteredChannelsProvider = Provider<AsyncValue<List<Channel>>>((ref) {
  final tab = ref.watch(liveTvTabProvider);
  final query = ref.watch(channelSearchQueryProvider).trim().toLowerCase();
  final filter = ref.watch(channelFilterProvider);
  final channelsAsync = ref.watch(channelsProvider);
  final favoriteIds = ref.watch(favoriteChannelIdsProvider);
  final recentIds = ref.watch(recentChannelIdsProvider);

  return channelsAsync.whenData((allChannels) {
    List<Channel> pool;

    // Resolve by tab
    switch (tab) {
      case LiveTvTab.favorites:
        pool = allChannels
            .where((ch) => favoriteIds.contains(ch.uniqueId))
            .toList();
        break;
      case LiveTvTab.recents:
        pool = _resolveRecents(allChannels, recentIds);
        break;
      case LiveTvTab.all:
        pool = _applyGroupFilter(allChannels, filter);
        break;
    }

    // Apply search
    if (query.isNotEmpty) {
      pool = _applySearch(pool, query);
    }

    return pool;
  });
});

/// The playlists' categories, for the filter sheet: A to Z,
/// with DTT (the national channels) first.
final channelCategoriesProvider =
    Provider.autoDispose<AsyncValue<List<String>>>(
      (ref) => ref.watch(channelsProvider).whenData((channels) {
        final categories = {
          for (final ch in channels) ?ch.group,
        }.where((group) => group.isNotEmpty).toList()..sort();
        if (categories.remove('DTT')) categories.insert(0, 'DTT');
        return categories;
      }),
    );

// ---------------------------------------------------------------------------
// Filter Helpers
// ---------------------------------------------------------------------------

List<Channel> _resolveRecents(
  List<Channel> allChannels,
  List<String> recentIds,
) {
  final channelMap = {for (final ch in allChannels) ch.uniqueId: ch};
  return recentIds
      .map((id) => channelMap[id])
      .where((ch) => ch != null)
      .cast<Channel>()
      .toList();
}

List<Channel> _applyGroupFilter(List<Channel> channels, ChannelFilter filter) {
  if (!filter.isActive) return channels;

  final targets = filter.selectedCategories;
  return channels.where((ch) {
    if (ch.group == null) return false;
    return targets.contains(ch.group);
  }).toList();
}

List<Channel> _applySearch(List<Channel> channels, String query) {
  final asNumber = int.tryParse(query);
  return channels.where((ch) {
    if (asNumber != null && ch.lcn.toString().startsWith(query)) return true;
    return ch.name.toLowerCase().contains(query);
  }).toList();
}

// ---------------------------------------------------------------------------
// EPG Helpers
// ---------------------------------------------------------------------------

/// The program airing now on [channel], re-checked every minute (REV-112).
/// `autoDispose`: `Channel` has no `==`, so each channel list reload makes
/// new entries and the unused ones must be freed.
final currentProgramProvider = Provider.autoDispose
    .family<EpgProgram?, Channel>((ref, channel) {
      final programs = ref.watch(
        epgDataProvider.select((asyncEpg) {
          return asyncEpg.whenOrNull(
                data: (epgData) =>
                    EpgChannelMatcher.findPrograms(channel, epgData),
              ) ??
              const <EpgProgram>[];
        }),
      );
      if (programs.isEmpty) return null;

      final now = ref.watch(minuteClockProvider);
      for (final p in programs) {
        if (now.isAfter(p.startTime) && now.isBefore(p.endTime)) return p;
      }
      return null;
    });
