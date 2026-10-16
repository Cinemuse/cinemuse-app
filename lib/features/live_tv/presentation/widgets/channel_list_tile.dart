import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// A single channel row in the channel list panel.
class ChannelListTile extends StatelessWidget {
  final Channel channel;
  final bool isSelected;
  final bool isFavorite;
  final EpgProgram? currentProgram;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;
  final FocusNode? focusNode;
  final bool autofocus;
  final FocusOnKeyEventCallback? onKeyEvent;

  const ChannelListTile({
    super.key,
    required this.channel,
    required this.isSelected,
    this.isFavorite = false,
    this.currentProgram,
    required this.onTap,
    this.onFavoriteToggle,
    this.focusNode,
    this.autofocus = false,
    this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DpadFocusable(
        focusNode: focusNode,
        autofocus: autofocus,
        onTap: onTap,
        onLongPress: onFavoriteToggle != null ? _handleLongPress : null,
        onSecondaryTap: onFavoriteToggle != null ? _handleLongPress : null,
        onKeyEvent: onKeyEvent,
        borderRadius: BorderRadius.circular(10),
        builder: (context, isFocused, isHovered, _) {
          final isHighlighted = isFocused || isHovered;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? Colors.white.withValues(alpha: 0.18)
                  : (isSelected
                        ? AppTheme.accent.withValues(alpha: 0.12)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppTheme.border : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                _buildLcnNumber(isHighlighted),
                _buildChannelLogo(),
                const SizedBox(width: 10),
                _buildChannelInfo(isHighlighted),
                _buildTrailingIndicator(),
              ],
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }

  void _handleLongPress() {
    if (onFavoriteToggle == null) return;
    HapticFeedback.mediumImpact();
    onFavoriteToggle!();
  }

  Widget _buildLcnNumber(bool isHighlighted) {
    return SizedBox(
      width: 36,
      child: Text(
        channel.lcn.toString(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: (isSelected || isHighlighted)
              ? Colors.white
              : AppTheme.textMuted,
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
          cacheWidth: 72,
          cacheHeight: 72,
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

  Widget _buildChannelInfo(bool isHighlighted) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (isFavorite) ...[
                const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  channel.name,
                  style: TextStyle(
                    color: (isSelected || isHighlighted)
                        ? Colors.white
                        : AppTheme.textSecondary,
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
              style: TextStyle(
                color: isHighlighted
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.textMuted,
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
    final isUhd = channel.quality == StreamQuality.uhd;
    final color = isUhd ? Colors.amber : Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: isUhd
            ? Colors.amber.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.08),
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
      width: 7,
      height: 7,
      margin: const EdgeInsets.only(left: 8),
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 4)],
      ),
    );
  }
}
