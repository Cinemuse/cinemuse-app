import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';

/// Coordinates channel switching (zapping) during Live TV video playback.
/// Typed channel numbers: [ChannelNumberEntryNotifier].
class PlayerChannelInputCoordinator {
  void zapNextChannel({
    required WidgetRef ref,
    required Channel? currentChannel,
  }) {
    final channels =
        ref.read(filteredChannelsProvider).value ??
        ref.read(channelsProvider).value ??
        [];
    if (channels.isEmpty) return;

    final current = currentChannel ?? ref.read(selectedChannelProvider);
    final idx = channels.indexWhere((c) => c.uniqueId == current?.uniqueId);
    final nextIdx = idx == -1 ? 0 : (idx + 1) % channels.length;
    ref.read(selectedChannelProvider.notifier).select(channels[nextIdx]);
  }

  void zapPreviousChannel({
    required WidgetRef ref,
    required Channel? currentChannel,
  }) {
    final channels =
        ref.read(filteredChannelsProvider).value ??
        ref.read(channelsProvider).value ??
        [];
    if (channels.isEmpty) return;

    final current = currentChannel ?? ref.read(selectedChannelProvider);
    final idx = channels.indexWhere((c) => c.uniqueId == current?.uniqueId);
    final prevIdx = idx == -1
        ? 0
        : (idx - 1 + channels.length) % channels.length;
    ref.read(selectedChannelProvider.notifier).select(channels[prevIdx]);
  }
}
