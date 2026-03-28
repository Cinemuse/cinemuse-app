import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'settings_widgets.dart';

class LiveTvQualityView extends ConsumerWidget {
  final VoidCallback onBack;
  final CinemaPlayerState state;

  const LiveTvQualityView({
    super.key,
    required this.onBack,
    required this.state,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final availableQualities = state.currentChannel?.links.map((l) => l.quality).toSet() ?? {};
    final currentQuality = ref.watch(settingsProvider.select((s) => s.liveTvQuality));

    return Column(
      children: [
        SubViewHeader(
          title: l10n.playerSelectQuality,
          onBack: onBack,
          compact: isLandscape,
        ),
        if (availableQualities.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              l10n.playerNoQualityOptions,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          )
        else
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              children: [
                ...StreamQuality.values.reversed.where((q) => availableQualities.contains(q)).map((q) {
                  return _buildQualityTile(
                    context: context,
                    ref: ref,
                    quality: q,
                    icon: _getQualityIcon(q),
                    current: currentQuality,
                    label: q == StreamQuality.fhd ? 'FULL HD' : null,
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQualityTile({
    required BuildContext context,
    required WidgetRef ref,
    required StreamQuality quality,
    required IconData icon,
    required StreamQuality current,
    String? label,
  }) {
    final isSelected = quality == current;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ref.read(settingsProvider.notifier).updateSettings({'liveTvQuality': quality});
            onBack();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
                width: 1,
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
                    label ?? quality.label,
                    style: TextStyle(
                      color: isSelected ? AppTheme.accent : AppTheme.textWhite.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
          ),
        ),
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
