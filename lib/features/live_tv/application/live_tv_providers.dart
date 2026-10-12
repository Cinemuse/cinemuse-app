// Re-exported so the widgets keep one import.
export 'package:cinemuse_app/features/live_tv/application/custom_playlists_notifier.dart';
export 'package:cinemuse_app/features/live_tv/application/channel_prefs_notifiers.dart';

import 'dart:async';

import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/application/custom_epg_url_notifier.dart';
import 'package:cinemuse_app/features/live_tv/application/channel_prefs_notifiers.dart';
import 'package:cinemuse_app/features/live_tv/application/custom_playlists_notifier.dart';
import 'package:cinemuse_app/features/live_tv/application/minute_clock_provider.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_channel_matcher.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/data/local_playlist_storage.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

// Shared client: timeouts + retries, so a dead server can't hang (REV-117).
final liveTvRepositoryProvider = Provider<LiveTvRepository>((ref) {
  return LiveTvRepository(
    ref.watch(dioProvider),
    defaultEpgUrl: ref.watch(defaultEpgUrlProvider),
  );
});

// ---------------------------------------------------------------------------
// Data Providers
// ---------------------------------------------------------------------------

/// All playable channels, sorted by LCN.
final channelsProvider = FutureProvider<List<Channel>>((ref) async {
  final repo = ref.watch(liveTvRepositoryProvider);
  final customPlaylists = ref.watch(customPlaylistsProvider);

  // Filter out disabled playlists before loading channels.
  final enabledPlaylists = customPlaylists.where((p) => p.isEnabled).toList();

  // Resolve local playlist filenames (or legacy absolute paths) to the full
  // platform-specific path so the repository can read them as File objects.
  final resolvedPlaylists = await Future.wait(
    enabledPlaylists.map((playlist) async {
      if (!playlist.isLocal) return playlist;
      final absolutePath = await LocalPlaylistStorage.resolveToAbsolutePath(
        playlist.urlOrPath,
      );
      return playlist.copyWith(urlOrPath: absolutePath);
    }),
  );

  return repo.fetchChannels(customPlaylists: resolvedPlaylists);
});

/// Full EPG data keyed by channel identifier → programs.
final epgDataProvider = FutureProvider<Map<String, List<EpgProgram>>>((
  ref,
) async {
  final repo = ref.watch(liveTvRepositoryProvider);
  // Wait for the saved URL: starting with the default guide meant two
  // downloads and two parses on every start (REV-115).
  final customUrl = await ref.watch(customEpgUrlProvider.future);
  return repo.fetchEpg(url: customUrl);
});

// ---------------------------------------------------------------------------
// UI State — Tabs & Filters
// ---------------------------------------------------------------------------

/// The three navigation tabs on the channel list panel.
enum LiveTvTab { all, favorites, recents }

/// Which tab is currently active.
final liveTvTabProvider = StateProvider<LiveTvTab>((ref) => LiveTvTab.all);

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
      final channels = next.valueOrNull;
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
final channelSearchQueryProvider = StateProvider<String>((ref) => '');

/// Whether the slide-in channel list overlay is currently open in full-window or OS fullscreen mode.
final liveTvChannelOverlayProvider = StateProvider<bool>((ref) => false);

/// Saved scroll offset for the Live TV channel list overlay drawer.
final liveTvOverlayScrollOffsetProvider = StateProvider<double?>((ref) => null);

/// Action to focus the live preview player from the channel list via D-Pad Right.
final livePlayerFocusActionProvider = StateProvider<void Function()?>(
  (ref) => null,
);

// ---------------------------------------------------------------------------
// Derived: Sectioned channels for the main list
// ---------------------------------------------------------------------------

/// A section header + its channels, used for sticky headers in the flat list.
class ChannelSection {
  final String title;
  final List<Channel> channels;
  const ChannelSection({required this.title, required this.channels});
}

/// Channels grouped into sections for sticky-header display.
/// When a filter is active, returns a single section (no headers needed).
final sectionedChannelsProvider = Provider<AsyncValue<List<ChannelSection>>>((
  ref,
) {
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

    // Build sections
    if (tab != LiveTvTab.all || !filter.isActive) {
      // Single flat list — no category section headers, preserving natural LCN order
      return [ChannelSection(title: '', channels: pool)];
    }

    // Group by category when a specific category filter is active
    return _buildSections(pool);
  });
});

/// Flat filtered channels (convenience for scroll-to-selected logic).
final filteredChannelsProvider = Provider<AsyncValue<List<Channel>>>((ref) {
  final sectioned = ref.watch(sectionedChannelsProvider);
  return sectioned.whenData((sections) {
    return sections.expand((s) => s.channels).toList();
  });
});

// ---------------------------------------------------------------------------
// Section Building Helpers
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

List<ChannelSection> _buildSections(List<Channel> channels) {
  final grouped = <String, List<Channel>>{};
  for (final ch in channels) {
    final key = ch.group?.isNotEmpty == true ? ch.group! : 'Other';
    (grouped[key] ??= []).add(ch);
  }

  // Sort groups, but keep DTT first if present
  final keys = grouped.keys.toList()..sort();
  if (keys.contains('DTT')) {
    keys.remove('DTT');
    keys.insert(0, 'DTT');
  }

  return keys
      .map((k) => ChannelSection(title: k, channels: grouped[k]!))
      .toList();
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

// ---------------------------------------------------------------------------
// Number Input State
// ---------------------------------------------------------------------------

/// Buffer for remote-style number input (e.g., "10" for LCN 10).
final numberInputBufferProvider = StateProvider<String>((ref) => '');
