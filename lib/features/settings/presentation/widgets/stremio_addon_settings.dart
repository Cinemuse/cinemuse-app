import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

class StremioAddonSettings extends ConsumerStatefulWidget {
  const StremioAddonSettings({super.key});

  @override
  ConsumerState<StremioAddonSettings> createState() => _StremioAddonSettingsState();
}

class _StremioAddonSettingsState extends ConsumerState<StremioAddonSettings> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  bool _showApiKey = false;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsAddonSuccess)),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                    onChanged: (val) => ref.read(settingsProvider.notifier).updateSettings({
                      'enableRealDebrid': val,
                    }),
                  ),
                ),
                if (settings.enableRealDebrid)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: TextField(
                      controller: TextEditingController(text: settings.realDebridKey),
                      style: const TextStyle(color: Colors.white),
                      obscureText: !_showApiKey,
                      decoration: InputDecoration(
                        labelText: l10n.settingsRealDebridKey,
                        labelStyle: const TextStyle(color: AppTheme.textMuted),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accent),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showApiKey ? LucideIcons.eye : LucideIcons.eyeOff,
                            color: AppTheme.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _showApiKey = !_showApiKey),
                        ),
                      ),
                      onChanged: (val) => ref.read(settingsProvider.notifier).updateSettings({
                        'realDebridKey': val,
                      }),
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
                Builder(
                  builder: (context) {
                    final isDebridActive = settings.enableRealDebrid && settings.realDebridKey.trim().isNotEmpty;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SettingsTile(
                          label: l10n.settingsEnableAnimeTosho,
                          description: "Native high-quality anime source (Torrent)",
                          icon: LucideIcons.zap,
                          trailing: SettingToggle(
                            value: settings.enableAnimeTosho && isDebridActive,
                            onChanged: isDebridActive 
                              ? (val) => ref.read(settingsProvider.notifier).updateSettings({
                                  'enableAnimeTosho': val,
                                })
                              : (val) {}, // No-op if disabled
                          ),
                        ),
                        SettingsTile(
                          label: l10n.settingsEnableVixSrc,
                          description: "Native direct streaming source (No Debrid required)",
                          icon: LucideIcons.playCircle,
                          showDivider: !isDebridActive,
                          trailing: SettingToggle(
                            value: settings.enableVixSrc,
                            onChanged: (val) => ref.read(settingsProvider.notifier).updateSettings({
                              'enableVixSrc': val,
                            }),
                          ),
                        ),
                        if (!isDebridActive)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orangeAccent),
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
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // Global Search Settings
        SettingsSection(
          title: "Search Preferences",
          children: [
            SettingsCard(
              children: [
                SettingsTile(
                  label: l10n.settingsSmartSearch,
                  description: l10n.settingsSmartSearchDesc,
                  icon: LucideIcons.filter,
                  showDivider: false,
                  trailing: SettingToggle(
                    value: settings.smartSearchFilter,
                    onChanged: (val) => ref.read(settingsProvider.notifier).updateSettings({
                      'smartSearchFilter': val,
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
                                hintStyle: const TextStyle(color: Colors.white24),
                                errorText: _error,
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppTheme.accent),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(l10n.settingsInstall),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.settingsAddonHint,
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
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
                            errorBuilder: (context, error, stackTrace) => const Icon(LucideIcons.box, size: 20, color: Colors.white70),
                          )
                        : const Icon(LucideIcons.box, size: 20, color: Colors.white70),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SettingToggle(
                          value: addon.enabled,
                          onChanged: (val) => ref.read(settingsProvider.notifier).toggleAddon(addon.id, val),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(LucideIcons.copy, color: AppTheme.textMuted, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: addon.baseUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.settingsCopiedToClipboard),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                                width: 200,
                              ),
                            );
                          },
                          tooltip: l10n.settingsCopy,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 18),
                          onPressed: () => ref.read(settingsProvider.notifier).removeAddon(addon.id),
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
                      Icon(LucideIcons.box, size: 64, color: Colors.white.withOpacity(0.05)),
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
