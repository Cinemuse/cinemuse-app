import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's own font (Outfit) for the rest of the test file, so text
/// is as wide as in the app: the default test font draws every letter as a
/// full square, and a row that fits in the app overflows in the test.
/// The widgets pick it up through `AppTheme.darkTheme` or `DesktopTypography`.
Future<void> loadAppFont() async {
  final bytes = File('assets/fonts/outfit.ttf').readAsBytesSync();
  final loader = FontLoader('Outfit')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}
