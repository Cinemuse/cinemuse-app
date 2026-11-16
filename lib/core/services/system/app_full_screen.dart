import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:cinemuse_app/core/utils/platform_info.dart';

/// What the app asks of its own window on Windows and Linux.
class AppWindow {
  const AppWindow();

  Future<void> setFullScreen(bool on) => windowManager.setFullScreen(on);

  Future<void> close() => windowManager.close();
}

final appWindowProvider = Provider<AppWindow>((ref) => const AppWindow());

/// Whether the whole app fills the screen, on Windows and Linux: F11
/// anywhere, or the "Start in full screen" setting. The player's own full
/// screen is separate: it ends when the player closes.
class AppFullScreenNotifier extends Notifier<bool> {
  /// True when the window was already made full screen at start.
  final bool startsOn;

  AppFullScreenNotifier({this.startsOn = false});

  @override
  bool build() => startsOn;

  Future<void> set(bool on) async {
    if (!PlatformInfo.isDesktop || on == state) return;
    state = on;
    await ref.read(appWindowProvider).setFullScreen(on);
  }

  Future<void> toggle() => set(!state);
}

final appFullScreenProvider = NotifierProvider<AppFullScreenNotifier, bool>(
  AppFullScreenNotifier.new,
);
