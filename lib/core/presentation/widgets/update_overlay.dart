import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/services/updates/update_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

class UpdateOverlay extends ConsumerWidget {
  const UpdateOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    if (updateState.status == UpdateStatus.initial || 
        updateState.status == UpdateStatus.upToDate ||
        updateState.status == UpdateStatus.checking) {
      return const SizedBox.shrink();
    }

    if (updateState.status == UpdateStatus.available) {
      return _buildUpdateBanner(context, ref, l10n, updateState);
    }


    if (updateState.status == UpdateStatus.downloading) {
      return _buildDownloadOverlay(context, l10n, updateState);
    }


    if (updateState.status == UpdateStatus.readyToInstall) {
      return _buildReadyBanner(context, l10n);
    }


    return const SizedBox.shrink();
  }

  Widget _buildUpdateBanner(BuildContext context, WidgetRef ref, AppLocalizations l10n, UpdateState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.secondary.withAlpha((0.9 * 255).toInt()),
      child: Row(
        children: [
          const Icon(Icons.system_update_alt, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${l10n.updateAvailable}: ${state.latestVersion}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => _showUpdateDialog(context, ref, l10n),
            child: Text(
              l10n.updateNow,
              style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadOverlay(BuildContext context, AppLocalizations l10n, UpdateState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black.withAlpha((0.8 * 255).toInt()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.downloadingUpdate(state.progress.toStringAsFixed(0)),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),

          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: state.progress / 100,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyBanner(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.green.withAlpha((0.9 * 255).toInt()),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Update downloaded. Restarting...',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primary,
        title: Text(l10n.updateDialogTitle),
        content: Text(l10n.updateDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.later, style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
            onPressed: () {
              ref.read(updateProvider.notifier).startUpdate();
              Navigator.pop(context);
            },
            child: Text(l10n.updateNow),
          ),
        ],
      ),
    );
  }
}
