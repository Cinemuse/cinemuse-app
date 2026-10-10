import 'package:flutter_riverpod/flutter_riverpod.dart';

final navIndexProvider = StateProvider<int>((ref) => 0);

/// Action callback to request focus on the Top Navbar from anywhere in the app.
final topNavbarFocusActionProvider = StateProvider<void Function()?>(
  (ref) => null,
);

/// Action callback to request focus on the first element of the current page content from the Top Navbar.
final pageContentFocusActionProvider = StateProvider<void Function()?>(
  (ref) => null,
);

/// Registry mapping page index (0: Home, 1: Explore, 2: Live TV, 3: Profile) to its content focus callback.
final pageContentFocusActionsProvider =
    StateProvider<Map<int, void Function()>>((ref) => const {});
