import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/media/application/media_details_controller.dart';

class SocialActionsGroup extends ConsumerWidget {
  final MediaItem mediaItem;
  final bool isFavorite;
  final bool isInWatchlist;
  final VoidCallback onListTap;

  final bool isExpanded;

  const SocialActionsGroup({
    super.key,
    required this.mediaItem,
    required this.isFavorite,
    required this.isInWatchlist,
    required this.onListTap,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: AppTheme.radius12,
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _buildIcon(
            _SocialIcon(
              icon: isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite
                  ? AppTheme.favorites
                  : theme.colorScheme.onSurface,
              onTap: () => ref
                  .read(mediaDetailsControllerProvider.notifier)
                  .toggleFavorite(mediaItem),
            ),
          ),
          const _VerticalDivider(),
          _buildIcon(
            _SocialIcon(
              icon: isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
              color: isInWatchlist
                  ? AppTheme.watchlist
                  : theme.colorScheme.onSurface,
              onTap: () => ref
                  .read(mediaDetailsControllerProvider.notifier)
                  .toggleWatchlist(mediaItem),
            ),
          ),
          const _VerticalDivider(),
          _buildIcon(
            _SocialIcon(icon: Icons.format_list_bulleted, onTap: onListTap),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(Widget icon) {
    return isExpanded ? Expanded(child: icon) : icon;
  }
}

class _SocialIcon extends StatefulWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _SocialIcon({required this.icon, this.color, required this.onTap});

  @override
  State<_SocialIcon> createState() => _SocialIconState();
}

class _SocialIconState extends State<_SocialIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool? _isOptimisticActive;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
      ],
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_SocialIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.icon != widget.icon || oldWidget.color != widget.color) {
      _isOptimisticActive = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get isActive =>
      _isOptimisticActive ??
      (widget.color != null && widget.color != AppTheme.textWhite);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Use 600px breakpoint to match mobile layout switching
    final horizontalPadding = screenWidth < 600 ? 12.0 : 18.0;

    IconData effectiveIcon = widget.icon;
    if (_isOptimisticActive != null) {
      if (widget.icon == Icons.favorite ||
          widget.icon == Icons.favorite_border) {
        effectiveIcon = _isOptimisticActive!
            ? Icons.favorite
            : Icons.favorite_border;
      } else if (widget.icon == Icons.bookmark ||
          widget.icon == Icons.bookmark_border) {
        effectiveIcon = _isOptimisticActive!
            ? Icons.bookmark
            : Icons.bookmark_border;
      }
    }

    final theme = Theme.of(context);
    Color effectiveColor = widget.color ?? theme.colorScheme.onSurface;
    if (_isOptimisticActive != null) {
      if (widget.icon == Icons.favorite ||
          widget.icon == Icons.favorite_border) {
        effectiveColor = _isOptimisticActive!
            ? AppTheme.favorites
            : theme.colorScheme.onSurface;
      } else if (widget.icon == Icons.bookmark ||
          widget.icon == Icons.bookmark_border) {
        effectiveColor = _isOptimisticActive!
            ? AppTheme.watchlist
            : theme.colorScheme.onSurface;
      }
    }

    return DpadFocusable(
      autoScroll: false,
      onTap: () {
        if (widget.icon != Icons.format_list_bulleted) {
          setState(() {
            _isOptimisticActive = !isActive;
          });
        }
        _controller.forward(from: 0.0);
        widget.onTap();
      },
      scale: 1.0,
      borderRadius: AppTheme.radiusMd,
      builder: (context, isFocused, isHovered, child) {
        return Container(
          decoration: BoxDecoration(
            color: isFocused
                ? theme.focusColor
                : (isHovered ? theme.hoverColor : Colors.transparent),
            borderRadius: AppTheme.radiusMd,
          ),
          child: child,
        );
      },
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 15,
        ),
        // FittedBox scales down contents if they still exceed the container width
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Icon(
                    effectiveIcon,
                    key: ValueKey(effectiveIcon),
                    color: effectiveColor,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      color: AppTheme.textWhite.withValues(alpha: 0.1),
    );
  }
}
