import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// Left sticky column displaying channel items in the EPG TV Guide.
class EpgChannelColumn extends StatelessWidget {
  final List<Channel> channels;
  final Channel? selectedChannel;
  final Set<String> favoriteIds;
  final double rowHeight;
  final double columnWidth;
  final ScrollController? controller;
  final void Function(Channel channel)? onChannelTap;
  final void Function(Channel channel)? onChannelFocus;
  final void Function(Channel channel)? onToggleFavorite;
  final FocusNode Function(int index)? focusNodeBuilder;
  final void Function(int index)? onNavigateRight;

  const EpgChannelColumn({
    super.key,
    required this.channels,
    this.selectedChannel,
    this.favoriteIds = const {},
    this.rowHeight = 68.0,
    this.columnWidth = 210.0,
    this.controller,
    this.onChannelTap,
    this.onChannelFocus,
    this.onToggleFavorite,
    this.focusNodeBuilder,
    this.onNavigateRight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: columnWidth,
      child: ListView.builder(
        controller: controller,
        physics: const ClampingScrollPhysics(),
        itemExtent: rowHeight,
        cacheExtent: rowHeight * 6,
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          final isSelected = selectedChannel?.uniqueId == channel.uniqueId;
          final isFavorite = favoriteIds.contains(channel.uniqueId);

          return RepaintBoundary(
            child: _ChannelItemTile(
              index: index,
              channel: channel,
              isSelected: isSelected,
              isFavorite: isFavorite,
              focusNode: focusNodeBuilder?.call(index),
              onTap: () => onChannelTap?.call(channel),
              onFocusChange: (focused) {
                if (focused) onChannelFocus?.call(channel);
              },
              onToggleFavorite: onToggleFavorite != null
                  ? () => onToggleFavorite!(channel)
                  : null,
              onNavigateRight: onNavigateRight != null
                  ? () => onNavigateRight!(index)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _ChannelItemTile extends StatelessWidget {
  final int index;
  final Channel channel;
  final bool isSelected;
  final bool isFavorite;
  final FocusNode? focusNode;
  final VoidCallback onTap;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onNavigateRight;

  const _ChannelItemTile({
    required this.index,
    required this.channel,
    required this.isSelected,
    required this.isFavorite,
    this.focusNode,
    required this.onTap,
    required this.onFocusChange,
    this.onToggleFavorite,
    this.onNavigateRight,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      focusNode: focusNode,
      onTap: onTap,
      onFocusChange: onFocusChange,
      onLongPress: onToggleFavorite,
      onSecondaryTap: onToggleFavorite,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (onNavigateRight != null) {
            onNavigateRight!();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      builder: (context, isFocused, isHovered, _) {
        final isHighlighted = isFocused || isHovered;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isFocused
                ? Colors.white.withValues(alpha: 0.16)
                : (isHovered
                      ? Colors.white.withValues(alpha: 0.08)
                      : (isSelected
                            ? AppTheme.accent.withValues(alpha: 0.12)
                            : const Color(0xFF0F081C))),
            border: Border(
              right: BorderSide(
                color: isFocused ? AppTheme.accent : AppTheme.border,
                width: isFocused ? 2.0 : 1.0,
              ),
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // LCN Number badge
              if (channel.lcn > 0) ...[
                Container(
                  width: 30,
                  alignment: Alignment.center,
                  child: Text(
                    '${channel.lcn}',
                    style: TextStyle(
                      color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Channel Logo or fallback avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 36,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.06),
                  alignment: Alignment.center,
                  child: channel.logoUrl.isNotEmpty
                      ? Image.network(
                          channel.logoUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _buildFallbackIcon(),
                        )
                      : _buildFallbackIcon(),
                ),
              ),
              const SizedBox(width: 10),

              // Channel Name
              Expanded(
                child: Text(
                  channel.name,
                  style: TextStyle(
                    color: isHighlighted || isSelected
                        ? Colors.white
                        : AppTheme.textWhite.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Favorite indicator
              if (isFavorite) ...[
                const SizedBox(width: 4),
                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              ],
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildFallbackIcon() {
    final initial = channel.name.isNotEmpty
        ? channel.name[0].toUpperCase()
        : 'TV';
    return Text(
      initial,
      style: const TextStyle(
        color: AppTheme.accent,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
