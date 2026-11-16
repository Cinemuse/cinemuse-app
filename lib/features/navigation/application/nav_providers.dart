import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/application/settable_notifier.dart';

/// Tab indexes of the shell, in navbar order (REV-12).
abstract final class NavTab {
  static const home = 0;
  static const explore = 1;
  static const liveTv = 2;
  static const profile = 3;
}

// Kept for the session, like the focus callbacks below: the shell and every
// tab use them for as long as the app runs.
final navIndexProvider = NotifierProvider<SettableNotifier<int>, int>(
  () => SettableNotifier(NavTab.home),
);

/// The navigator inside the shell (pages opened from a tab). Lives for the
/// whole session: the shell and the Back handling share the same key.
final shellNavigatorKeyProvider = Provider(
  (ref) => GlobalKey<NavigatorState>(),
);

/// Action callback to request focus on the Top Navbar from anywhere in the app.
final topNavbarFocusActionProvider =
    NotifierProvider<SettableNotifier<void Function()?>, void Function()?>(
      () => SettableNotifier(null),
    );

/// Registry mapping a [NavTab] index to its content focus callback.
final pageContentFocusActionsProvider =
    NotifierProvider<
      SettableNotifier<Map<int, void Function()>>,
      Map<int, void Function()>
    >(() => SettableNotifier(const {}));
