import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/save_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// How the stream search behaves: smart filter, skipping slow providers.
class SearchOptionsSection extends ConsumerWidget {
  const SearchOptionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = settingsSaver(context, ref);
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);

    return SettingsSection(
      title: l10n.settingsSearchPreferences,
      children: [
        SettingsCard(
          children: [
            SettingsToggleTile(
              label: l10n.settingsSmartSearch,
              description: l10n.settingsSmartSearchDesc,
              icon: LucideIcons.filter,
              value: settings.smartSearchFilter,
              onChanged: (val) =>
                  save((s) => s.copyWith(smartSearchFilter: val)),
            ),
            SettingsToggleTile(
              label: l10n.settingsAutoSkipProviders,
              description: l10n.settingsAutoSkipProvidersDesc,
              icon: LucideIcons.clock,
              showDivider: false,
              value: settings.enableAutoSkipProviders,
              onChanged: (val) =>
                  save((s) => s.copyWith(enableAutoSkipProviders: val)),
            ),
          ],
        ),
      ],
    );
  }
}
