import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';

/// A single channel row in the channel list panel.
class ChannelListTile extends StatelessWidget {
  final Channel channel;
  final bool isSelected;
  final bool isFavorite;
  final EpgProgram? currentProgram;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;

  const ChannelListTile({
    super.key,
    required this.channel,
    required this.isSelected,
    this.isFavorite = false,
    this.currentProgram,
    required this.onTap,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: _handleLongPress,
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppTheme.accent.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accent.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                _buildLcnNumber(),
                _buildChannelLogo(),
                const SizedBox(width: 10),
                _buildChannelInfo(),
                _buildTrailingIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLongPress() {
    if (onFavoriteToggle == null) return;
    HapticFeedback.mediumImpact();
    onFavoriteToggle!();
  }

  Widget _buildLcnNumber() {
    return SizedBox(
      width: 32,
      child: Text(
        channel.lcn.toString(),
        style: TextStyle(
          color: isSelected ? AppTheme.accent : AppTheme.textMuted,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildChannelLogo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 36,
        height: 36,
        color: Colors.white.withValues(alpha: 0.05),
        child: Image.network(
          channel.logo,
          fit: BoxFit.contain,
          cacheWidth: 80,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              channel.name.isNotEmpty ? channel.name.substring(0, 1) : '?',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (isFavorite) ...[
                const Icon(Icons.star, size: 12, color: AppTheme.accent),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  channel.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (channel.quality != StreamQuality.sd) ...[
                const SizedBox(width: 6),
                _buildQualityBadge(),
              ],
            ],
          ),
          if (currentProgram != null) ...[
            const SizedBox(height: 2),
            Text(
              currentProgram!.name,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityBadge() {
    final color = channel.quality == StreamQuality.uhd
        ? Colors.amber
        : AppTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        channel.quality.label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTrailingIndicator() {
    if (!isSelected) return const SizedBox.shrink();
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}
