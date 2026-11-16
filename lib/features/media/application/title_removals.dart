import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Removals that wait for their Undo message, by title ('tv-1396',
/// 'movie-27205'). The title's other watch changes wait for it too, or the
/// removal would take them.
class TitleRemovals {
  TitleRemovals(this._ref);

  final Ref _ref;
  final Map<String, Future<void>> _pending = {};

  /// Waits for [title]'s pending removal, if any.
  Future<void> after(String title) async {
    try {
      await _pending[title];
    } catch (_) {
      // Safe to go on: the removal's own caller shows its error.
    }
  }

  /// Runs [remove] unless [undone] completes with true, after the title's
  /// earlier removal; the title's other watch changes wait for it. On Undo,
  /// and when [remove] fails, [showAgain] brings back what the screen hid;
  /// the error is rethrown for the UI to show.
  Future<void> removeUnlessUndone({
    required String title,
    required Future<bool> undone,
    required Future<void> Function() remove,
    required void Function() showAgain,
    required String action,
  }) async {
    final earlier = after(title);
    Future<void> run() async {
      final isUndone = await undone;
      if (isUndone) showAgain();
      await earlier;
      if (isUndone) return;
      try {
        await remove();
        _ref.invalidate(droppedListProvider);
        _ref.invalidate(continueWatchingProvider);
      } catch (e, stack) {
        AppLogger.error(
          'TitleRemovals',
          'Failed $action for $title',
          error: e,
          stackTrace: stack,
        );
        showAgain();
        rethrow;
      }
    }

    final removal = run();
    _pending[title] = removal;
    try {
      await removal;
    } finally {
      _pending.removeWhere((_, pending) => pending == removal);
    }
  }
}

// Not autoDispose: a removal outlives the screen that started it.
final titleRemovalsProvider = Provider<TitleRemovals>(TitleRemovals.new);
