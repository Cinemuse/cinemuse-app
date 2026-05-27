import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/core/services/local_playlist_storage.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

final liveTvRepositoryProvider = Provider<LiveTvRepository>((ref) {
  return LiveTvRepository(Dio());
});

// ---------------------------------------------------------------------------
// Custom Playlists
// ---------------------------------------------------------------------------

class CustomPlaylistsNotifier extends StateNotifier<List<LiveTvPlaylist>> {
  CustomPlaylistsNotifier() : super([]) {
    _load();
  }

  static const _key = 'live_tv_custom_playlists';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    try {
      state = jsonList.map((str) => LiveTvPlaylist.decode(str)).toList();
    } catch (_) {
      state = [];
    }
  }

  Future<void> addPlaylist(LiveTvPlaylist playlist) async {
    final next = [...state, playlist];
    state = next;
    _save(next);
  }

  Future<void> removePlaylist(String id) async {
    final next = state.where((p) => p.id != id).toList();
    state = next;
    _save(next);
  }

  Future<void> togglePlaylistEnabled(String id) async {
    final next = state.map((p) {
      if (p.id != id) return p;
      return p.copyWith(isEnabled: !p.isEnabled);
    }).toList();
    state = next;
    _save(next);
  }

  Future<void> _save(List<LiveTvPlaylist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = playlists.map((p) => p.encode()).toList();
    await prefs.setStringList(_key, jsonList);
  }
}

final customPlaylistsProvider =
    StateNotifierProvider<CustomPlaylistsNotifier, List<LiveTvPlaylist>>((ref) {
  return CustomPlaylistsNotifier();
});

// ---------------------------------------------------------------------------
// Data Providers
// ---------------------------------------------------------------------------

/// All playable channels, sorted by LCN.
final channelsProvider = FutureProvider<List<Channel>>((ref) async {
  final repo = ref.watch(liveTvRepositoryProvider);
  final region = ref.watch(settingsProvider.select((s) => s.liveTvRegion));
  final customPlaylists = ref.watch(customPlaylistsProvider);

  // Filter out disabled playlists before loading channels.
  final enabledPlaylists = customPlaylists.where((p) => p.isEnabled).toList();

  // Resolve local playlist filenames (or legacy absolute paths) to the full
  // platform-specific path so the repository can read them as File objects.
  final resolvedPlaylists = await Future.wait(
    enabledPlaylists.map((playlist) async {
      if (!playlist.isLocal) return playlist;
      final absolutePath =
          await LocalPlaylistStorage.resolveToAbsolutePath(playlist.urlOrPath);
      return playlist.copyWith(urlOrPath: absolutePath);
    }),
  );

  return repo.fetchChannels(region: region, customPlaylists: resolvedPlaylists);
});

/// Full EPG data keyed by source → channel id → programs.
final epgDataProvider =
    FutureProvider<Map<String, Map<String, List<EpgProgram>>>>((ref) async {
  final repo = ref.watch(liveTvRepositoryProvider);
  return repo.fetchEpg();
});

// ---------------------------------------------------------------------------
// UI State — Tabs & Filters
// ---------------------------------------------------------------------------

/// The three navigation tabs on the channel list panel.
enum LiveTvTab { all, favorites, recents }

/// Which tab is currently active.
final liveTvTabProvider = StateProvider<LiveTvTab>((ref) => LiveTvTab.all);

/// Grouping mode used inside the filter sheet.
enum LiveTvGroupMode { category, provider }

/// Filter state applied from the filter sheet.
class ChannelFilter {
  final LiveTvGroupMode groupMode;
  final String? selectedGroup;
  final String? selectedSubProvider;

  const ChannelFilter({
    this.groupMode = LiveTvGroupMode.category,
    this.selectedGroup,
    this.selectedSubProvider,
  });

  bool get isActive => selectedGroup != null;

  ChannelFilter copyWith({
    LiveTvGroupMode? groupMode,
    String? Function()? selectedGroup,
    String? Function()? selectedSubProvider,
  }) {
    return ChannelFilter(
      groupMode: groupMode ?? this.groupMode,
      selectedGroup:
          selectedGroup != null ? selectedGroup() : this.selectedGroup,
      selectedSubProvider: selectedSubProvider != null
          ? selectedSubProvider()
          : this.selectedSubProvider,
    );
  }
}

/// The current filter state (set via the filter sheet).
final channelFilterProvider =
    StateProvider<ChannelFilter>((ref) => const ChannelFilter());

/// The currently selected / playing channel.
final selectedChannelProvider = StateProvider<Channel?>((ref) => null);

/// The active search query for filtering channels.
final channelSearchQueryProvider = StateProvider<String>((ref) => '');

// ---------------------------------------------------------------------------
// Favorites
// ---------------------------------------------------------------------------

class FavoriteChannelsNotifier extends StateNotifier<Set<String>> {
  FavoriteChannelsNotifier() : super({}) {
    _load();
  }

  static const _key = 'live_tv_favorites';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    state = ids.toSet();
  }

  Future<void> toggle(String channelId) async {
    final next = Set<String>.from(state);
    if (next.contains(channelId)) {
      next.remove(channelId);
    } else {
      next.add(channelId);
    }
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }

  bool isFavorite(String channelId) => state.contains(channelId);
}

final favoriteChannelIdsProvider =
    StateNotifierProvider<FavoriteChannelsNotifier, Set<String>>((ref) {
  return FavoriteChannelsNotifier();
});

// ---------------------------------------------------------------------------
// Recently Watched
// ---------------------------------------------------------------------------

class RecentChannelsNotifier extends StateNotifier<List<String>> {
  RecentChannelsNotifier() : super([]) {
    _load();
  }

  static const _key = 'live_tv_recents';
  static const _maxRecents = 15;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key) ?? [];
  }

  Future<void> push(String channelId) async {
    final next = [channelId, ...state.where((id) => id != channelId)];
    state = next.take(_maxRecents).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state);
  }
}

final recentChannelIdsProvider =
    StateNotifierProvider<RecentChannelsNotifier, List<String>>((ref) {
  return RecentChannelsNotifier();
});

// ---------------------------------------------------------------------------
// Derived: Groups & Sub-Providers (for filter sheet)
// ---------------------------------------------------------------------------

/// All available groups (Categories or Providers) for the filter sheet.
final groupsProvider = Provider<AsyncValue<List<String>>>((ref) {
  final channelsAsync = ref.watch(channelsProvider);
  final mode =
      ref.watch(channelFilterProvider.select((f) => f.groupMode));

  return channelsAsync.whenData((channels) {
    final groups = channels
        .map((ch) =>
            mode == LiveTvGroupMode.category ? ch.group : ch.provider)
        .where((g) => g != null && g.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    groups.sort();

    if (mode == LiveTvGroupMode.category && groups.contains('DTT')) {
      groups.remove('DTT');
      groups.insert(0, 'DTT');
    }
    return groups;
  });
});

/// Sub-providers available for the currently selected group.
final subProvidersForGroupProvider = Provider<List<String>>((ref) {
  final channelsAsync = ref.watch(channelsProvider);
  final filter = ref.watch(channelFilterProvider);

  return channelsAsync.whenOrNull(data: (channels) {
        if (filter.selectedGroup == null) return <String>[];

        final inGroup = channels.where((ch) {
          final chGroup = filter.groupMode == LiveTvGroupMode.category
              ? ch.group
              : ch.provider;
          return chGroup == filter.selectedGroup;
        });

        final subs = inGroup
            .map((ch) => ch.subProvider)
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();
        subs.sort();
        return subs;
      }) ??
      [];
});

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
final sectionedChannelsProvider =
    Provider<AsyncValue<List<ChannelSection>>>((ref) {
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
    if (tab != LiveTvTab.all || filter.isActive || query.isNotEmpty) {
      // Single flat list — no section headers
      return [ChannelSection(title: '', channels: pool)];
    }

    // Group by category for "All" tab with no filter
    return _buildSections(pool);
  });
});

/// Flat filtered channels (convenience for scroll-to-selected logic).
final filteredChannelsProvider =
    Provider<AsyncValue<List<Channel>>>((ref) {
  final sectioned = ref.watch(sectionedChannelsProvider);
  return sectioned.whenData((sections) {
    return sections.expand((s) => s.channels).toList();
  });
});

// ---------------------------------------------------------------------------
// Section Building Helpers
// ---------------------------------------------------------------------------

List<Channel> _resolveRecents(
    List<Channel> allChannels, List<String> recentIds) {
  final channelMap = {for (final ch in allChannels) ch.uniqueId: ch};
  return recentIds
      .map((id) => channelMap[id])
      .where((ch) => ch != null)
      .cast<Channel>()
      .toList();
}

List<Channel> _applyGroupFilter(
    List<Channel> channels, ChannelFilter filter) {
  if (!filter.isActive) return channels;

  var result = channels.where((ch) {
    final chGroup = filter.groupMode == LiveTvGroupMode.category
        ? ch.group
        : ch.provider;
    return chGroup == filter.selectedGroup;
  });

  if (filter.selectedSubProvider != null) {
    result = result.where((ch) => ch.subProvider == filter.selectedSubProvider);
  }

  return result.toList();
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

/// Current program for a given channel.
final currentProgramProvider =
    Provider.family<EpgProgram?, Channel>((ref, channel) {
  final programs = ref.watch(epgDataProvider.select((asyncEpg) {
    return asyncEpg.whenOrNull(data: (epgData) {
      if (channel.epgSource == null || channel.epgId == null) return <EpgProgram>[];
      return epgData[channel.epgSource]?[channel.epgId] ?? <EpgProgram>[];
    }) ?? <EpgProgram>[];
  }));

  if (programs.isEmpty) return null;
  final now = DateTime.now();
  
  for (int i = 0; i < programs.length; i++) {
    final p = programs[i];
    if (now.isAfter(p.startTime) && now.isBefore(p.endTime)) {
      return p;
    }
  }
  return null;
});

/// Next program for a given channel.
final nextProgramProvider =
    Provider.family<EpgProgram?, Channel>((ref, channel) {
  final programs = ref.watch(epgDataProvider.select((asyncEpg) {
    return asyncEpg.whenOrNull(data: (epgData) {
      if (channel.epgSource == null || channel.epgId == null) return <EpgProgram>[];
      return epgData[channel.epgSource]?[channel.epgId] ?? <EpgProgram>[];
    }) ?? <EpgProgram>[];
  }));

  if (programs.isEmpty) return null;
  final now = DateTime.now();
  
  for (int i = 0; i < programs.length; i++) {
    final p = programs[i];
    if (now.isAfter(p.startTime) && now.isBefore(p.endTime)) {
      if (i + 1 < programs.length) return programs[i + 1];
    }
  }
  return null;
});

// ---------------------------------------------------------------------------
// Number Input State
// ---------------------------------------------------------------------------

/// Buffer for remote-style number input (e.g., "10" for LCN 10).
final numberInputBufferProvider = StateProvider<String>((ref) => '');
