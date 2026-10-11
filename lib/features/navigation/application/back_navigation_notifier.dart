import 'dart:async';

import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the shell must do after a Back press.
enum BackOutcome {
  /// Back did something (or there was nothing to do); no more steps.
  handled,

  /// First Back on Home: show "press Back again to exit".
  confirmExit,

  /// Second Back on Home in time: close the app.
  exit,
}

/// The one Back handler for the Android Back button, the TV remote, Escape
/// and the Back shortcut (REV-09, REV-12).
///
/// State: when "press Back again to exit" was last shown, or null.
class BackNavigationNotifier extends Notifier<DateTime?> {
  /// How long the second Back press may take to still close the app.
  static const exitWindow = Duration(seconds: 2);

  @override
  DateTime? build() => null;

  /// Runs the first step that applies: close the open page, leave Live TV
  /// full-window, go back to Home, and on Home ask to exit (only when
  /// [canExitApp]: Escape on PC must never close the app).
  BackOutcome handleBack({required bool canExitApp, DateTime? now}) {
    final navigator = ref.read(shellNavigatorKeyProvider).currentState;
    if (navigator != null && navigator.canPop()) {
      // maybePop, not pop: a page's PopScope can take a step of its own first
      // (e.g. Settings goes back to its category list, REV-86). Nothing to
      // await: the outcome is "handled" either way.
      unawaited(navigator.maybePop());
      return BackOutcome.handled;
    }

    final tab = ref.read(navIndexProvider);
    if (tab == NavTab.liveTv &&
        ref.read(liveTvViewModeProvider) == LiveTvViewMode.fullWindow) {
      ref.read(liveTvViewModeProvider.notifier).state = LiveTvViewMode.split;
      return BackOutcome.handled;
    }

    if (tab != NavTab.home) {
      ref.read(navIndexProvider.notifier).state = NavTab.home;
      return BackOutcome.handled;
    }

    if (!canExitApp) return BackOutcome.handled;

    final time = now ?? DateTime.now();
    final askedAt = state;
    if (askedAt != null && time.difference(askedAt) < exitWindow) {
      state = null;
      return BackOutcome.exit;
    }
    state = time;
    return BackOutcome.confirmExit;
  }
}

/// Not autoDispose: nothing watches it, and the "asked at" time must survive
/// between two Back presses.
final backNavigationProvider =
    NotifierProvider<BackNavigationNotifier, DateTime?>(
      BackNavigationNotifier.new,
    );
