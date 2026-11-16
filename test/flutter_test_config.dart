import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

/// Runs around every test file (Flutter picks this file up by its name).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // App log lines would bury the failures in the test output. A test that
  // checks the log sets its own sink.
  AppLogger.sink = (_) {};
  // The last input (key, click, touch) is app-wide: a tap in one test would
  // hide the focus look in the next, and a key press after a tap must bring
  // it back as in the app (REV-314). Plain logic tests have no binding.
  setUp(() {
    if (BindingBase.debugBindingType() == null) return;
    FocusRing.debugResetInput();
    FocusRing.debugWatchKeys();
  });
  await testMain();
}
