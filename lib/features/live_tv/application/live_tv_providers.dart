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

/// The currently selected / playing channel.
final selectedChannelProvider = StateProvider<Channel?>((ref) => null);

/// The active search query for filtering channels.
final channelSearchQueryProvider = StateProvider<String>((ref) => '');

/// The currently selected category.
final liveTvCategoryProvider = StateProvider<String>((ref) => 'Generale');

/// All available categories extracted from the current channel list.
final categoriesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final channelsAsync = ref.watch(channelsProvider);
  return channelsAsync.whenData((channels) {
    final groups = channels
        .map((ch) => ch.group)
        .where((g) => g != null)
        .cast<String>()
        .toSet()
        .toList();
    groups.sort();
    
    // Always put 'Generale' or 'All' first if exists, otherwise keep sorted
    if (groups.contains('Generale')) {
      groups.remove('Generale');
      groups.insert(0, 'Generale');
    }
    return groups;
  });
});

/// Channels filtered by the active search query (name or LCN) AND category.
final filteredChannelsProvider = Provider<AsyncValue<List<Channel>>>((ref) {
  final channelsAsync = ref.watch(channelsProvider);
  final query = ref.watch(channelSearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(liveTvCategoryProvider);

  return channelsAsync.whenData((channels) {
    var filtered = channels;
    
    // 1. Filter by category
    if (category.isNotEmpty) {
      filtered = filtered.where((ch) => ch.group == category).toList();
    }
    
    // 2. Filter by search query
    if (query.isEmpty) return filtered;
    
    final asNumber = int.tryParse(query);
    return filtered.where((ch) {
      if (asNumber != null && ch.lcn.toString().startsWith(query)) return true;
      return ch.name.toLowerCase().contains(query);
    }).toList();
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

