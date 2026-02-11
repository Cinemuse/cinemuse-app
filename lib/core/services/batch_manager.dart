import 'dart:async';

/// BatchManager
/// 
/// A singleton utility to debounce high-frequency write operations.
/// Used to delay Firestore writes for actions like reordering lists or items,
/// reducing read/write costs by only committing the final state.
/// 
/// Mirrors the web app's batchManager.js
class BatchManager {
  static final BatchManager _instance = BatchManager._internal();
  factory BatchManager() => _instance;
  BatchManager._internal();

  final Map<String, Timer> _timers = {};
  final Map<String, Future<void> Function()> _pendingCallbacks = {};

  /// Schedule a task to be executed after a delay.
  /// If a task with the same key is already scheduled, it is cancelled.
  /// 
  /// @param key - Unique identifier for the task (e.g., "reorder_list_123")
  /// @param callback - The function to execute (can be async)
  /// @param delay - Delay in milliseconds
  void schedule(String key, Future<void> Function() callback, int delayMs) {
    // Cancel existing timer for this key
    if (_timers.containsKey(key)) {
      _timers[key]!.cancel();
    }

    // Store callback for potential flush
    _pendingCallbacks[key] = callback;

    // Start new timer
    _timers[key] = Timer(Duration(milliseconds: delayMs), () async {
      try {
        await callback();
      } catch (e) {
        print('BatchManager error for $key: $e');
      } finally {
        _timers.remove(key);
        _pendingCallbacks.remove(key);
      }
    });
  }

  /// Cancel a scheduled task immediately.
  void cancel(String key) {
    if (_timers.containsKey(key)) {
      _timers[key]!.cancel();
      _timers.remove(key);
      _pendingCallbacks.remove(key);
    }
  }

  /// Check if there are pending operations
  bool get hasPending => _timers.isNotEmpty;

  /// Flush all pending operations immediately
  /// Useful when app is about to close
  Future<void> flushAll() async {
    final callbacks = Map<String, Future<void> Function()>.from(_pendingCallbacks);
    
    // Cancel all timers first
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pendingCallbacks.clear();

    // Execute all pending callbacks
    for (final entry in callbacks.entries) {
      try {
        await entry.value();
      } catch (e) {
        print('BatchManager flush error for ${entry.key}: $e');
      }
    }
  }
}

/// Global instance
final batchManager = BatchManager();
