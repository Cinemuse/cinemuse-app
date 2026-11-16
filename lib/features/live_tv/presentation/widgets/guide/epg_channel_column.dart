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
  final void Function(int index, Channel channel)? onChannelFocus;
  final void Function(Channel channel)? onToggleFavorite;
  final FocusNode Function(int index)? focusNodeBuilder;
  final void Function(int index)? onNavigateRight;

  /// Up from the first channel.
  final VoidCallback? onNavigateUpFromTop;

  /// Page up (-1) or Page down (+1) from the channel at index.
  final void Function(int index, int direction)? onPage;

  const EpgChannelColumn({
    super.key,
    required this.channels,
    this.selectedChannel,
    this.favoriteIds = const {},
    required this.rowHeight,
    required this.columnWidth,
    this.controller,
    this.onChannelTap,
    this.onChannelFocus,
    this.onToggleFavorite,
    this.focusNodeBuilder,
    this.onNavigateRight,
    this.onNavigateUpFromTop,
    this.onPage,
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
              channel: channel,
              isSelected: isSelected,
              isFavorite: isFavorite,
              focusNode: focusNodeBuilder?.call(index),
              onTap: () => onChannelTap?.call(channel),
              onFocusChange: (focused) {
                if (focused) onChannelFocus?.call(index, channel);
              },
              onToggleFavorite: onToggleFavorite != null
                  ? () => onToggleFavorite!(channel)
                  : null,
              onNavigateRight: onNavigateRight != null
                  ? () => onNavigateRight!(index)
                  : null,
              onNavigateUp: index == 0 ? onNavigateUpFromTop : null,
              onPage: onPage != null
                  ? (direction) => onPage!(index, direction)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _ChannelItemTile extends StatelessWidget {
  final Channel channel;
  final bool isSelected;
  final bool isFavorite;
  final FocusNode? focusNode;
  final VoidCallback onTap;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onNavigateRight;
  final VoidCallback? onNavigateUp;
  final ValueChanged<int>? onPage;

  const _ChannelItemTile({
    required this.channel,
    required this.isSelected,
    required this.isFavorite,
    this.focusNode,
    required this.onTap,
    required this.onFocusChange,
    this.onToggleFavorite,
    this.onNavigateRight,
    this.onNavigateUp,
    this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      focusNode: focusNode,
      borderRadius: BorderRadius.zero,
      isFocusRingInside: true,
      onTap: onTap,
      onFocusChange: onFocusChange,
      onLongPress: onToggleFavorite,
      onSecondaryTap: onToggleFavorite,
      onKeyEvent: (node, event) {
        final key = event.logicalKey;
        // Only a press turns a page; its repeats are swallowed.
        if (onPage != null &&
            (key == LogicalKeyboardKey.pageUp ||
                key == LogicalKeyboardKey.pageDown)) {
          if (event is KeyDownEvent) {
            onPage!(key == LogicalKeyboardKey.pageUp ? -1 : 1);
          }
          return KeyEventResult.handled;
        }
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final action = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowRight => onNavigateRight,
          LogicalKeyboardKey.arrowUp => onNavigateUp,
          _ => null,
        };
        if (action == null) return KeyEventResult.ignored;
        action();
        return KeyEventResult.handled;
      },
      builder: (context, isFocused, isHovered, _) {
        final isHighlighted = isFocused || isHovered;

        // No fade: the fill moves with the ring, which never fades.
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            // Fill only: the rows touch, so an outline would pile up.
            color: isSelected
                ? AppTheme.accentSelectedBg
                : (isHighlighted ? AppTheme.accentHoverBg : AppTheme.primary),
            border: Border(
              right: const BorderSide(color: AppTheme.border),
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
                      color: isSelected ? Colors.white : AppTheme.textMuted,
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
                  child: channel.logo.isNotEmpty
                      ? Image.network(
                          channel.logo,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _buildFallbackIcon(),
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
