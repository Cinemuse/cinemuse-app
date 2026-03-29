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

    // 1. If no update or checking, show nothing (ignore full-screen)
    if (updateState.status == UpdateStatus.initial || 
        updateState.status == UpdateStatus.upToDate ||
        updateState.status == UpdateStatus.checking) {
      return const SizedBox.shrink();
    }

    // 2. Active Update Blocking Modal (Downloading or Ready)
    if (updateState.status == UpdateStatus.downloading || 
        updateState.status == UpdateStatus.readyToInstall) {
      return Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              color: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.system_update_alt, size: 48, color: AppTheme.secondary),
                    const SizedBox(height: 16),
                    Text(
                      updateState.status == UpdateStatus.readyToInstall 
                        ? 'Update Ready' 
                        : 'Updating Cinemuse...',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      updateState.status == UpdateStatus.readyToInstall
                        ? 'Files swapped. Restarting in a moment...'
                        : 'Please wait while we prepare the new version. Do not close the app.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    if (updateState.status == UpdateStatus.downloading) ...[
                      LinearProgressIndicator(
                        value: updateState.progress / 100,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${updateState.progress.toStringAsFixed(0)}%',
                        style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold),
                      ),
                    ] else ...[
                      const CircularProgressIndicator(color: Colors.green),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final double topOffset = isMobile ? (MediaQuery.of(context).padding.top + 60.0) : 80.0;

    // 3. Banner/Error Overlay (Non-blocking but on top)
    return Stack(
      children: [
        if (updateState.status == UpdateStatus.available)
          Positioned(
            top: topOffset,
            left: 0,
            right: 0,
            child: _buildUpdateBanner(context, ref, l10n, updateState),
          ),
        if (updateState.status == UpdateStatus.error)
          Positioned(
            top: topOffset,
            left: 0,
            right: 0,
            child: _buildErrorBanner(context, ref, updateState.error ?? 'Unknown error'),
          ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, WidgetRef ref, String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.redAccent.withAlpha((0.9 * 255).toInt()),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Update check failed: $error',
              style: const TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: () => ref.read(updateProvider.notifier).dismissUpdate(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
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
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () => ref.read(updateProvider.notifier).dismissUpdate(),
            padding: const EdgeInsets.only(left: 8),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
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
