import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_menu.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

class EpisodeListCard extends ConsumerStatefulWidget {
  final EpisodeItem episode;
  final int seasonNumber;

  /// TMDB ID string used for cache key lookup.
  final String mediaId;
  final bool isWatched;
  final int watchCount;
  final double? resumePercentage;
  final void Function(int season, int episode, String name, {bool restart})? onEpisodeTap;
  final Function(int, int, DateTime?)? onMarkWatched;
  final Function(int, int) onTrackOptions;
  final List<({int season, int episode})> Function(int, int)
  onFindMissingPreceding;
  final Function(int, int, List<({int season, int episode})>)
  onShowMarkPrecedingModal;
  final VoidCallback? onShowComments;
  final VoidCallback? onViewHistory;

  const EpisodeListCard({
    super.key,
    required this.episode,
    required this.seasonNumber,
    required this.mediaId,
    required this.isWatched,
    required this.watchCount,
    this.resumePercentage,
    this.onEpisodeTap,
    this.onMarkWatched,
    required this.onTrackOptions,
    required this.onFindMissingPreceding,
    required this.onShowMarkPrecedingModal,
    this.onShowComments,
    this.onViewHistory,
  });

  @override
  ConsumerState<EpisodeListCard> createState() => _EpisodeListCardState();
}

class _EpisodeListCardState extends ConsumerState<EpisodeListCard> {
  bool _isExpanded = false;
  bool _hasCachedStream = false;
  Offset? _tapPosition;

  int get _epNumber => widget.episode.episodeNumber;

  @override
  void initState() {
    super.initState();
    _refreshCacheState();
  }

  void _refreshCacheState() {
    final resolver = ref.read(unifiedStreamResolverProvider);
    final hasCache = resolver.hasCachedStream(
      widget.mediaId,
      'tv',
      season: widget.seasonNumber,
      episode: _epNumber,
    );
    if (hasCache != _hasCachedStream) {
      setState(() => _hasCachedStream = hasCache);
    }
  }

  void _clearCache() {
    final l10n = AppLocalizations.of(context)!;
    final resolver = ref.read(unifiedStreamResolverProvider);
    resolver.clearCachedStream(
      widget.mediaId,
      'tv',
      season: widget.seasonNumber,
      episode: _epNumber,
    );
    setState(() => _hasCachedStream = false);
    AppSnackBar.show(
      context,
      message: l10n.menuRemoveCachedProvider,
      duration: const Duration(seconds: 2),
      backgroundColor: AppTheme.secondary,
    );
  }

  void _showContextMenu(BuildContext context, {BuildContext? anchorContext}) {
    final l10n = AppLocalizations.of(context)!;
    final fallbackName = l10n.detailsEpisodeFallback(_epNumber);
    final epName = widget.episode.getTitle(fallbackName);

    _refreshCacheState();

    final options = EpisodeMenu.buildEpisodeMenuOptions(
      context: context,
      l10n: l10n,
      mediaId: widget.mediaId,
      seasonNumber: widget.seasonNumber,
      episodeNumber: _epNumber,
      episodeName: epName,
      isWatched: widget.isWatched,
      resumePercentage: widget.resumePercentage,
      hasCachedStream: _hasCachedStream,
      onClearCache: _clearCache,
      onEpisodeTap: widget.onEpisodeTap,
      onMarkWatched: widget.onMarkWatched,
      onTrackOptions: widget.onTrackOptions,
      onViewHistory: widget.onViewHistory,
      onFindMissingPreceding: widget.onFindMissingPreceding,
      onShowMarkPrecedingModal: widget.onShowMarkPrecedingModal,
      onShowComments: widget.onShowComments,
    );

    AppMenu.show(
      context: context,
      options: options,
      title: l10n.detailsEpisodeWithSeason(widget.seasonNumber, _epNumber, epName),
      anchorContext: anchorContext,
      position: _tapPosition,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fallbackName = l10n.detailsEpisodeFallback(_epNumber);
    final name = widget.episode.getTitle(fallbackName);
    final overview = widget.episode.overview ?? '';
    final stillPath = widget.episode.stillPath;
    final runtime = widget.episode.runtime;
    final airDate = widget.episode.airDate;
    final formattedAirDate = airDate != null
        ? DateFormat.yMMMd(
            Localizations.localeOf(context).languageCode,
          ).format(airDate)
        : null;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return DpadFocusable(
      onTap: () =>
          widget.onEpisodeTap?.call(widget.seasonNumber, _epNumber, name),
      onLongPress: () => _showContextMenu(context),
      onSecondaryTap: () => _showContextMenu(context),
      scale: 1.01,
      borderRadius: BorderRadius.circular(16),
      builder: (context, isFocused, isHovered, child) {
        final theme = Theme.of(context);
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isFocused
                    ? theme.focusColor
                    : (isHovered
                        ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.7)
                        : theme.colorScheme.surfaceContainer.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
            Positioned.fill(
              child: CardFocusBorder(
                isFocused: isFocused,
                isHovered: isHovered,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEpisodeStill(
                        context,
                        l10n,
                        stillPath,
                        runtime,
                        160,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildEpisodeHeader(name, formattedAirDate),
                            const SizedBox(height: 8),
                            _buildActions(context, l10n, isMobile: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildExpandableOverview(context, l10n, overview),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEpisodeStill(
                    context,
                    l10n,
                    stillPath,
                    runtime,
                    160,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEpisodeHeader(name, formattedAirDate),
                        const SizedBox(height: 4),
                        _buildExpandableOverview(context, l10n, overview),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildActions(context, l10n, isMobile: false),
                ],
              ),
      ),
    );
  }

  Widget _buildEpisodeStill(
    BuildContext context,
    AppLocalizations l10n,
    String? stillPath,
    dynamic runtime,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: stillPath != null
                  ? CachedNetworkImage(
                      imageUrl: TmdbImageHelper.stillUrl(context, stillPath) ?? '',
                      memCacheWidth: 400,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AppTheme.secondary),
                      errorWidget: (context, url, error) => Container(
                        color: AppTheme.secondary,
                        child: const Center(
                          child: Icon(
                            Icons.tv,
                            color: AppTheme.textMuted,
                            size: 32,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: AppTheme.secondary,
                      child: const Center(
                        child: Icon(
                          Icons.tv,
                          color: AppTheme.textMuted,
                          size: 32,
                        ),
                      ),
                    ),
            ),
          ),

          // Play Overlay
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: AppTheme.textWhite,
                  size: 24,
                ),
              ),
            ),
          ),

          // Cache indicator dot
          if (_hasCachedStream)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),

          // Episode Number badge
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOverlay,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppTheme.textWhite.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                l10n.detailsEpisodeNumber(_epNumber),
                style: AppTheme.monoStyle(
                  color: AppTheme.textWhite,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Runtime badge
          if (runtime != null)
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOverlay,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: AppTheme.textWhite,
                      size: 9,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${runtime}m',
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Progress Bar
          if (!widget.isWatched &&
              widget.resumePercentage != null &&
              widget.resumePercentage! > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppTheme.textWhite.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: widget.resumePercentage!.clamp(0.0, 1.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEpisodeHeader(String name, String? formattedAirDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: DesktopTypography.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (formattedAirDate != null) ...[
          const SizedBox(height: 4),
          Text(
            formattedAirDate,
            style: TextStyle(
              color: AppTheme.textMuted.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExpandableOverview(
    BuildContext context,
    AppLocalizations l10n,
    String overview,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(
          text: overview,
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
            height: 1.4,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 2,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = textPainter.didExceedMaxLines;

        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overview,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
                maxLines: _isExpanded ? null : 2,
                overflow: _isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
              if (isOverflowing)
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _isExpanded ? l10n.detailsShowLess : l10n.detailsReadMore,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActions(
    BuildContext context,
    AppLocalizations l10n, {
    required bool isMobile,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: isMobile ? 0 : 4),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          // More options (right-click hint) button
          Tooltip(
            message: l10n.menuMoreOptions,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Builder(
                builder: (buttonContext) {
                  return GestureDetector(
                    onTap: () {
                      _tapPosition = null;
                      _showContextMenu(context, anchorContext: buttonContext);
                    },
                    child: HoverScale(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.textWhite.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.textWhite.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Icon(
                          Icons.more_vert,
                          color: AppTheme.textWhite.withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Comments Button
          if (widget.onShowComments != null)
            Tooltip(
              message: l10n.detailsTvTimeComments,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onShowComments,
                  child: HoverScale(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.textWhite.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.textWhite.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        color: AppTheme.textWhite.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Mark Watched Button
          MarkWatchedButton(
            isWatched: widget.isWatched,
            watchCount: widget.watchCount,
            onTap: () {
              if (widget.isWatched) {
                widget.onTrackOptions(widget.seasonNumber, _epNumber);
              } else {
                final missing = widget.onFindMissingPreceding(
                  widget.seasonNumber,
                  _epNumber,
                );
                if (missing.isNotEmpty) {
                  widget.onShowMarkPrecedingModal(
                    widget.seasonNumber,
                    _epNumber,
                    missing,
                  );
                } else {
                  widget.onMarkWatched?.call(
                    widget.seasonNumber,
                    _epNumber,
                    null,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class MarkWatchedButton extends StatelessWidget {
  final bool isWatched;
  final int watchCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MarkWatchedButton({
    super.key,
    required this.isWatched,
    this.watchCount = 0,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: isWatched
          ? l10n.detailsTooltipWatched
          : l10n.detailsTooltipMarkWatched,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: HoverScale(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: watchCount > 1 ? 12 : 8,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isWatched
                    ? AppTheme.success
                    : AppTheme.textWhite.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isWatched
                      ? AppTheme.success
                      : AppTheme.textWhite.withValues(alpha: 0.1),
                ),
              ),
              child: watchCount > 1
                  ? Text(
                      'x$watchCount',
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Icon(
                      isWatched ? Icons.check : Icons.remove_red_eye_outlined,
                      color: isWatched ? AppTheme.textWhite : AppTheme.textMuted,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
