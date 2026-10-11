import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/streaming/models/stremio_addon.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/save_settings.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_input.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';

class AddonSettings extends ConsumerStatefulWidget {
  const AddonSettings({super.key});

  @override
  ConsumerState<AddonSettings> createState() => _AddonSettingsState();
}

class _AddonSettingsState extends ConsumerState<AddonSettings> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _installAddon() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(settingsProvider.notifier).installAddon(url);
      _urlController.clear();
      if (mounted) {
        AppSnackBar.show(context, message: l10n.settingsAddonSuccess);
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is ValidationFailure
          ? l10n.settingsAddonInvalid
          : ref.read(errorMapperProvider).map(e).message;
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Removes [addon] with an Undo snackbar (REV-78).
  Future<void> _removeAddon(StremioAddon addon) async {
    final l10n = AppLocalizations.of(context)!;
    final index = ref
        .read(settingsProvider)
        .installedAddons
        .indexWhere((a) => a.id == addon.id);

    await runSettingsSave(context, ref, (s) => s.removeAddon(addon.id));
    final isRemoved = !ref
        .read(settingsProvider)
        .installedAddons
        .any((a) => a.id == addon.id);
    if (!mounted || !isRemoved) return; // the save failed and said so

    AppSnackBar.show(
      context,
      message: l10n.settingsAddonRemoved(addon.name),
      actionLabel: l10n.commonUndo,
      onAction: () {
        // Undo needs this screen's context for its error message.
        if (!mounted) return;
        unawaited(
          runSettingsSave(context, ref, (s) => s.restoreAddon(addon, index)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final addons = settings.installedAddons;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Debrid Services
        SettingsSection(
          title: l10n.settingsDebridServices,
          children: [
            SettingsCard(
              children: [
                SettingsTile(
                  label: l10n.settingsRealDebridTitle,
                  description: l10n.settingsRealDebridKeyDesc,
                  icon: LucideIcons.hardDrive,
                  trailing: SettingToggle(
                    value: settings.enableRealDebrid,
                    onChanged: (val) =>
                        saveSettings(context, ref, {'enableRealDebrid': val}),
                  ),
                ),
                if (settings.enableRealDebrid)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: SettingInput(
                      value: settings.realDebridKey,
                      placeholder: l10n.settingsRealDebridKey,
                      isPassword: true,
                      onSave: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateSettings({'realDebridKey': val.trim()}),
                    ),
                  ),
                SettingsTile(
                  label: l10n.settingsTorBoxTitle,
                  description: l10n.settingsTorBoxKeyDesc,
                  icon: LucideIcons.box,
                  trailing: SettingToggle(
                    value: settings.enableTorBox,
                    onChanged: (val) =>
                        saveSettings(context, ref, {'enableTorBox': val}),
                  ),
                ),
                if (settings.enableTorBox)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: SettingInput(
                      value: settings.torBoxKey,
                      placeholder: l10n.settingsTorBoxKey,
                      isPassword: true,
                      onSave: (val) => ref
                          .read(settingsProvider.notifier)
                          .updateSettings({'torBoxKey': val.trim()}),
                    ),
                  ),
                if (settings.enableRealDebrid && settings.enableTorBox)
                  SettingsTile(
                    label: l10n.settingsPreferredDebridTitle,
                    description: l10n.settingsPreferredDebridDesc,
                    icon: Icons.swap_vert_rounded,
                    trailing: DropdownButton<String>(
                      value:
                          settings.preferredDebridProvider.toLowerCase() ==
                              'torbox'
                          ? 'torbox'
                          : 'realdebrid',
                      dropdownColor: AppTheme.surface,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: 'realdebrid',
                          child: Text(
                            'Real-Debrid',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'torbox',
                          child: Text(
                            'TorBox',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          saveSettings(context, ref, {
                            'preferredDebridProvider': val,
                          });
                        }
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),

        // External Subtitle Services
        SettingsSection(
          title: l10n.settingsOpenSubtitlesTitle,
          children: [
            SettingsCard(
              children: [
                SettingsTile(
                  label: l10n.settingsOpenSubtitlesTitle,
                  description: l10n.settingsOpenSubtitlesKeyDesc,
                  icon: LucideIcons.subtitles,
                  showDivider: false,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SettingInput(
                    value: settings.openSubtitlesKey,
                    placeholder: l10n.settingsOpenSubtitlesKey,
                    isPassword: true,
                    onSave: (val) => ref
                        .read(settingsProvider.notifier)
                        .updateSettings({'openSubtitlesKey': val.trim()}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SettingToggle(
                    label: l10n.settingsOpenSubtitlesAutoDownloadTitle,
                    description: l10n.settingsOpenSubtitlesAutoDownloadDesc,
                    value: settings.autoDownloadMissingSubtitles,
                    onChanged: (val) {
                      saveSettings(context, ref, {
                        'autoDownloadMissingSubtitles': val,
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),

        // Native Providers
        SettingsSection(
          title: l10n.settingsNativeIntegrations,
          children: [
            SettingsCard(
              children: [
                SettingsTile(
                  label: l10n.settingsEnableAnimeTosho,
                  description: "Native high-quality anime source (Torrent)",
                  icon: LucideIcons.zap,
                  showDivider: settings.hasDebrid,
                  trailing: SettingToggle(
                    value: settings.isAnimeToshoActive,
                    onChanged: settings.hasDebrid
                        ? (val) => saveSettings(context, ref, {
                            'enableAnimeTosho': val,
                          })
                        : null,
                  ),
                ),
                // Under its own tile: only AnimeTosho needs debrid.
                if (!settings.hasDebrid) ...[
                  Padding(
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
                            l10n.settingsEnableAnimeToshoWarning,
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.05),
                    indent: 52,
                  ),
                ],
                SettingsTile(
                  label: l10n.settingsEnableVixSrc,
                  description:
                      "Native direct streaming source (No Debrid required)",
                  icon: LucideIcons.playCircle,
                  trailing: SettingToggle(
                    value: settings.enableVixSrc,
                    onChanged: (val) =>
                        saveSettings(context, ref, {'enableVixSrc': val}),
                  ),
                ),
                SettingsTile(
                  label: l10n.settingsEnableAnimeUnity,
                  description: l10n.settingsEnableAnimeUnityDesc,
                  icon: LucideIcons.playCircle,
                  showDivider: false,
                  trailing: SettingToggle(
                    value: settings.enableAnimeUnity,
                    onChanged: (val) =>
                        saveSettings(context, ref, {'enableAnimeUnity': val}),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Global Search Settings
        SettingsSection(
          title: l10n.settingsSearchPreferences,
          children: [
            SettingsCard(
              children: [
                SettingsTile(
                  label: l10n.settingsSmartSearch,
                  description: l10n.settingsSmartSearchDesc,
                  icon: LucideIcons.filter,
                  showDivider: true,
                  trailing: SettingToggle(
                    value: settings.smartSearchFilter,
                    onChanged: (val) =>
                        saveSettings(context, ref, {'smartSearchFilter': val}),
                  ),
                ),
                SettingsTile(
                  label: l10n.settingsAutoSkipProviders,
                  description: l10n.settingsAutoSkipProvidersDesc,
                  icon: LucideIcons.clock,
                  showDivider: false,
                  trailing: SettingToggle(
                    value: settings.enableAutoSkipProviders,
                    onChanged: (val) => saveSettings(context, ref, {
                      'enableAutoSkipProviders': val,
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Install New Addon
        SettingsSection(
          title: l10n.settingsAddNewAddon,
          children: [
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "https://.../manifest.json",
                                hintStyle: const TextStyle(
                                  color: Colors.white24,
                                ),
                                errorText: _error,
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppTheme.accent,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: (_) => _installAddon(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _installAddon,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(l10n.settingsInstall),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.settingsAddonHint,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // Installed Addons List
        if (addons.isNotEmpty)
          SettingsSection(
            title: l10n.settingsInstalledAddons,
            children: [
              SettingsCard(
                padding: EdgeInsets.zero,
                children: addons.map((addon) {
                  final isLast = addon == addons.last;
                  return SettingsTile(
                    label: addon.name,
                    description: addon.baseUrl,
                    leading: addon.logo != null && addon.logo!.isNotEmpty
                        ? Image.network(
                            addon.logo!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  LucideIcons.box,
                                  size: 20,
                                  color: Colors.white70,
                                ),
                          )
                        : const Icon(
                            LucideIcons.box,
                            size: 20,
                            color: Colors.white70,
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SettingToggle(
                          value: addon.enabled,
                          onChanged: (val) => runSettingsSave(
                            context,
                            ref,
                            (settings) => settings.toggleAddon(addon.id, val),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.copy,
                            color: AppTheme.textMuted,
                            size: 18,
                          ),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: addon.baseUrl),
                            );
                            AppSnackBar.show(
                              context,
                              message: l10n.settingsCopiedToClipboard,
                              duration: const Duration(seconds: 1),
                            );
                          },
                          tooltip: l10n.settingsCopy,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.trash2,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          onPressed: () => _removeAddon(addon),
                          tooltip: l10n.settingsRemove,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                    showDivider: !isLast,
                  );
                }).toList(),
              ),
            ],
          )
        else
          SettingsCard(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.box,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.settingsNoAddons,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
