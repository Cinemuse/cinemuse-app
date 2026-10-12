import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';

/// Coordinates channel switching (zapping) and direct numeric LCN input
/// during Live TV video playback.
class PlayerChannelInputCoordinator {
  Timer? _numberInputTimer;

  void dispose() {
    _numberInputTimer?.cancel();
    _numberInputTimer = null;
  }

  void zapNextChannel({
    required WidgetRef ref,
    required Channel? currentChannel,
    VoidCallback? onCustomNextChannel,
  }) {
    if (onCustomNextChannel != null) {
      onCustomNextChannel();
      return;
    }
    final channels =
        ref.read(filteredChannelsProvider).valueOrNull ??
        ref.read(channelsProvider).valueOrNull ??
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
    VoidCallback? onCustomPreviousChannel,
  }) {
    if (onCustomPreviousChannel != null) {
      onCustomPreviousChannel();
      return;
    }
    final channels =
        ref.read(filteredChannelsProvider).valueOrNull ??
        ref.read(channelsProvider).valueOrNull ??
        [];
    if (channels.isEmpty) return;

    final current = currentChannel ?? ref.read(selectedChannelProvider);
    final idx = channels.indexWhere((c) => c.uniqueId == current?.uniqueId);
    final prevIdx = idx == -1
        ? 0
        : (idx - 1 + channels.length) % channels.length;
    ref.read(selectedChannelProvider.notifier).select(channels[prevIdx]);
  }

  void handleNumberInput({
    required WidgetRef ref,
    required String digit,
    ValueChanged<String>? onCustomNumberInput,
    VoidCallback? onCustomConfirmNumber,
  }) {
    if (onCustomNumberInput != null) {
      onCustomNumberInput(digit);
      return;
    }
    final buffer = ref.read(numberInputBufferProvider);
    ref.read(numberInputBufferProvider.notifier).state = buffer + digit;
    _numberInputTimer?.cancel();
    _numberInputTimer = Timer(const Duration(seconds: 2), () {
      confirmNumberInput(
        ref: ref,
        onCustomConfirmNumber: onCustomConfirmNumber,
      );
    });
  }

  void confirmNumberInput({
    required WidgetRef ref,
    VoidCallback? onCustomConfirmNumber,
  }) {
    if (onCustomConfirmNumber != null) {
      onCustomConfirmNumber();
      return;
    }
    _numberInputTimer?.cancel();
    final buffer = ref.read(numberInputBufferProvider);
    if (buffer.isEmpty) return;

    final lcn = int.tryParse(buffer);
    if (lcn != null) {
      final channels = ref.read(channelsProvider).valueOrNull ?? [];
      final match = channels.where((c) => c.lcn == lcn).firstOrNull;
      if (match != null) {
        ref.read(selectedChannelProvider.notifier).select(match);
      }
    }
    ref.read(numberInputBufferProvider.notifier).state = '';
  }
}
