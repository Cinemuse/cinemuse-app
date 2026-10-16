import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/hero/social_actions_group.dart';
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
  // Looked up on every build (a map lookup), so it never goes stale when
  // the card is reused for another episode or after playing (REV-208).
  bool get _hasCachedStream =>
      widget.mediaId.isNotEmpty &&
      ref
          .read(unifiedStreamResolverProvider)
          .hasCachedStream(
            widget.mediaId,
            widget.mediaType,
            season: widget.season,
            episode: widget.episode,
          );

  void _clearCache(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final resolver = ref.read(unifiedStreamResolverProvider);
    resolver.clearCachedStream(
      widget.mediaId,
      widget.mediaType,
      season: widget.season,
      episode: widget.episode,
    );
    setState(() {});
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
    final isMobile = Breakpoints.isCompact(context);

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
                    isMovie: widget.mediaItem.mediaType == MediaKind.movie,
                    seriesWatchStatus: widget.seriesWatchStatus,
                    movieWatchCount: widget.movieWatchCount,
                  ),
                ),
              ],
              if (widget.onCommentsTap != null) ...[
                const SizedBox(width: 12),
                _CommentsButton(onCommentsTap: widget.onCommentsTap!),
              ],
            ],
          ),
        ],
      );
    }

    // Wraps: just above the phone width the buttons don't fit on one line
    // (REV-301).
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildPlaySection(context),
        SocialActionsGroup(
          mediaItem: widget.mediaItem,
          isFavorite: widget.isFavorite,
          isInWatchlist: widget.isInWatchlist,
          onListTap: widget.onListTap,
          isExpanded: false,
        ),
        if (widget.onTrackTap != null)
          _TrackButton(
            onTrackTap: widget.onTrackTap!,
            isMovie: widget.mediaItem.mediaType == MediaKind.movie,
            seriesWatchStatus: widget.seriesWatchStatus,
            movieWatchCount: widget.movieWatchCount,
          ),
        if (widget.onCommentsTap != null)
          _CommentsButton(onCommentsTap: widget.onCommentsTap!),
      ],
    );
  }

  Widget _buildPlaySection(BuildContext context, {bool isFullWidth = false}) {
    if (!_hasDropdownOptions) {
      return _PlayButton(
        onPlayClick: widget.onPlayClick,
        label: widget.playButtonLabel,
        isFullWidth: isFullWidth,
      );
    }

    return _SplitPlayButton(
      onPlayClick: widget.onPlayClick,
      label: widget.playButtonLabel,
      isFullWidth: isFullWidth,
      onDropdownOpened: () => setState(() {}),
      dropdownItems: _buildDropdownItems(context),
    );
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
        ),
      if (widget.onDropClick != null)
        _DropdownItem(
          icon: Icons.stop_circle_outlined,
          label: l10n.menuStopWatching,
          onTap: widget.onDropClick!,
        ),
    ];
  }
}

class _DropdownItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DropdownItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// Play with a ▾ menu (Restart, Clear progress…) next to it.
class _SplitPlayButton extends StatefulWidget {
  final VoidCallback onPlayClick;
  final String label;
  final bool isFullWidth;
  final List<_DropdownItem> dropdownItems;
  final VoidCallback onDropdownOpened;

  const _SplitPlayButton({
    required this.onPlayClick,
    required this.label,
    required this.dropdownItems,
    required this.onDropdownOpened,
    this.isFullWidth = false,
  });

  @override
  State<_SplitPlayButton> createState() => _SplitPlayButtonState();
}

// One popup key for the button's life: a new key on every build threw the
// menu away and lost focus (REV-219).
class _SplitPlayButtonState extends State<_SplitPlayButton> {
  final _popupKey = GlobalKey<PopupMenuButtonState<int>>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final divider = Container(
      width: 1,
      height: 28,
      color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
    );

    final chevronButton = PopupMenuButton<int>(
      key: _popupKey,
      // Disabled: its own InkWell would be a second focus stop inside the
      // DpadFocusable; the chevron's GestureDetector opens it instead.
      enabled: false,
      onOpened: widget.onDropdownOpened,
      tooltip: '',
      color: theme.colorScheme.surface,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.radius12,
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      offset: const Offset(0, 48),
      itemBuilder: (_) => widget.dropdownItems.map((item) {
        return PopupMenuItem<int>(
          onTap: item.onTap,
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      // The disabled button's InkWell shows the arrow cursor: put the hand back.
      child: Tooltip(
        message: AppLocalizations.of(context)!.menuMoreOptions,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _popupKey.currentState?.showButtonMenu(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: theme.colorScheme.onPrimary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );

    return DpadFocusable(
      autofocus: true,
      autoScroll: false,
      onKeyEvent: _stayOnLeft,
      onTap: widget.onPlayClick,
      onLongPress: () => _popupKey.currentState?.showButtonMenu(),
      scale: 1.06,
      borderRadius: AppTheme.radius12,
      builder: (context, isFocused, isHovered, child) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: AppTheme.radius12,
            boxShadow: isFocused || isHovered
                ? AppTheme.shadowAccentGlow
                : AppTheme.shadowCard,
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      child: Row(
        mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          widget.isFullWidth
              ? Expanded(child: _buildMainPlayContent())
              : _buildMainPlayContent(),
          divider,
          chevronButton,
        ],
      ),
    );
  }

  Widget _buildMainPlayContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
      child: _PlayLabel(label: widget.label, isFullWidth: widget.isFullWidth),
    );
  }
}

/// Play is the first button in its row: Left keeps focus on it instead of
/// letting the arrow jump to an unrelated control.
KeyEventResult _stayOnLeft(FocusNode node, KeyEvent event) =>
    event is! KeyUpEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft
    ? KeyEventResult.handled
    : KeyEventResult.ignored;

/// The ▶ icon and label shared by both Play buttons.
class _PlayLabel extends StatelessWidget {
  final String label;
  final bool isFullWidth;

  const _PlayLabel({required this.label, required this.isFullWidth});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

/// Play alone, when its menu would be empty.
class _PlayButton extends StatelessWidget {
  final VoidCallback onPlayClick;
  final String label;
  final bool isFullWidth;

  const _PlayButton({
    required this.onPlayClick,
    required this.label,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DpadFocusable(
      autofocus: true,
      autoScroll: false,
      onKeyEvent: _stayOnLeft,
      onTap: onPlayClick,
      scale: 1.06,
      borderRadius: AppTheme.radius12,
      builder: (context, isFocused, isHovered, child) {
        return Container(
          width: isFullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: AppTheme.radius12,
            boxShadow: isFocused || isHovered
                ? AppTheme.shadowAccentGlow
                : AppTheme.shadowCard,
          ),
          child: child,
        );
      },
      child: _PlayLabel(label: label, isFullWidth: isFullWidth),
    );
  }
}

class _TrackButton extends StatelessWidget {
  final VoidCallback onTrackTap;
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})?
  seriesWatchStatus;
  final int? movieWatchCount;

  /// From the title's type: a show has no movie count (REV-303).
  final bool isMovie;

  const _TrackButton({
    required this.onTrackTap,
    required this.isMovie,
    this.seriesWatchStatus,
    this.movieWatchCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Not known yet: a spinner, not a wrong "Track" (REV-287).
    final isLoading = isMovie
        ? movieWatchCount == null
        : seriesWatchStatus == null;
    final isFullyWatched =
        seriesWatchStatus?.isFullyWatched ?? (movieWatchCount ?? 0) > 0;
    final isPartiallyWatched = seriesWatchStatus?.isPartiallyWatched ?? false;
    final minWatchCount =
        seriesWatchStatus?.minWatchCount ?? (movieWatchCount ?? 0);

    final isMobile = Breakpoints.isCompact(context);
    final horizontalPadding = isMobile ? 12.0 : 24.0;

    return DpadFocusable(
      autoScroll: false,
      onTap: isLoading ? null : onTrackTap,
      scale: 1.0,
      borderRadius: AppTheme.radius12,
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
                ? (isFocused || isHovered
                      ? AppTheme.success.withValues(alpha: 0.3)
                      : AppTheme.success.withValues(alpha: 0.15))
                : (isFocused || isHovered
                      ? Color.alphaBlend(theme.focusColor, baseColor)
                      : baseColor),
            borderRadius: AppTheme.radius12,
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
          if (isLoading)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
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
            // Hidden, not removed: the button keeps its size while loading.
            child: Visibility(
              visible: !isLoading,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
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
          ),
        ],
      ),
    );
  }
}

class _CommentsButton extends StatelessWidget {
  final VoidCallback onCommentsTap;

  const _CommentsButton({required this.onCommentsTap});

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
        borderRadius: AppTheme.radius12,
        builder: (context, isFocused, isHovered, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: isFocused || isHovered
                  ? Color.alphaBlend(theme.focusColor, baseColor)
                  : baseColor,
              borderRadius: AppTheme.radius12,
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
