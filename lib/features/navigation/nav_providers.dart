import 'package:flutter_riverpod/flutter_riverpod.dart';

final navIndexProvider = StateProvider<int>((ref) => 0);

/// Action callback to request focus on the TV Navigation Rail from anywhere in the app.
final tvRailFocusActionProvider = StateProvider<void Function()?>((ref) => null);
