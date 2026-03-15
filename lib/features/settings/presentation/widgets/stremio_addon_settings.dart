import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

class StremioAddonSettings extends ConsumerStatefulWidget {
  const StremioAddonSettings({super.key});

  @override
  ConsumerState<StremioAddonSettings> createState() => _StremioAddonSettingsState();
}

class _StremioAddonSettingsState extends ConsumerState<StremioAddonSettings> {
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            l10n.settingsDebridServices.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        SettingsCard(
          margin: const EdgeInsets.only(bottom: 24),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.hardDrive, color: Colors.blueAccent, size: 20),
              ),
              title: Text(
                l10n.settingsRealDebridTitle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                l10n.settingsRealDebridKeyDesc,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              trailing: Switch(
                value: settings.enableRealDebrid,
                onChanged: (val) => ref.read(settingsProvider.notifier).updateSettings({
                  'enableRealDebrid': val,
                }),
                activeColor: AppTheme.accent,
              ),
            ),
            if (settings.enableRealDebrid) ...[
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: settings.realDebridKey),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l10n.settingsRealDebridKey,
                  labelStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) => ref.read(settingsProvider.notifier).updateSettings({
                  'realDebridKey': val,
                }),
              ),
            ],
          ],
        ),

        // Native Providers
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            l10n.settingsNativeIntegrations.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        SettingsCard(
          margin: const EdgeInsets.only(bottom: 24),
          children: [
            Builder(
              builder: (context) {
                final isDebridActive = settings.enableRealDebrid && settings.realDebridKey.trim().isNotEmpty;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.zap, color: AppTheme.accent, size: 20),
                      ),
                      title: Text(
                        l10n.settingsEnableAnimeTosho,
                        style: TextStyle(
                          color: isDebridActive ? Colors.white : Colors.white.withOpacity(0.3),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        "Native high-quality anime source (Torrent)",
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                      trailing: Switch(
                        value: settings.enableAnimeTosho && isDebridActive,
                        onChanged: isDebridActive 
                          ? (val) => ref.read(settingsProvider.notifier).updateSettings({
                              'enableAnimeTosho': val,
                            })
                          : null,
                        activeColor: AppTheme.accent,
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.playCircle, color: Colors.purpleAccent, size: 20),
                      ),
                      title: Text(
                        l10n.settingsEnableVixSrc,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        "Native direct streaming source (No Debrid required)",
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                      trailing: Switch(
                        value: settings.enableVixSrc,
                        onChanged: (val) => ref.read(settingsProvider.notifier).updateSettings({
                          'enableVixSrc': val,
                        }),
                        activeColor: AppTheme.accent,
                      ),
                    ),
                    if (!isDebridActive)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 52),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orangeAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.settingsEnableAnimeToshoWarning,
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 11,
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

        // Install New Addon
        SettingsCard(
          children: [
            Text(
              l10n.settingsAddNewAddon,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
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
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
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
            const SizedBox(height: 8),
            Text(
              l10n.settingsAddonHint,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),

        // Installed Addons List
        if (addons.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              l10n.settingsInstalledAddons,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          ...addons.map((addon) => SettingsCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: addon.icon != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(addon.icon!, width: 40, height: 40, fit: BoxFit.cover),
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.package, color: AppTheme.textMuted, size: 20),
                      ),
                title: Text(
                  addon.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  addon.baseUrl,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: addon.enabled,
                      onChanged: (val) => ref.read(settingsProvider.notifier).toggleAddon(addon.id, val),
                      activeColor: AppTheme.accent,
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                      onPressed: () => ref.read(settingsProvider.notifier).removeAddon(addon.id),
                    ),
                  ],
                ),
              ),
            ],
          )),
        ] else
          SettingsCard(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.box, size: 48, color: Colors.white10),
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
