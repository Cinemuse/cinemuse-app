import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episode_actions_helper.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

/// A landscape 16:9 episode card designed for horizontal carousels.
class EpisodeThumbnailCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> episode;
  final int seasonNumber;
  final String mediaId;
  final bool isWatched;
  final int watchCount;
  final double? resumePercentage;
  final VoidCallback? onTap;
  final void Function(int season, int episode, String name, {bool restart})? onEpisodeTap;
  final Function(int season, int episode, DateTime? date)? onMarkWatched;
  final Function(int season, int episode)? onTrackOptions;
  final List<({int season, int episode})> Function(int season, int episode)?
  onFindMissingPreceding;
  final Function(int season, int episode, List<({int season, int episode})> missing)?
  onShowMarkPrecedingModal;
  final VoidCallback? onShowComments;
  final VoidCallback? onViewHistory;

  const EpisodeThumbnailCard({
    super.key,
    required this.episode,
    required this.seasonNumber,
    required this.mediaId,
    this.isWatched = false,
    this.watchCount = 0,
    this.resumePercentage,
    this.onTap,
    this.onEpisodeTap,
    this.onMarkWatched,
    this.onTrackOptions,
    this.onFindMissingPreceding,
    this.onShowMarkPrecedingModal,
    this.onShowComments,
    this.onViewHistory,
  });

  @override
  ConsumerState<EpisodeThumbnailCard> createState() =>
      _EpisodeThumbnailCardState();
}

class _EpisodeThumbnailCardState extends ConsumerState<EpisodeThumbnailCard> {
  bool _hasCachedStream = false;

  int get _epNumber => widget.episode['episode_number'] as int? ?? 1;
  String get _epName => widget.episode['name'] ?? 'Episode $_epNumber';

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

  void _showContextMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    _refreshCacheState();

    final options = EpisodeActionsHelper.buildEpisodeMenuOptions(
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
    );

    AppMenu.show(
      context: context,
      title: 'S${widget.seasonNumber} E$_epNumber • $_epName',
      options: options,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stillPath = widget.episode['still_path'];
    final runtime = widget.episode['runtime'];
    final formattedAirDate = _formatAirDate(context);

    return DpadFocusable(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          widget.onEpisodeTap?.call(
            widget.seasonNumber,
            _epNumber,
            _epName,
          );
        }
      },
      onLongPress: () => _showContextMenu(context),
      onSecondaryTap: () => _showContextMenu(context),
      scale: 1.04,
      borderRadius: BorderRadius.circular(16),
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
                isFocused,
                isHovered,
              ),
              const SizedBox(height: 10),
              _buildMetaInfo(context, formattedAirDate, isFocused),
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }

  String? _formatAirDate(BuildContext context) {
    final airDateStr = widget.episode['air_date']?.toString();
    if (airDateStr == null) return null;
    final airDate = DateTime.tryParse(airDateStr);
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
    bool isFocused,
    bool isHovered,
  ) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildStillImage(context, stillPath),
                _buildPlayOverlay(context, isFocused),
                _buildBadges(l10n, runtime),
                _buildProgressBar(),
              ],
            ),
          ),
          Positioned.fill(
            child: CardFocusBorder(
              isFocused: isFocused,
              isHovered: isHovered,
              borderRadius: BorderRadius.circular(16),
            ),
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
        placeholder: (context, url) => Container(color: theme.colorScheme.surfaceContainer),
        errorWidget: (context, url, error) => Container(
          color: theme.colorScheme.surfaceContainer,
          child: Icon(Icons.tv, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 32),
        ),
      );
    }
    return Container(
      color: theme.colorScheme.surfaceContainer,
      child: Icon(Icons.tv, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 32),
    );
  }

  Widget _buildPlayOverlay(BuildContext context, bool isFocused) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isFocused ? theme.focusColor : AppTheme.surfaceOverlay,
          shape: BoxShape.circle,
          border: Border.all(
            color: isFocused ? theme.colorScheme.primary : AppTheme.borderSubtle,
          ),
        ),
        child: Icon(
          Icons.play_arrow,
          color: isFocused ? theme.colorScheme.primary : AppTheme.textWhite,
          size: isFocused ? 28 : 22,
        ),
      ),
    );
  }

  Widget _buildBadges(AppLocalizations l10n, dynamic runtime) {
    return Stack(
      children: [
        // Episode badge top-left
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOverlay,
              borderRadius: BorderRadius.circular(4),
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
        // Watched indicator badge top-right
        if (widget.isWatched)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: AppTheme.textWhite,
                size: 12,
              ),
            ),
          )
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
                borderRadius: BorderRadius.circular(4),
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
          child: Container(
            color: AppTheme.accent,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaInfo(BuildContext context, String? formattedAirDate, bool isFocused) {
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
            color: isFocused
                ? theme.colorScheme.onSurface
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
}
