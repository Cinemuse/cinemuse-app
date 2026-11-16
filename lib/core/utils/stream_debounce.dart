import 'dart:async';

/// Debounces a stream: only the last event of a burst is passed on.
extension StreamDebounce<T> on Stream<T> {
  /// Emits an event once [duration] has passed without a newer one.
  ///
  /// The source is listened to only while the result is, so cancelling the
  /// result also cancels the source (e.g. closes a Supabase realtime
  /// channel) and the pending timer (REV-182).
  Stream<T> debounce(Duration duration) {
    Timer? timer;
    StreamSubscription<T>? subscription;
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        subscription = listen(
          (event) {
            timer?.cancel();
            timer = Timer(duration, () => controller.add(event));
          },
          onError: controller.addError,
          onDone: () {
            timer?.cancel();
            controller.close();
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        timer?.cancel();
        return subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
