import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'settings_widgets.dart';

class LiveTvQualityView extends ConsumerWidget {
  final VoidCallback onBack;
  final CinemaPlayerState state;
  final PlayerParams params;

  const LiveTvQualityView({
    super.key,
    required this.onBack,
    required this.state,
    required this.params,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final links = state.currentChannel?.links ?? [];
    final currentQuality = ref.watch(
      settingsProvider.select((s) => s.liveTvQuality),
    );

    return Column(
      children: [
        SubViewHeader(
          title: l10n.playerSelectQuality,
          onBack: onBack,
          compact: isLandscape,
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            children: [
              if (links.isNotEmpty) ...[
                _buildSectionHeader(l10n.playerLiveSources),
                const SizedBox(height: 8),
                ...links.asMap().entries.map((entry) {
                  final index = entry.key;
                  final link = entry.value;
                  final isActive = state.currentLiveLink?.url == link.url;
                  final hasActive = links.any(
                    (l) => state.currentLiveLink?.url == l.url,
                  );
                  return _buildStreamSourceCard(
                    ref: ref,
                    link: link,
                    isActive: isActive,
                    l10n: l10n,
                    autofocus: isActive || (!hasActive && index == 0),
                  );
                }),
                const SizedBox(height: 16),
              ],
              _buildSectionHeader(l10n.playerPreferredQuality),
              const SizedBox(height: 8),
              ...StreamQuality.values.reversed.map((q) {
                return _buildQualityTile(
                  ref: ref,
                  quality: q,
                  icon: _getQualityIcon(q),
                  current: currentQuality,
                  // The first one used to win and focused 4K (REV-171).
                  autofocus: links.isEmpty && q == currentQuality,
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppTheme.textMuted.withValues(alpha: 0.8),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildStreamSourceCard({
    required WidgetRef ref,
    required StreamLink link,
    required bool isActive,
    required AppLocalizations l10n,
    bool autofocus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: DpadFocusable(
        autofocus: autofocus,
        scale: 1.02,
        borderRadius: AppTheme.radius12,
        onTap: () {
          ref
              .read(playerControllerProvider(params).notifier)
              .switchLiveSource(link);
          onBack();
        },
        builder: (context, isFocused, isHovered, child) {
          final isHighlighted = isFocused || isHovered;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.accent.withValues(alpha: 0.12)
                  : (isHighlighted
                        ? AppTheme.textWhite.withValues(alpha: 0.08)
                        : AppTheme.textWhite.withValues(alpha: 0.04)),
              borderRadius: AppTheme.radius12,
              border: Border.all(
                color: isActive
                    ? AppTheme.accent.withValues(alpha: 0.5)
                    : (isHighlighted
                          ? AppTheme.textWhite.withValues(alpha: 0.2)
                          : AppTheme.textWhite.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                _buildQualityBadge(link.quality),
                const SizedBox(width: 8),
                _buildFormatBadge(link.formatLabel),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    link.displayProvider,
                    style: TextStyle(
                      color: isActive
                          ? AppTheme.accent
                          : AppTheme.textWhite.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (isActive)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.accent,
                    size: 20,
                  ),
              ],
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildQualityBadge(StreamQuality quality) {
    final color = switch (quality) {
      StreamQuality.uhd => AppTheme.badgeFlag,
      StreamQuality.fhd => AppTheme.badgeResolution,
      StreamQuality.hd => AppTheme.badgeSize,
      StreamQuality.sd => AppTheme.textMuted,
    };
    return SettingsBadge(text: quality.label, color: color);
  }

  Widget _buildFormatBadge(String format) {
    return SettingsBadge(text: format, color: AppTheme.badgeAudio);
  }

  Widget _buildQualityTile({
    required WidgetRef ref,
    required StreamQuality quality,
    required IconData icon,
    required StreamQuality current,
    bool autofocus = false,
  }) {
    final isSelected = quality == current;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: DpadFocusable(
        autofocus: autofocus,
        scale: 1.02,
        borderRadius: AppTheme.radius12,
        onTap: () {
          ref.read(settingsProvider.notifier).updateSettings({
            'liveTvQuality': quality,
          });
          onBack();
        },
        builder: (context, isFocused, isHovered, child) {
          final isHighlighted = isFocused || isHovered;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accent.withValues(alpha: 0.1)
                  : (isHighlighted
                        ? AppTheme.textWhite.withValues(alpha: 0.08)
                        : AppTheme.textWhite.withValues(alpha: 0.04)),
              borderRadius: AppTheme.radius12,
              border: Border.all(
                color: isSelected
                    ? AppTheme.accent.withValues(alpha: 0.4)
                    : (isHighlighted
                          ? AppTheme.textWhite.withValues(alpha: 0.2)
                          : AppTheme.textWhite.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    quality.label,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.accent
                          : AppTheme.textWhite.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.accent,
                    size: 20,
                  ),
              ],
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }

  IconData _getQualityIcon(StreamQuality quality) {
    switch (quality) {
      case StreamQuality.uhd:
        return Icons.four_k_rounded;
      case StreamQuality.fhd:
        return Icons.hd_rounded;
      case StreamQuality.hd:
        return Icons.hd_outlined;
      case StreamQuality.sd:
        return Icons.sd_rounded;
    }
  }
}
