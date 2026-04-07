import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/services/updates/update_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:io';


class UpdateOverlay extends ConsumerWidget {
  const UpdateOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    // 1. If no update or checking, show nothing (ignore full-screen)
    if (kDebugMode || 
        updateState.status == UpdateStatus.initial || 
        updateState.status == UpdateStatus.upToDate ||
        updateState.status == UpdateStatus.checking) {
      return const SizedBox.shrink();
    }

    // 2. Active Update Blocking Modal (Downloading or Ready)
    if (updateState.status == UpdateStatus.downloading || 
        updateState.status == UpdateStatus.readyToInstall) {
      return Container(
        color: Colors.black.withAlpha((0.85 * 255).toInt()),
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
                    const Icon(Icons.system_update_alt, size: 48, color: AppTheme.accent),
                    const SizedBox(height: 16),
                    Text(
                      updateState.status == UpdateStatus.readyToInstall 
                        ? l10n.updateReadyToInstall 
                        : l10n.downloadingUpdate(updateState.progress.toStringAsFixed(0)),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      updateState.status == UpdateStatus.readyToInstall
                        ? (Platform.isAndroid 
                            ? 'Preparing to launch the installer...' 
                            : 'Files swapped. Restarting in a moment...')
                        : 'Please wait while we prepare the new version. Do not close the app.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    if (updateState.status == UpdateStatus.downloading) ...[
                      LinearProgressIndicator(
                        value: updateState.progress / 100,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${updateState.progress.toStringAsFixed(0)}%',
                        style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => ref.read(updateProvider.notifier).cancelUpdate(),
                        icon: const Icon(Icons.cancel, color: Colors.white60, size: 18),
                        label: Text(l10n.updateCancel, style: const TextStyle(color: Colors.white60)),
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
            child: _buildErrorBanner(context, ref, l10n, updateState),
          ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, WidgetRef ref, AppLocalizations l10n, UpdateState state) {
    String errorMessage = state.error ?? l10n.updateFailed;
    
    // Attempt to localize if we have an errorKey
    if (state.errorKey != null) {
      switch (state.errorKey) {
        case 'updateNoCompatibleApk':
          errorMessage = l10n.updateNoCompatibleApk(state.errorArgs?['abi'] ?? 'unknown');
          break;
        case 'updateNetworkError':
          errorMessage = l10n.updateNetworkError;
          break;
        case 'updateStorageError':
          errorMessage = l10n.updateStorageError;
          break;
        case 'updateSourceError':
          errorMessage = l10n.updateSourceError;
          break;
        case 'updateFailed':
          errorMessage = l10n.updateFailed;
          break;
      }
    }

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
              errorMessage,
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
            onPressed: () => _showUpdateDialog(context, ref, l10n, state),
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

  void _showUpdateDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n, UpdateState updateState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primary,
        title: Row(
          children: [
            const Icon(Icons.system_update_alt, color: AppTheme.accent),
            const SizedBox(width: 12),
            Text(l10n.updateDialogTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.updateDialogMessage),
            if (updateState.releaseNotes != null && updateState.releaseNotes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              Text(
                l10n.updateChangelog,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.accent),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: MarkdownBody(
                      data: updateState.releaseNotes!,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 12, color: Colors.white70),
                        h1: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        h2: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        listBullet: const TextStyle(color: AppTheme.accent),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.later, style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
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
