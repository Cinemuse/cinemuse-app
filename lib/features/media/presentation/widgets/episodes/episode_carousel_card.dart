import 'package:cinemuse_app/shared/widgets/card_marks.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_menu.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

/// A landscape 16:9 episode card designed for horizontal carousels.
class EpisodeCarouselCard extends ConsumerStatefulWidget {
  final EpisodeItem episode;
  final int seasonNumber;
  final String mediaId;
  final bool isWatched;
  final double? resumePercentage;
  final void Function(int season, int episode, String name, {bool restart})?
  onEpisodeTap;
  final Function(int season, int episode, DateTime? date)? onMarkWatched;
  final Function(int season, int episode)? onTrackOptions;
  final List<({int season, int episode})> Function(int season, int episode)?
  onFindMissingPreceding;
  final Function(
    int season,
    int episode,
    List<({int season, int episode})> missing,
  )?
  onShowMarkPrecedingModal;
  final VoidCallback? onShowComments;
  final VoidCallback? onViewHistory;

  const EpisodeCarouselCard({
    super.key,
    required this.episode,
    required this.seasonNumber,
    required this.mediaId,
    this.isWatched = false,
    this.resumePercentage,
    this.onEpisodeTap,
    this.onMarkWatched,
    this.onTrackOptions,
    this.onFindMissingPreceding,
    this.onShowMarkPrecedingModal,
    this.onShowComments,
    this.onViewHistory,
  });

  @override
  ConsumerState<EpisodeCarouselCard> createState() =>
      _EpisodeCarouselCardState();
}

class _EpisodeCarouselCardState extends ConsumerState<EpisodeCarouselCard> {
  int get _epNumber => widget.episode.episodeNumber;
  String get _epName {
    final l10n = AppLocalizations.of(context)!;
    return widget.episode.getTitle(l10n.detailsEpisodeFallback(_epNumber));
  }

  // Looked up on every build (a map lookup), so it never goes stale when
  // the card is reused for another episode or after playing (REV-208).
  bool get _hasCachedStream =>
      widget.mediaId.isNotEmpty &&
      ref
          .read(unifiedStreamResolverProvider)
          .hasCachedStream(
            widget.mediaId,
            'tv',
            season: widget.seasonNumber,
            episode: _epNumber,
          );

  void _clearCache() {
    final l10n = AppLocalizations.of(context)!;
    final resolver = ref.read(unifiedStreamResolverProvider);
    resolver.clearCachedStream(
      widget.mediaId,
      'tv',
      season: widget.seasonNumber,
      episode: _epNumber,
    );
    setState(() {});
    AppSnackBar.show(
      context,
      message: l10n.menuRemoveCachedProvider,
      duration: const Duration(seconds: 2),
      backgroundColor: AppTheme.secondary,
    );
  }

  void _showContextMenu(BuildContext context, {Offset? at}) {
    final l10n = AppLocalizations.of(context)!;

    final options = EpisodeMenu.buildEpisodeMenuOptions(
      context: context,
      l10n: l10n,
      mediaId: widget.mediaId,
      seasonNumber: widget.seasonNumber,
      episodeNumber: _epNumber,
      episodeName: _epName,
      isWatched: widget.isWatched,
      resumePercentage: widget.resumePercentage,
      hasCachedStream: _hasCachedStream,
      onClearCache: _clearCache,
      onEpisodeTap: widget.onEpisodeTap,
      onMarkWatched: widget.onMarkWatched,
      onTrackOptions: widget.onTrackOptions != null
          ? (s, e) => widget.onTrackOptions!(s, e)
          : null,
      onViewHistory: widget.onViewHistory,
      onFindMissingPreceding: widget.onFindMissingPreceding,
      onShowMarkPrecedingModal: widget.onShowMarkPrecedingModal,
      onShowComments: widget.onShowComments,
      onShowSynopsis: _hasOverview ? _showSynopsis : null,
    );

    AppMenu.show(
      context: context,
      title: l10n.detailsEpisodeWithSeason(
        widget.seasonNumber,
        _epNumber,
        _epName,
      ),
      options: options,
      position: at,
    );
  }

  bool get _hasOverview => (widget.episode.overview ?? '').trim().isNotEmpty;

  void _showSynopsis() => AppBottomSheet.show(
    context: context,
    constraints: const BoxConstraints(maxWidth: 640),
    child: _EpisodeSynopsisSheet(
      title: AppLocalizations.of(
        context,
      )!.detailsEpisodeWithSeason(widget.seasonNumber, _epNumber, _epName),
      meta: [
        ?_formatAirDate(context),
        if (widget.episode.runtime != null) '${widget.episode.runtime}m',
      ].join(' · '),
      overview: widget.episode.overview!.trim(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stillPath = widget.episode.stillPath;
    final runtime = widget.episode.runtime;
    final formattedAirDate = _formatAirDate(context);

    return DpadFocusable(
      onTap: () =>
          widget.onEpisodeTap?.call(widget.seasonNumber, _epNumber, _epName),
      onLongPress: () => _showContextMenu(context),
      onSecondaryTapDown: (d) =>
          _showContextMenu(context, at: d.globalPosition),
      scale: 1.04,
      borderRadius: AppTheme.radiusLg,
      showFocusRing: false,
      builder: (context, isFocused, isHovered, child) {
        return SizedBox(
          width: 270,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThumbnail(
                context,
                l10n,
                stillPath,
                runtime,
                isFocused || isHovered,
              ),
              const SizedBox(height: 10),
              _buildMetaInfo(context, formattedAirDate, isFocused || isHovered),
              if (_hasOverview) ...[
                const SizedBox(height: 6),
                _buildSynopsisPreview(context, l10n),
              ],
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }

  String? _formatAirDate(BuildContext context) {
    final airDate = widget.episode.airDate;
    if (airDate == null) return null;
    return DateFormat.yMMMd(
      Localizations.localeOf(context).languageCode,
    ).format(airDate);
  }

  Widget _buildThumbnail(
    BuildContext context,
    AppLocalizations l10n,
    String? stillPath,
    dynamic runtime,
    bool isHighlighted,
  ) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: AppTheme.radiusLg,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildStillImage(context, stillPath),
                _buildPlayOverlay(context, isHighlighted),
                _buildBadges(l10n, runtime),
                _buildProgressBar(),
              ],
            ),
          ),
          Positioned.fill(
            child: CardFocusBorder(borderRadius: AppTheme.radiusLg),
          ),
        ],
      ),
    );
  }

  Widget _buildStillImage(BuildContext context, String? stillPath) {
    final theme = Theme.of(context);
    if (stillPath != null) {
      return CachedNetworkImage(
        imageUrl: TmdbImageHelper.stillUrl(context, stillPath) ?? '',
        memCacheWidth: 400,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Container(color: theme.colorScheme.surfaceContainer),
        errorWidget: (context, url, error) => Container(
          color: theme.colorScheme.surfaceContainer,
          child: Icon(
            Icons.tv,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            size: 32,
          ),
        ),
      );
    }
    return Container(
      color: theme.colorScheme.surfaceContainer,
      child: Icon(
        Icons.tv,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        size: 32,
      ),
    );
  }

  Widget _buildPlayOverlay(BuildContext context, bool isHighlighted) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isHighlighted ? theme.focusColor : AppTheme.surfaceOverlay,
          shape: BoxShape.circle,
          border: Border.all(
            color: isHighlighted
                ? theme.colorScheme.primary
                : AppTheme.borderSubtle,
          ),
        ),
        child: Icon(
          Icons.play_arrow,
          color: isHighlighted ? theme.colorScheme.primary : AppTheme.textWhite,
          size: isHighlighted ? 28 : 22,
        ),
      ),
    );
  }

  Widget _buildBadges(AppLocalizations l10n, dynamic runtime) {
    return Stack(
      children: [
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOverlay,
              borderRadius: AppTheme.radiusSm,
              border: Border.all(
                color: AppTheme.textWhite.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              l10n.detailsEpisodeNumber(_epNumber),
              style: AppTheme.monoStyle(
                color: AppTheme.textWhite,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (widget.isWatched)
          Positioned(top: 6, right: 6, child: const WatchedTick())
        else if (_hasCachedStream)
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
        // Runtime badge bottom-right
        if (runtime != null)
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOverlay,
                borderRadius: AppTheme.radiusSm,
              ),
              child: Text(
                '${runtime}m',
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar() {
    if (widget.isWatched ||
        widget.resumePercentage == null ||
        widget.resumePercentage! <= 0) {
      return const SizedBox.shrink();
    }
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 3,
        color: AppTheme.textWhite.withValues(alpha: 0.1),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: widget.resumePercentage!.clamp(0.0, 1.0),
          child: Container(color: AppTheme.accent),
        ),
      ),
    );
  }

  Widget _buildMetaInfo(
    BuildContext context,
    String? formattedAirDate,
    bool isHighlighted,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$_epNumber. $_epName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DesktopTypography.bodySecondary.copyWith(
            fontWeight: FontWeight.bold,
            color: isHighlighted
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.9),
          ),
        ),
        if (formattedAirDate != null) ...[
          const SizedBox(height: 2),
          Text(
            formattedAirDate,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  /// The first two lines, like the phone's list; "Read more" opens the whole
  /// text. It is not a stop for the arrows: the card is one stop, and its menu
  /// has "Synopsis" for the remote.
  Widget _buildSynopsisPreview(BuildContext context, AppLocalizations l10n) {
    final overview = widget.episode.overview!.trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measured like the Text below draws it, so "Read more" shows
        // whenever the text is cut.
        final painter = TextPainter(
          text: TextSpan(text: overview, style: _previewStyle),
          maxLines: 2,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final isCut = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              overview,
              style: _previewStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isCut)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showSynopsis,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.detailsReadMore,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static const _previewStyle = TextStyle(
    color: AppTheme.textMuted,
    fontSize: 12,
    height: 1.4,
  );
}

/// An episode's whole synopsis, opened from a card's "Read more" or its menu.
/// Nothing in it can be pressed: Back, Esc or a click outside closes it, and
/// the arrows scroll a long text.
class _EpisodeSynopsisSheet extends StatefulWidget {
  final String title;
  final String meta;
  final String overview;

  const _EpisodeSynopsisSheet({
    required this.title,
    required this.meta,
    required this.overview,
  });

  @override
  State<_EpisodeSynopsisSheet> createState() => _EpisodeSynopsisSheetState();
}

class _EpisodeSynopsisSheetState extends State<_EpisodeSynopsisSheet> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 80.0,
      LogicalKeyboardKey.arrowUp => -80.0,
      _ => null,
    };
    if (step == null) return KeyEventResult.ignored;
    if (_scroll.hasClients) {
      _scroll.animateTo(
        (_scroll.offset + step).clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxTextHeight = MediaQuery.sizeOf(context).height * 2 / 3;
    return AppBottomSheet(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.meta.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.meta,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxTextHeight),
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Text(
                    widget.overview,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
