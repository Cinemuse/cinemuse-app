import 'package:flutter_riverpod/misc.dart';

/// [defaults] then [own], keeping only the last override of each provider:
/// Riverpod refuses a provider overridden twice in one scope.
List<Override> withOwnOverrides(List<Override> defaults, List<Override> own) {
  final all = [...defaults, ...own];
  final lastIndex = {for (var i = 0; i < all.length; i++) all[i].origin: i};
  return [
    for (var i = 0; i < all.length; i++)
      if (lastIndex[all[i].origin] == i) all[i],
  ];
}
