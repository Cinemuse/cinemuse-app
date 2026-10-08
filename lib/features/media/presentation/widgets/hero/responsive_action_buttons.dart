import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/social_actions_group.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResponsiveActionButtons extends ConsumerStatefulWidget {
  final VoidCallback onPlayClick;
  final VoidCallback? onRestartClick;
  final String playButtonLabel;
  final MediaItem mediaItem;
  final bool isFavorite;
  final bool isInWatchlist;
  final VoidCallback onListTap;
  final VoidCallback? onTrackTap;
  final VoidCallback? onCommentsTap;
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})?
  seriesWatchStatus;
  final int? movieWatchCount;
  final double mobileBreakpoint;
  final VoidCallback? onDropClick;
  final VoidCallback? onClearProgress;

  // Cache-check fields
  final bool hasResumeProgress;
  final String mediaId;
  final String mediaType;
  final int? season;
  final int? episode;

  const ResponsiveActionButtons({
    super.key,
    required this.onPlayClick,
    this.onRestartClick,
    required this.playButtonLabel,
    required this.mediaItem,
    required this.isFavorite,
    required this.isInWatchlist,
    required this.onListTap,
    this.onTrackTap,
    this.onCommentsTap,
    this.seriesWatchStatus,
    this.movieWatchCount,
    this.mobileBreakpoint = 600.0,
    this.onDropClick,
    this.onClearProgress,
    this.hasResumeProgress = false,
    this.mediaId = '',
    this.mediaType = 'movie',
    this.season,
    this.episode,
  });

  @override
  ConsumerState<ResponsiveActionButtons> createState() =>
      _ResponsiveActionButtonsState();
}

class _ResponsiveActionButtonsState
    extends ConsumerState<ResponsiveActionButtons> {
  bool _hasCachedStream = false;

  @override
  void initState() {
    super.initState();
    _refreshCacheState();
  }

  void _refreshCacheState() {
    if (widget.mediaId.isEmpty) return;
    final resolver = ref.read(unifiedStreamResolverProvider);
    final hasCache = resolver.hasCachedStream(
      widget.mediaId,
      widget.mediaType,
      season: widget.season,
      episode: widget.episode,
    );
    if (hasCache != _hasCachedStream) {
      setState(() => _hasCachedStream = hasCache);
    }
  }

  void _clearCache(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final resolver = ref.read(unifiedStreamResolverProvider);
    resolver.clearCachedStream(
      widget.mediaId,
      widget.mediaType,
      season: widget.season,
      episode: widget.episode,
    );
    setState(() => _hasCachedStream = false);
    AppSnackBar.show(context, message: l10n.menuRemoveCachedProvider);
  }

  /// Whether the dropdown has any options to show
  bool get _hasDropdownOptions =>
      widget.hasResumeProgress ||
      _hasCachedStream ||
      widget.onDropClick != null ||
      widget.onClearProgress != null;

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < widget.mobileBreakpoint;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPlaySection(context, isFullWidth: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SocialActionsGroup(
                  mediaItem: widget.mediaItem,
                  isFavorite: widget.isFavorite,
                  isInWatchlist: widget.isInWatchlist,
                  onListTap: widget.onListTap,
                  isExpanded: true,
                ),
              ),
              if (widget.onTrackTap != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _TrackButton(
                    onTrackTap: widget.onTrackTap!,
                    seriesWatchStatus: widget.seriesWatchStatus,
                    movieWatchCount: widget.movieWatchCount,
                  ),
                ),
              ],
              if (widget.onCommentsTap != null) ...[
                const SizedBox(width: 12),
                _CommentsButton(
                  onCommentsTap: widget.onCommentsTap!,
                ),
              ],
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        _buildPlaySection(context),
        const SizedBox(width: 16),
        SocialActionsGroup(
          mediaItem: widget.mediaItem,
          isFavorite: widget.isFavorite,
          isInWatchlist: widget.isInWatchlist,
          onListTap: widget.onListTap,
          isExpanded: false,
        ),
        if (widget.onTrackTap != null) ...[
          const SizedBox(width: 16),
          _TrackButton(
            onTrackTap: widget.onTrackTap!,
            seriesWatchStatus: widget.seriesWatchStatus,
            movieWatchCount: widget.movieWatchCount,
          ),
        ],
        if (widget.onCommentsTap != null) ...[
          const SizedBox(width: 16),
          _CommentsButton(
            onCommentsTap: widget.onCommentsTap!,
          ),
        ],
      ],
    );
  }

  Widget _buildPlaySection(BuildContext context, {bool isFullWidth = false}) {
    if (!_hasDropdownOptions) {
      return _PlayButton(
        onPlayClick: widget.onPlayClick,
        label: widget.playButtonLabel,
        isFullWidth: isFullWidth,
        onExitLeft: _handleExitLeft,
      );
    }

    return _SplitPlayButton(
      onPlayClick: widget.onPlayClick,
      label: widget.playButtonLabel,
      isFullWidth: isFullWidth,
      onDropdownOpened: _refreshCacheState,
      dropdownItems: _buildDropdownItems(context),
      onExitLeft: _handleExitLeft,
    );
  }

  void _handleExitLeft() {
    final isWidescreen = ref.read(isBigPictureProvider);
    if (isWidescreen) {
      final focusRail = ref.read(tvRailFocusActionProvider);
      focusRail?.call();
    }
  }

  List<_DropdownItem> _buildDropdownItems(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      if (widget.hasResumeProgress && widget.onRestartClick != null)
        _DropdownItem(
          icon: Icons.replay,
          label: l10n.menuRestart,
          onTap: widget.onRestartClick!,
        ),
      if (widget.hasResumeProgress && widget.onClearProgress != null)
        _DropdownItem(
          icon: Icons.history_toggle_off_outlined,
          label: l10n.menuClearProgress,
          onTap: widget.onClearProgress!,
        ),
      if (_hasCachedStream)
        _DropdownItem(
          icon: Icons.cached,
          label: l10n.menuRemoveCachedProvider,
          onTap: () => _clearCache(context),
          isDestructive: false,
        ),
      if (widget.onDropClick != null)
        _DropdownItem(
          icon: Icons.stop_circle_outlined,
          label: l10n.menuStopWatching,
          onTap: widget.onDropClick!,
          isDestructive: false,
        ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Internal data model for dropdown items
// ---------------------------------------------------------------------------

class _DropdownItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DropdownItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}

// ---------------------------------------------------------------------------
// Split Play Button — main action + chevron dropdown
// ---------------------------------------------------------------------------

class _SplitPlayButton extends StatelessWidget {
  final VoidCallback onPlayClick;
  final String label;
  final bool isFullWidth;
  final List<_DropdownItem> dropdownItems;
  final VoidCallback onDropdownOpened;
  final VoidCallback? onExitLeft;

  const _SplitPlayButton({
    required this.onPlayClick,
    required this.label,
    required this.dropdownItems,
    required this.onDropdownOpened,
    this.onExitLeft,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final popupKey = GlobalKey<PopupMenuButtonState<int>>();

    final divider = Container(
      width: 1,
      height: 28,
      color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
    );

    final chevronButton = PopupMenuButton<int>(
      key: popupKey,
      onOpened: onDropdownOpened,
      tooltip: '',
      color: theme.colorScheme.surface,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      offset: const Offset(0, 48),
      itemBuilder: (_) => dropdownItems.asMap().entries.map((entry) {
        final item = entry.value;
        return PopupMenuItem<int>(
          value: entry.key,
          onTap: item.onTap,
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 18,
                color: item.isDestructive
                    ? AppTheme.favorites
                    : theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  color: item.isDestructive
                      ? AppTheme.favorites
                      : theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Icon(
            Icons.keyboard_arrow_down,
            color: theme.colorScheme.onPrimary,
            size: 22,
          ),
        ),
      ),
    );

    return DpadFocusable(
      autofocus: true,
      autoScroll: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            onExitLeft?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      onTap: onPlayClick,
      onLongPress: () {
        onDropdownOpened();
        popupKey.currentState?.showButtonMenu();
      },
      scale: 1.06,
      borderRadius: BorderRadius.circular(12),
      builder: (context, isFocused, isHovered, child) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isFocused
                ? const [
                    BoxShadow(
                      color: Color(0x99000000), // black 60%
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: Offset(0, 6),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x40000000), // black 25%
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      child: Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          isFullWidth
              ? Expanded(child: _buildMainPlayContent())
              : _buildMainPlayContent(),
          divider,
          chevronButton,
        ],
      ),
    );
  }

  Widget _buildMainPlayContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const Icon(
            Icons.play_arrow_outlined,
            color: AppTheme.textWhite,
            size: 24,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plain Play Button (no dropdown)
// ---------------------------------------------------------------------------

class _PlayButton extends StatelessWidget {
  final VoidCallback onPlayClick;
  final String label;
  final bool isFullWidth;
  final VoidCallback? onExitLeft;

  const _PlayButton({
    required this.onPlayClick,
    required this.label,
    this.onExitLeft,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DpadFocusable(
      autofocus: true,
      autoScroll: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            onExitLeft?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      onTap: onPlayClick,
      scale: 1.06,
      borderRadius: BorderRadius.circular(12),
      builder: (context, isFocused, isHovered, child) {
        return Container(
          width: isFullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isFocused
                ? const [
                    BoxShadow(
                      color: Color(0x99000000), // black 60%
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: Offset(0, 6),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x40000000), // black 25%
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const Icon(
            Icons.play_arrow_outlined,
            color: AppTheme.textWhite,
            size: 24,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Track Button
// ---------------------------------------------------------------------------

class _TrackButton extends StatelessWidget {
  final VoidCallback onTrackTap;
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})?
  seriesWatchStatus;
  final int? movieWatchCount;

  const _TrackButton({
    required this.onTrackTap,
    this.seriesWatchStatus,
    this.movieWatchCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMovie = movieWatchCount != null;
    final isFullyWatched =
        seriesWatchStatus?.isFullyWatched ?? (isMovie && movieWatchCount! > 0);
    final isPartiallyWatched = seriesWatchStatus?.isPartiallyWatched ?? false;
    final minWatchCount =
        seriesWatchStatus?.minWatchCount ?? (movieWatchCount ?? 0);

    final isMobile = MediaQuery.of(context).size.width < 600;
    final horizontalPadding = isMobile ? 12.0 : 24.0;

    return DpadFocusable(
      autoScroll: false,
      onTap: onTrackTap,
      scale: 1.0,
      borderRadius: BorderRadius.circular(12),
      builder: (context, isFocused, isHovered, child) {
        final theme = Theme.of(context);
        final baseColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            color: isFullyWatched
                ? (isFocused
                    ? AppTheme.success.withValues(alpha: 0.3)
                    : AppTheme.success.withValues(alpha: 0.15))
                : (isFocused
                    ? Color.alphaBlend(theme.focusColor, baseColor)
                    : (isHovered
                        ? Color.alphaBlend(theme.hoverColor, baseColor)
                        : baseColor)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFullyWatched
                  ? AppTheme.success.withValues(alpha: 0.3)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.05),
              width: 1.0,
            ),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFullyWatched
                ? Icons.check_circle
                : (isPartiallyWatched
                    ? Icons.check_circle_outline
                    : Icons.add_task),
            color: isFullyWatched ? AppTheme.success : AppTheme.textWhite,
            size: 24,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              isFullyWatched
                  ? (isMovie
                      ? (minWatchCount > 1
                          ? l10n.detailsWatchedCount(minWatchCount)
                          : l10n.detailsWatched)
                      : (minWatchCount > 1
                          ? l10n.detailsUpToDateCount(minWatchCount)
                          : l10n.detailsUpToDate))
                  : (isPartiallyWatched
                      ? l10n.detailsFinishSeries
                      : l10n.detailsTrack),
              style: TextStyle(
                color: isFullyWatched ? AppTheme.success : AppTheme.textWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comments Button
// ---------------------------------------------------------------------------

class _CommentsButton extends StatelessWidget {
  final VoidCallback onCommentsTap;

  const _CommentsButton({
    required this.onCommentsTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final baseColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Tooltip(
      message: l10n.detailsTvTimeComments,
      child: DpadFocusable(
        autoScroll: false,
        onTap: onCommentsTap,
        scale: 1.0,
        borderRadius: BorderRadius.circular(12),
        builder: (context, isFocused, isHovered, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: isFocused
                  ? Color.alphaBlend(theme.focusColor, baseColor)
                  : (isHovered
                      ? Color.alphaBlend(theme.hoverColor, baseColor)
                      : baseColor),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                width: 1.0,
              ),
            ),
            child: child,
          );
        },
        child: Icon(
          Icons.chat_bubble_outline,
          color: theme.colorScheme.onSurface,
          size: 24,
        ),
      ),
    );
  }
}
