import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/save_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// The app's own sources: the anime torrent feed (needs debrid), the movie
/// and series site, the anime site. Their names come from the server's list.
class BuiltInSourcesSection extends ConsumerWidget {
  const BuiltInSourcesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final save = settingsSaver(context, ref);
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final names =
        ref.watch(serverAddressesProvider).value ?? ServerAddresses.empty;
    final torrentFeed = names.name(ServerAddress.animeTorrents);

    return SettingsSection(
      title: l10n.settingsNativeIntegrations,
      children: [
        SettingsCard(
          children: [
            SettingsToggleTile(
              label: l10n.settingsEnableSource(torrentFeed),
              description: l10n.settingsAnimeTorrentsDesc,
              icon: LucideIcons.zap,
              showDivider: settings.hasDebrid,
              value: settings.isAnimeTorrentsActive,
              onChanged: settings.hasDebrid
                  ? (val) => save((s) => s.copyWith(enableAnimeTorrents: val))
                  : null,
            ),
            // Under its own tile: only the torrent feed needs debrid.
            if (!settings.hasDebrid) ...[
              _NeedsDebridWarning(torrentFeed),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.05),
                indent: 52,
              ),
            ],
            SettingsToggleTile(
              label: l10n.settingsEnableSource(
                names.name(ServerAddress.movieSite),
              ),
              description: l10n.settingsMovieSiteDesc,
              icon: LucideIcons.playCircle,
              value: settings.enableMovieSite,
              onChanged: (val) => save((s) => s.copyWith(enableMovieSite: val)),
            ),
            SettingsToggleTile(
              label: l10n.settingsEnableSource(
                names.name(ServerAddress.animeSite),
              ),
              description: l10n.settingsEnableBuiltInAnimeDesc,
              icon: LucideIcons.playCircle,
              showDivider: false,
              value: settings.enableAnimeSite,
              onChanged: (val) => save((s) => s.copyWith(enableAnimeSite: val)),
            ),
          ],
        ),
      ],
    );
  }
}

class _NeedsDebridWarning extends StatelessWidget {
  final String torrentFeed;

  const _NeedsDebridWarning(this.torrentFeed);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              )!.settingsAnimeTorrentsNeedDebrid(torrentFeed),
              style: const TextStyle(
                color: AppTheme.warning,
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
