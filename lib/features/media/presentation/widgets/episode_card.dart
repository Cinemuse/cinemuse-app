import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

class EpisodeCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> episode;
  final int seasonNumber;
  final Map<String, dynamic> media;

  /// TMDB ID string used for cache key lookup.
  final String mediaId;
  final bool isWatched;
  final int watchCount;
  final double? resumePercentage;
  final Function(int, int, String)? onEpisodeTap;
  final Function(int, int, DateTime?)? onMarkWatched;
  final Function(int, int) onTrackOptions;
  final List<({int season, int episode})> Function(int, int)
  onFindMissingPreceding;
  final Function(int, int, List<({int season, int episode})>)
  onShowMarkPrecedingModal;
  final VoidCallback? onShowTvTimeComments;

  const EpisodeCard({
    super.key,
    required this.episode,
    required this.seasonNumber,
    required this.media,
    required this.mediaId,
    required this.isWatched,
    required this.watchCount,
    this.resumePercentage,
    this.onEpisodeTap,
    this.onMarkWatched,
    required this.onTrackOptions,
    required this.onFindMissingPreceding,
    required this.onShowMarkPrecedingModal,
    this.onShowTvTimeComments,
  });

  @override
  ConsumerState<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends ConsumerState<EpisodeCard> {
  bool _isExpanded = false;
  bool _hasCachedStream = false;
  Offset? _tapPosition;

  int get _epNumber => widget.episode['episode_number'] as int;

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.menuRemoveCachedProvider),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.secondary,
      ),
    );
  }

  void _showContextMenu(BuildContext context, {BuildContext? anchorContext}) {
    final l10n = AppLocalizations.of(context)!;
    final epName = widget.episode['name'] ?? 'Episode $_epNumber';
    final hasProgress = (widget.resumePercentage ?? 0) > 0 && !widget.isWatched;

    _refreshCacheState();

    final options = [
      AppMenuOption(
        icon: Icons.play_arrow_outlined,
        label: hasProgress ? l10n.menuResume : l10n.detailsPlay,
        onTap: () =>
            widget.onEpisodeTap?.call(widget.seasonNumber, _epNumber, epName),
      ),
      if (hasProgress)
        AppMenuOption(
          icon: Icons.replay,
          label: l10n.menuRestart,
          onTap: () =>
              widget.onEpisodeTap?.call(widget.seasonNumber, _epNumber, epName),
        ),
      if (_hasCachedStream)
        AppMenuOption(
          icon: Icons.cached,
          label: l10n.menuRemoveCachedProvider,
          onTap: _clearCache,
        ),
      if (widget.isWatched)
        AppMenuOption(
          icon: Icons.check_circle,
          label: l10n.detailsTooltipWatched,
          onTap: () => widget.onTrackOptions(widget.seasonNumber, _epNumber),
        )
      else ...[
        AppMenuOption(
          icon: Icons.remove_red_eye_outlined,
          label: l10n.menuMarkWatchedNow,
          onTap: () {
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
              widget.onMarkWatched?.call(widget.seasonNumber, _epNumber, null);
            }
          },
        ),
        AppMenuOption(
          icon: Icons.edit_calendar,
          label: l10n.menuMarkWatchedCustomDate,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppTheme.accent,
                      onPrimary: Colors.white,
                      surface: AppTheme.secondary,
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              widget.onMarkWatched?.call(widget.seasonNumber, _epNumber, date);
            }
          },
        ),
      ],
      if (widget.onShowTvTimeComments != null)
        AppMenuOption(
          icon: Icons.forum_outlined,
          label: 'TVTime Comments',
          onTap: widget.onShowTvTimeComments!,
        ),
    ];

    AppMenu.show(
      context: context,
      options: options,
      title: epName,
      anchorContext: anchorContext,
      position: _tapPosition,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.episode['name'] ?? 'Episode $_epNumber';
    final overview = widget.episode['overview'] ?? '';
    final stillPath = widget.episode['still_path'];
    final runtime = widget.episode['runtime'];
    final airDateStr = widget.episode['air_date']?.toString();
    final DateTime? airDate = airDateStr != null
        ? DateTime.tryParse(airDateStr)
        : null;
    final formattedAirDate = airDate != null
        ? DateFormat.yMMMd(
            Localizations.localeOf(context).languageCode,
          ).format(airDate)
        : null;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onSecondaryTapDown: (details) => _tapPosition = details.globalPosition,
      onSecondaryTap: () => _showContextMenu(context),
      onLongPressStart: (details) => _tapPosition = details.globalPosition,
      onLongPress: () => _showContextMenu(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.secondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.textWhite.withValues(alpha: 0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                widget.onEpisodeTap?.call(widget.seasonNumber, _epNumber, name),
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
          ),
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
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.secondary,
                borderRadius: BorderRadius.circular(8),
                image: stillPath != null
                    ? DecorationImage(
                        image: NetworkImage(
                          'https://image.tmdb.org/t/p/w300$stillPath',
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: stillPath == null
                  ? const Center(
                      child: Icon(
                        Icons.tv,
                        color: AppTheme.textMuted,
                        size: 32,
                      ),
                    )
                  : null,
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
                color: Colors.black.withValues(alpha: 0.6),
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
                  color: Colors.black.withValues(alpha: 0.6),
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
          // TV Time Comments Button
          if (widget.onShowTvTimeComments != null)
            Tooltip(
              message: 'TVTime Comments',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onShowTvTimeComments,
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
            onLongPress:
                () {}, // Empty to prevent default behavior, or just remove if we modify the widget
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
                    ? Colors.green
                    : AppTheme.textWhite.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isWatched
                      ? Colors.green
                      : AppTheme.textWhite.withValues(alpha: 0.1),
                ),
              ),
              child: watchCount > 1
                  ? Text(
                      'x$watchCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Icon(
                      isWatched ? Icons.check : Icons.remove_red_eye_outlined,
                      color: isWatched ? Colors.white : AppTheme.textMuted,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
