import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/live_tv/data/live_tv_repository.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

final liveTvRepositoryProvider = Provider<LiveTvRepository>((ref) {
  return LiveTvRepository(Dio());
});

// ---------------------------------------------------------------------------
// Data Providers
// ---------------------------------------------------------------------------

/// All playable channels, sorted by LCN.
final channelsProvider = FutureProvider<List<Channel>>((ref) async {
  final repo = ref.watch(liveTvRepositoryProvider);
  final region = ref.watch(settingsProvider.select((s) => s.liveTvRegion));
  return repo.fetchChannels(region: region);
});

/// Full EPG data keyed by source → channel id → programs.
final epgDataProvider =
    FutureProvider<Map<String, Map<String, List<EpgProgram>>>>((ref) async {
  final repo = ref.watch(liveTvRepositoryProvider);
  return repo.fetchEpg();
});

// ---------------------------------------------------------------------------
// UI State
// ---------------------------------------------------------------------------

enum LiveTvGroupMode { category, provider }
enum LiveTvPanelFocus { groups, channels }

/// The currently selected / playing channel.
final selectedChannelProvider = StateProvider<Channel?>((ref) => null);

/// The active search query for filtering channels.
final channelSearchQueryProvider = StateProvider<String>((ref) => '');

/// Current group mode (Category vs Provider)
final liveTvGroupModeProvider = StateProvider<LiveTvGroupMode>((ref) => LiveTvGroupMode.category);

/// Which part of the panel is currently focused/expanded
final liveTvPanelFocusProvider = StateProvider<LiveTvPanelFocus>((ref) => LiveTvPanelFocus.groups);

/// Tracks which sub-providers are expanded in the channel list (accordion state)
/// Key: Provider/Category name, Value: Set of expanded sub-provider names.
final expandedSubProvidersProvider = StateProvider<Map<String, Set<String>>>((ref) => {});

/// The currently selected group name (Category or Provider).
final liveTvSelectedGroupProvider = StateProvider<String>((ref) {
  final mode = ref.watch(liveTvGroupModeProvider);
  return mode == LiveTvGroupMode.category ? 'DTT' : '';
});

// Legacy support for category chip UI if still used elsewhere
final liveTvCategoryProvider = Provider<String>((ref) => ref.watch(liveTvSelectedGroupProvider));

/// All available groups (Categories or Providers) extracted from the current channel list.
final groupsProvider = Provider<AsyncValue<List<String>>>((ref) {
  final channelsAsync = ref.watch(channelsProvider);
  final mode = ref.watch(liveTvGroupModeProvider);
  
  return channelsAsync.whenData((channels) {
    final groups = channels
        .map((ch) => mode == LiveTvGroupMode.category ? ch.group : ch.provider)
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

/// Channels filtered by the active search query AND selected group (category or provider).
final filteredChannelsProvider = Provider<AsyncValue<List<Channel>>>((ref) {
  final channelsAsync = ref.watch(channelsProvider);
  final query = ref.watch(channelSearchQueryProvider).trim().toLowerCase();
  final selectedGroup = ref.watch(liveTvSelectedGroupProvider);
  final mode = ref.watch(liveTvGroupModeProvider);

  return channelsAsync.whenData((channels) {
    if (query.isNotEmpty) {
      // Global search across all categories/providers
      final asNumber = int.tryParse(query);
      return channels.where((ch) {
        if (asNumber != null && ch.lcn.toString().startsWith(query)) return true;
        return ch.name.toLowerCase().contains(query);
      }).toList();
    }
    
    // Filter by group (Category or Provider) only if NOT searching
    if (selectedGroup.isNotEmpty) {
      return channels.where((ch) {
        final chGroup = mode == LiveTvGroupMode.category ? ch.group : ch.provider;
        return chGroup == selectedGroup;
      }).toList();
    }
    
    return channels;
  });
});

// ---------------------------------------------------------------------------
// EPG Helpers
// ---------------------------------------------------------------------------

/// Current program for a given channel.
final currentProgramProvider =
    Provider.family<EpgProgram?, Channel>((ref, channel) {
  final epgAsync = ref.watch(epgDataProvider);
  return epgAsync.whenOrNull(data: (epgData) {
    final repo = ref.read(liveTvRepositoryProvider);
    return repo.getProgramsForChannel(channel, epgData).current;
  });
});

/// Next program for a given channel.
final nextProgramProvider =
    Provider.family<EpgProgram?, Channel>((ref, channel) {
  final epgAsync = ref.watch(epgDataProvider);
  return epgAsync.whenOrNull(data: (epgData) {
    final repo = ref.read(liveTvRepositoryProvider);
    return repo.getProgramsForChannel(channel, epgData).next;
  });
});

// ---------------------------------------------------------------------------
// Number Input State
// ---------------------------------------------------------------------------

/// Buffer for remote-style number input (e.g., "10" for LCN 10).
final numberInputBufferProvider = StateProvider<String>((ref) => '');

