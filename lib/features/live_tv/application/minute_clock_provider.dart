import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The time now, updated at the start of every minute, so "now playing"
/// moves on when a program ends (REV-112). Guide programs start on whole
/// minutes.
class MinuteClockNotifier extends AutoDisposeNotifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    _scheduleTick();
    return DateTime.now();
  }

  void _scheduleTick() {
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(nextMinute.difference(now), () {
      state = DateTime.now();
      _scheduleTick();
    });
  }
}

final minuteClockProvider =
    NotifierProvider.autoDispose<MinuteClockNotifier, DateTime>(
      MinuteClockNotifier.new,
    );
