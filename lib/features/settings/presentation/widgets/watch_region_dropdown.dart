import 'package:cinemuse_app/features/settings/application/watch_region_providers.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_choice.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The "Streaming country" row: every country TMDB has streaming data for.
/// While the list loads (or if TMDB can't answer) it shows only the saved
/// country, by its code.
class WatchRegionTile extends ConsumerWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const WatchRegionTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final regions = ref.watch(watchRegionsProvider).value ?? const [];
    final hasValue = regions.any((r) => r.code == value);

    return SettingsChoiceTile<String>(
      label: l10n.settingsWatchRegion,
      description: l10n.settingsWatchRegionDesc,
      icon: Icons.public,
      value: value,
      choices: [
        if (!hasValue) SettingsChoice(value, value),
        for (final r in regions) SettingsChoice(r.code, r.name),
      ],
      onChanged: onChanged,
    );
  }
}
