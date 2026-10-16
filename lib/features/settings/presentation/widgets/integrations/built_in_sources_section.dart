import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/save_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// The app's own sources: AnimeTosho (needs debrid), VixSrc, AnimeUnity.
class BuiltInSourcesSection extends ConsumerWidget {
  const BuiltInSourcesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = settingsSaver(context, ref);
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);

    return SettingsSection(
      title: l10n.settingsNativeIntegrations,
      children: [
        SettingsCard(
          children: [
            SettingsToggleTile(
              label: l10n.settingsEnableAnimeTosho,
              description: "Native high-quality anime source (Torrent)",
              icon: LucideIcons.zap,
              showDivider: settings.hasDebrid,
              value: settings.isAnimeToshoActive,
              onChanged: settings.hasDebrid
                  ? (val) => save((s) => s.copyWith(enableAnimeTosho: val))
                  : null,
            ),
            // Under its own tile: only AnimeTosho needs debrid.
            if (!settings.hasDebrid) ...[
              const _NeedsDebridWarning(),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.05),
                indent: 52,
              ),
            ],
            SettingsToggleTile(
              label: l10n.settingsEnableVixSrc,
              description:
                  "Native direct streaming source (No Debrid required)",
              icon: LucideIcons.playCircle,
              value: settings.enableVixSrc,
              onChanged: (val) => save((s) => s.copyWith(enableVixSrc: val)),
            ),
            SettingsToggleTile(
              label: l10n.settingsEnableAnimeUnity,
              description: l10n.settingsEnableAnimeUnityDesc,
              icon: LucideIcons.playCircle,
              showDivider: false,
              value: settings.enableAnimeUnity,
              onChanged: (val) =>
                  save((s) => s.copyWith(enableAnimeUnity: val)),
            ),
          ],
        ),
      ],
    );
  }
}

class _NeedsDebridWarning extends StatelessWidget {
  const _NeedsDebridWarning();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.orangeAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.settingsEnableAnimeToshoWarning,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
