import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart'; // For defaultTargetPlatform
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<ConnectivityResult>((ref) async* {
  // 1. WSL/Linux Workaround: connectivity_plus on Linux depends on NetworkManager via DBus.
  // Many minimal Linux environments (like WSL) don't run NetworkManager, causing a crash.
  if (defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS) {
    yield ConnectivityResult.wifi;
    return;
  }

  final connectivity = Connectivity();
  
  // 2. Initial Assumption: Assume connected (wifi) to avoid an immediate "Offline Screen" flicker.
  // This follows the "Fail-Open" UX principle: assume it works until proven otherwise.
  ConnectivityResult lastResult = ConnectivityResult.wifi; 

  // 2. Windows-Specific Stabilization: Only apply the delay on Windows to handle 
  // its specific NetworkManager quirks during startup/hot-reload.
  if (defaultTargetPlatform == TargetPlatform.windows) {
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  // 3. Initial Check
  try {
    final initial = await connectivity.checkConnectivity();
    if (initial.isNotEmpty) {
      lastResult = initial.first;
      yield lastResult;
    }
  } catch (e) {
    // Fail-open: if the platform check crashes or is unavailable, 
    // we yield our assumed state (wifi) and let actual API calls handle failures.
    yield lastResult;
  }

  // 4. Continuous Listening
  try {
    await for (final List<ConnectivityResult> results in connectivity.onConnectivityChanged) {
      if (results.isNotEmpty) {
        lastResult = results.first;
        yield lastResult;
      }
    }
  } catch (e) {
    // Stop gracefully without forcing an offline state on platform errors
    yield lastResult;
  }
});

extension ConnectivityResultSelectionX on ConnectivityResult {
  bool get isConnected => this != ConnectivityResult.none;
  bool get isOffline => this == ConnectivityResult.none;
}
