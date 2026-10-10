import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab indexes of the shell, in navbar order (REV-12).
abstract final class NavTab {
  static const home = 0;
  static const explore = 1;
  static const liveTv = 2;
  static const profile = 3;
}

final navIndexProvider = StateProvider<int>((ref) => NavTab.home);

/// The navigator inside the shell (pages opened from a tab). Lives for the
/// whole session: the shell and the Back handling share the same key.
final shellNavigatorKeyProvider = Provider(
  (ref) => GlobalKey<NavigatorState>(),
);

/// Action callback to request focus on the Top Navbar from anywhere in the app.
final topNavbarFocusActionProvider = StateProvider<void Function()?>(
  (ref) => null,
);

/// Action callback to request focus on the first element of the current page content from the Top Navbar.
final pageContentFocusActionProvider = StateProvider<void Function()?>(
  (ref) => null,
);

/// Registry mapping a [NavTab] index to its content focus callback.
final pageContentFocusActionsProvider =
    StateProvider<Map<int, void Function()>>((ref) => const {});
