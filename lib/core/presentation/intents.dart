import 'package:flutter/widgets.dart';

class BackIntent extends Intent {
  const BackIntent();
}

/// F11: the whole app in or out of full screen (Windows and Linux).
class ToggleFullScreenIntent extends Intent {
  const ToggleFullScreenIntent();
}
