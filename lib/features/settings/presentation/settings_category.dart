import 'package:cinemuse_app/features/settings/presentation/widgets/customization_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/identity_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/integrations/integrations_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/live_tv_settings.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The Settings categories, in sidebar order (REV-83).
enum SettingsCategory {
  identity(Icons.security),
  customization(Icons.smartphone),
  liveTv(Icons.live_tv),
  integrations(Icons.link);

  const SettingsCategory(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    identity => l10n.settingsIdentity,
    customization => l10n.settingsCustomization,
    liveTv => l10n.settingsLiveTv,
    integrations => l10n.settingsIntegrations,
  };

  Widget get content => switch (this) {
    identity => const IdentitySettings(),
    customization => const CustomizationSettings(),
    liveTv => const LiveTvSettings(),
    integrations => const IntegrationsSettings(),
  };
}
