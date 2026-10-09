import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/streaming/models/provider_search_status.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

/// Overlay widget displayed while scraping/resolving streams from providers.
class ResolvingOverlay extends StatelessWidget {
  final CinemaPlayerState state;
  final String? loadingMessage;
  final VoidCallback onSkipResolution;

  const ResolvingOverlay({
    super.key,
    required this.state,
    this.loadingMessage,
    required this.onSkipResolution,
  });

  bool _canSkipResolution() {
    final hasResults = state.providerStatuses.any(
      (s) => s.status == ProviderStatus.finished && s.resultsCount > 0,
    );
    if (!hasResults) return false;

    final maxElapsedSeconds = state.providerStatuses.isEmpty
        ? 0
        : state.providerStatuses
              .map((s) => s.timeElapsed.inSeconds)
              .reduce((a, b) => a > b ? a : b);
    return maxElapsedSeconds >= 15;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            loadingMessage ?? l10n.playerResolving,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 16),
          ),
          if (state.providerStatuses.isNotEmpty) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...state.providerStatuses.map((s) {
                    final isSearching = s.status == ProviderStatus.searching;
                    final isFailed = s.status == ProviderStatus.failed;

                    Color iconColor = AppTheme.textMuted;
                    IconData iconData = Icons.search;
                    String trailingText =
                        '${(s.timeElapsed.inMilliseconds / 1000).toStringAsFixed(1)}s';

                    if (!isSearching) {
                      if (isFailed) {
                        iconData = Icons.error_outline;
                        iconColor = Theme.of(context).colorScheme.error;
                        trailingText = l10n.playerProviderFailed(trailingText);
                      } else {
                        iconData = Icons.check_circle_outline;
                        iconColor = AppTheme.success;
                        trailingText = l10n.playerProviderResults(
                          s.resultsCount,
                          trailingText,
                        );
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          if (isSearching)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.accent,
                              ),
                            )
                          else
                            Icon(iconData, size: 16, color: iconColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.providerName,
                              style: TextStyle(
                                color: isSearching
                                    ? AppTheme.textWhite
                                    : AppTheme.textSecondary,
                                fontWeight: isSearching
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Text(
                            trailingText,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_canSkipResolution()) ...[
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: onSkipResolution,
                      icon: const Icon(Icons.skip_next, color: AppTheme.accent),
                      label: Text(
                        l10n.playerSkipToPlayback,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          shadows: [
                            Shadow(color: AppTheme.accentGlow, blurRadius: 10),
                          ],
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.secondary.withValues(
                          alpha: 0.6,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppTheme.radius12,
                          side: BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
