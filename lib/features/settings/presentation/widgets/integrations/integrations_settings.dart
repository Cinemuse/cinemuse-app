import 'package:cinemuse_app/features/settings/presentation/widgets/integrations/addon_install_section.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/integrations/built_in_sources_section.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/integrations/debrid_section.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/integrations/installed_addons_section.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/integrations/open_subtitles_section.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/integrations/search_options_section.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The Integrations category: debrid, subtitles, sources, add-ons.
class IntegrationsSettings extends StatelessWidget {
  const IntegrationsSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsSection(
      title: l10n.settingsIntegrations,
      description: l10n.settingsIntegrationsDesc,
      children: const [
        DebridSection(),
        OpenSubtitlesSection(),
        BuiltInSourcesSection(),
        SearchOptionsSection(),
        AddonInstallSection(),
        InstalledAddonsSection(),
      ],
    );
  }
}
