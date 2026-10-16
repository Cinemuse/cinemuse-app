import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/features/updates/presentation/update_overlay.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown instead of the app when it is older than the database allows
/// (REV-306). Windows and Android update from here; Linux gets a short text.
/// The download progress is the [UpdateOverlay] on top.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final isLinux = defaultTargetPlatform == TargetPlatform.linux;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.system_update_alt,
                  color: AppTheme.accent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.updateRequiredTitle,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.updateRequiredMessage,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                if (isLinux)
                  Text(
                    l10n.updateRequiredLinux,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  )
                else
                  const _UpdateAction(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Update now" once the release is found; while looking, a spinner; when
/// it can't be found (offline, GitHub error), the reason and Retry.
class _UpdateAction extends ConsumerWidget {
  const _UpdateAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(updateProvider);
    final notifier = ref.read(updateProvider.notifier);

    switch (state.status) {
      case UpdateStatus.available:
        return ElevatedButton.icon(
          autofocus: true,
          onPressed: notifier.startUpdate,
          icon: const Icon(Icons.system_update_alt),
          label: Text(l10n.updateNow),
        );
      case UpdateStatus.initial ||
          UpdateStatus.checking ||
          UpdateStatus.downloading ||
          UpdateStatus.readyToInstall:
        return const CircularProgressIndicator(color: AppTheme.accent);
      case UpdateStatus.error || UpdateStatus.upToDate:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.status == UpdateStatus.error) ...[
              Text(
                updateErrorMessage(l10n, state),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.error),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton.icon(
              autofocus: true,
              onPressed: notifier.checkForUpdates,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.commonRetry),
            ),
          ],
        );
    }
  }
}
