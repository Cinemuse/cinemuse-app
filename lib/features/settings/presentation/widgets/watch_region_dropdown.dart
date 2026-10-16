import 'package:cinemuse_app/features/settings/application/watch_region_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_widgets.dart';

/// The "Streaming country" drop-down: every country TMDB has streaming data
/// for. While the list loads (or if TMDB can't answer) it shows only the
/// saved country, by its code.
class WatchRegionDropdown extends ConsumerWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const WatchRegionDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regions = ref.watch(watchRegionsProvider).valueOrNull ?? const [];
    final hasValue = regions.any((r) => r.code == value);

    Text name(String text) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);

    // A fixed width: the longest country name would push the row's label
    // off a phone screen.
    return SettingsSmallDropdown<String>(
      value: value,
      width: 150,
      menuWidth: 260,
      items: [
        if (!hasValue) DropdownMenuItem(value: value, child: name(value)),
        for (final r in regions)
          DropdownMenuItem(value: r.code, child: name(r.name)),
      ],
      onChanged: onChanged,
    );
  }
}
