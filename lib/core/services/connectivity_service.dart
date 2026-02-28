import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<ConnectivityResult>((ref) async* {
  final connectivity = Connectivity();
  
  // Get initial state
  final initial = await connectivity.checkConnectivity();
  yield initial.first; // connectivity_plus 6.0 returns a List<ConnectivityResult>

  // Listen for changes
  await for (final List<ConnectivityResult> results in connectivity.onConnectivityChanged) {
    if (results.isNotEmpty) {
      yield results.first;
    }
  }
});

extension ConnectivityResultSelectionX on ConnectivityResult {
  bool get isConnected => this != ConnectivityResult.none;
  bool get isOffline => this == ConnectivityResult.none;
}
