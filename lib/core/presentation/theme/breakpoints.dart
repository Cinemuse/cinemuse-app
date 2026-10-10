import 'package:flutter/widgets.dart';

/// Shared screen-width breakpoints, so every widget picks the same layout
/// for the same window size (REV-51). Add new sizes here instead of writing
/// pixel numbers in widgets.
abstract final class Breakpoints {
  /// Below this width the app uses the phone layout (bottom bar).
  static const double compact = 600;

  /// Whether the current window is narrower than [compact].
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;
}
