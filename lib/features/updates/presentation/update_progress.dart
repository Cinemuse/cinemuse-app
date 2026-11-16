import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The running update: the download's bar, percentage and Cancel, then
/// "restarting" (Windows, Linux) or "opening the installer" (Android). Shown by
/// Settings' Info & updates page and the update-required screen.
class UpdateProgress extends ConsumerWidget {
  const UpdateProgress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(updateProvider);

    if (state.status == UpdateStatus.readyToInstall) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              defaultTargetPlatform == TargetPlatform.android
                  ? l10n.updatePreparingInstaller
                  : l10n.updateRestarting,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.downloadingUpdate(state.progress.toStringAsFixed(0)),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: state.progress / 100,
          backgroundColor: Colors.white10,
          color: AppTheme.accent,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () => ref.read(updateProvider.notifier).cancelUpdate(),
            icon: const Icon(Icons.close, size: 18),
            label: Text(l10n.updateCancel),
          ),
        ),
      ],
    );
  }
}
