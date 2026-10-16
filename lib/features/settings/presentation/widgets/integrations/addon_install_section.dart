import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_input.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The box to install a Stremio add-on from its manifest link.
class AddonInstallSection extends ConsumerStatefulWidget {
  const AddonInstallSection({super.key});

  @override
  ConsumerState<AddonInstallSection> createState() =>
      _AddonInstallSectionState();
}

class _AddonInstallSectionState extends ConsumerState<AddonInstallSection> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SettingsSection(
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
                        child: SettingsTextField(
                          controller: _urlController,
                          decoration: settingsInputDecoration(
                            hintText: "https://.../manifest.json",
                            errorText: _error,
                          ),
                          onSubmitted: (_) => _installAddon(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _InstallButton(
                        isLoading: _isLoading,
                        onPressed: _installAddon,
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
    );
  }
}

class _InstallButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _InstallButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(AppLocalizations.of(context)!.settingsInstall),
      ),
    );
  }
}
