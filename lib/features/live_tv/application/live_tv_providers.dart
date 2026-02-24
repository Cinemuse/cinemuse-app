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
  final settings = ref.watch(settingsProvider);
  return repo.fetchChannels(region: settings.liveTvRegion);
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

/// Channels filtered by the active search query (name or LCN).
final filteredChannelsProvider = Provider<AsyncValue<List<Channel>>>((ref) {
  final channelsAsync = ref.watch(channelsProvider);
  final query = ref.watch(channelSearchQueryProvider).trim().toLowerCase();

  return channelsAsync.whenData((channels) {
    if (query.isEmpty) return channels;
    final asNumber = int.tryParse(query);
    return channels.where((ch) {
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

