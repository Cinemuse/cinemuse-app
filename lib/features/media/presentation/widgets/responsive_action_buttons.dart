import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/social_actions_group.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:flutter/material.dart';
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
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})? seriesWatchStatus;
  final int? movieWatchCount;
  final double mobileBreakpoint;

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
    this.seriesWatchStatus,
    this.movieWatchCount,
    this.mobileBreakpoint = 600.0,
    this.hasResumeProgress = false,
    this.mediaId = '',
    this.mediaType = 'movie',
    this.season,
    this.episode,
  });

  @override
  ConsumerState<ResponsiveActionButtons> createState() => _ResponsiveActionButtonsState();
}

class _ResponsiveActionButtonsState extends ConsumerState<ResponsiveActionButtons> {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.menuRemoveCachedProvider),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.secondary,
      ),
    );
  }

  /// Whether the dropdown has any options to show
  bool get _hasDropdownOptions => widget.hasResumeProgress || _hasCachedStream;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < widget.mobileBreakpoint;

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
      onDropdownOpened: _refreshCacheState,
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
      if (_hasCachedStream)
        _DropdownItem(
          icon: Icons.cached,
          label: l10n.menuRemoveCachedProvider,
          onTap: () => _clearCache(context),
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

  const _SplitPlayButton({
    required this.onPlayClick,
    required this.label,
    required this.dropdownItems,
    required this.onDropdownOpened,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonDecoration = BoxDecoration(
      color: AppTheme.accent,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: AppTheme.accent.withValues(alpha: 0.4), blurRadius: 25, offset: const Offset(0, 8)),
      ],
    );

    final mainButton = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPlayClick,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow_outlined, color: AppTheme.textWhite, size: 24),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final divider = Container(
      width: 1,
      height: 28,
      color: AppTheme.textWhite.withValues(alpha: 0.3),
    );

    final chevronButton = PopupMenuButton<int>(
      onOpened: onDropdownOpened,
      tooltip: '',
      color: AppTheme.surface,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
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
                color: item.isDestructive ? AppTheme.favorites : AppTheme.textWhite.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  color: item.isDestructive ? AppTheme.favorites : AppTheme.textWhite,
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
          child: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textWhite, size: 22),
        ),
      ),
    );

    final content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        isFullWidth ? Expanded(child: mainButton) : mainButton,
        divider,
        chevronButton,
      ],
    );

    return HoverScale(
      child: Container(
        decoration: buttonDecoration,
        clipBehavior: Clip.antiAlias,
        child: content,
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

  const _PlayButton({
    required this.onPlayClick,
    required this.label,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPlayClick,
        child: HoverScale(
          child: Container(
            width: isFullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: AppTheme.accent.withValues(alpha: 0.4), blurRadius: 25, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_outlined, color: AppTheme.textWhite, size: 24),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Track Button (unchanged from original)
// ---------------------------------------------------------------------------

class _TrackButton extends StatelessWidget {
  final VoidCallback onTrackTap;
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})? seriesWatchStatus;
  final int? movieWatchCount;

  const _TrackButton({
    required this.onTrackTap,
    this.seriesWatchStatus,
    this.movieWatchCount,
  });

  @override
  Widget build(BuildContext context) {
    final isMovie = movieWatchCount != null;
    final isFullyWatched = seriesWatchStatus?.isFullyWatched ?? (isMovie && movieWatchCount! > 0);
    final isPartiallyWatched = seriesWatchStatus?.isPartiallyWatched ?? false;
    final minWatchCount = seriesWatchStatus?.minWatchCount ?? (movieWatchCount ?? 0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTrackTap,
        child: HoverScale(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            decoration: BoxDecoration(
              color: isFullyWatched
                  ? Colors.green.withValues(alpha: 0.15)
                  : AppTheme.textWhite.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFullyWatched
                    ? Colors.green.withValues(alpha: 0.3)
                    : AppTheme.textWhite.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFullyWatched
                      ? Icons.check_circle
                      : (isPartiallyWatched ? Icons.check_circle_outline : Icons.add_task),
                  color: isFullyWatched ? Colors.green : AppTheme.textWhite,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    isFullyWatched
                        ? (isMovie
                            ? (minWatchCount > 1 ? 'Watched x$minWatchCount' : 'Watched')
                            : (minWatchCount > 1 ? 'Up to date x$minWatchCount' : 'Up to date'))
                        : (isPartiallyWatched ? 'Finish Series' : 'Track'),
                    style: TextStyle(
                      color: isFullyWatched ? Colors.green : AppTheme.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
