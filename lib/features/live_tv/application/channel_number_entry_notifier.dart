import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';

/// The digits typed so far on a remote or keyboard ("5", "0" for channel 50).
///
/// Not autoDispose: the channel list reads it only from its key handler, and
/// the digits must last until the wait ends.
final channelNumberEntryProvider =
    NotifierProvider<ChannelNumberEntryNotifier, String>(
      ChannelNumberEntryNotifier.new,
    );

/// Typing a channel number, the same on the channel list and in the player:
/// the channel is found [waitAfterLastDigit] after the last digit, or at once
/// with [confirm].
class ChannelNumberEntryNotifier extends Notifier<String> {
  static const maxDigits = 4;
  static const waitAfterLastDigit = Duration(milliseconds: 1500);

  Timer? _timer;
  void Function(Channel channel)? _onFound;

  @override
  String build() {
    ref.onDispose(() => _timer?.cancel());
    return '';
  }

  /// Adds [digit]. [onFound] gets the channel with the typed number; the
  /// channel list opens it, the player switches to it.
  void type(String digit, {required void Function(Channel channel) onFound}) {
    if (state.length >= maxDigits) return;
    state = state + digit;
    _onFound = onFound;
    _timer?.cancel();
    _timer = Timer(waitAfterLastDigit, confirm);
  }

  void confirm() {
    final number = int.tryParse(state);
    final onFound = _onFound;
    clear();
    if (number == null || onFound == null) return;
    final channels = ref.read(channelsProvider).value ?? const [];
    final match = channels.where((c) => c.lcn == number).firstOrNull;
    if (match != null) onFound(match);
  }

  void clear() {
    _timer?.cancel();
    _onFound = null;
    state = '';
  }
}

/// The digit a key types: the number row and the number keypad both count.
String? channelDigitFor(LogicalKeyboardKey key) {
  final index = _digitKeys.indexOf(key);
  if (index != -1) return '$index';
  final numpadIndex = _numpadKeys.indexOf(key);
  return numpadIndex == -1 ? null : '$numpadIndex';
}

const _digitKeys = [
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

const _numpadKeys = [
  LogicalKeyboardKey.numpad0,
  LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2,
  LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4,
  LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6,
  LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8,
  LogicalKeyboardKey.numpad9,
];
