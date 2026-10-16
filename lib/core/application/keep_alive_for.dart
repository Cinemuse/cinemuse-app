import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps an autoDispose provider for a while after its last listener left.
extension KeepAliveFor on Ref<Object?> {
  /// Keeps this provider's state for [duration] after nobody listens, so a
  /// screen opened again soon shows it at once instead of loading again.
  void keepAliveFor(Duration duration) {
    final link = keepAlive();
    Timer? timer;
    onCancel(() => timer = Timer(duration, link.close));
    onResume(() => timer?.cancel());
    onDispose(() => timer?.cancel());
  }
}
