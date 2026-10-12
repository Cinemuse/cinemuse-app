import 'package:flutter/widgets.dart';

/// Shared screen-width breakpoints, so every widget picks the same layout
/// for the same window size (REV-51). Add new sizes here instead of writing
/// pixel numbers in widgets.
abstract final class Breakpoints {
  /// Below this width the app uses the phone layout (bottom bar).
  static const double compact = 600;

  /// Below this width a block (usually measured with a `LayoutBuilder`)
  /// stacks its controls in a column: the Explore header and filter panel,
  /// the Profile overview and the Watch history header.
  static const double medium = 800;

  /// From this width up, TMDB images are loaded in a bigger size. Also the
  /// widest a bottom sheet gets.
  static const double large = 1200;

  /// Whether the current window is narrower than [compact].
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  /// Whether the current window is at least [large] wide.
  static bool isLarge(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= large;
}
