import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lives for the whole session, like the repositories that fire it.
final watchLogEventsProvider = Provider<WatchLogEvents>((ref) {
  final events = WatchLogEvents();
  ref.onDispose(events.dispose);
  return events;
});

/// Tells listeners that this device added or removed watch logs, so the
/// timeline and the stats reload. Playback progress never fires it, so they
/// don't reload on every progress save (PERF-02).
class WatchLogEvents {
  final _written = StreamController<void>.broadcast();

  /// One event per write that added or removed watch logs.
  Stream<void> get written => _written.stream;

  /// Call after a write that added or removed watch logs has succeeded.
  void notifyWritten() {
    if (!_written.isClosed) _written.add(null);
  }

  void dispose() => _written.close();
}
