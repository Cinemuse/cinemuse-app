import 'dart:async';

import 'package:cinemuse_app/core/utils/app_logger.dart';

/// Waits before each new try, longest last; the last one repeats.
const realtimeRetryDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 10),
  Duration(seconds: 30),
];

/// A live stream that subscribes again after it fails or closes, so a
/// dropped Supabase realtime connection doesn't stop live updates until
/// the app restarts (REV-285).
///
/// [subscribe] opens a fresh source (e.g. `.from(t).stream(...)`) on each
/// try; the wait between tries grows along [delays] and starts over once a
/// try delivers data. An error before the first event is passed on, so a
/// screen waiting for it shows the error instead of spinning; later errors
/// are only logged, and the last value stays. Cancelling the result closes
/// the source and stops the tries.
Stream<T> reconnectingStream<T>(
  Stream<T> Function() subscribe, {
  required String logTag,
  List<Duration> delays = realtimeRetryDelays,
}) {
  late final StreamController<T> controller;
  StreamSubscription<T>? source;
  Timer? retry;
  var hasData = false;
  var failures = 0;
  late final void Function() listenToSource;

  void scheduleRetry(Object? error, StackTrace? stackTrace) {
    if (retry != null) return; // already waiting
    final delay = delays[failures.clamp(0, delays.length - 1)];
    failures++;
    AppLogger.warn(
      logTag,
      'Realtime stream ${error == null ? 'closed' : 'failed'}; '
      'reconnecting in ${delay.inSeconds} s',
      error: error,
      stackTrace: stackTrace,
    );
    final old = source;
    source = null;
    // The old channel is dead; closing it can't fail in a way to report.
    unawaited(old?.cancel());
    retry = Timer(delay, listenToSource);
  }

  listenToSource = () {
    retry = null;
    // One line per channel join, to count them in the log (REV-285 b).
    AppLogger.debug(logTag, 'Realtime subscribe (try ${failures + 1})');
    source = subscribe().listen(
      (event) {
        hasData = true;
        failures = 0;
        controller.add(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!hasData) controller.addError(error, stackTrace);
        scheduleRetry(error, stackTrace);
      },
      onDone: () => scheduleRetry(null, null),
    );
  };

  controller = StreamController<T>(
    onListen: listenToSource,
    onPause: () => source?.pause(),
    onResume: () => source?.resume(),
    onCancel: () {
      retry?.cancel();
      // Live streams never end by themselves: done once nobody listens.
      unawaited(controller.close());
      return source?.cancel();
    },
  );
  return controller.stream;
}
