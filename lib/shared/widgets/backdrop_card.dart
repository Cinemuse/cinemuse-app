import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';

class BackdropCard extends StatefulWidget {
  final String title;
  final String? backdropPath;
  final String? posterPath;
  final double? progress; // 0.0 to 1.0
  final String? infoText; // e.g. "S1 E5" or "1h 20m left"
  final VoidCallback? onTap;
  final VoidCallback? onDrop;
  final VoidCallback? onCancelRewatch;
  final VoidCallback? onDetails;
  final VoidCallback? onRestart;
  final VoidCallback? onWatchlistToggle;
  final VoidCallback? onClearCache;
  final VoidCallback? onClearProgress;
  final VoidCallback? onAddToList;
  final bool isWatchlisted;
  final double? width;

  const BackdropCard({
    super.key,
    required this.title,
    this.backdropPath,
    this.posterPath,
    this.progress,
    this.infoText,
    this.onTap,
    this.onDrop,
    this.onCancelRewatch,
    this.onDetails,
    this.onRestart,
    this.onWatchlistToggle,
    this.onClearCache,
    this.onClearProgress,
    this.onAddToList,
    this.isWatchlisted = false,
    this.width,
  });

  @override
  State<BackdropCard> createState() => _BackdropCardState();
}

class _BackdropCardState extends State<BackdropCard> {
  final GlobalKey _menuKey = GlobalKey();

  void _showContextActions(
    BuildContext context, {
    BuildContext? anchorContext,
  }) {
    final l10n = AppLocalizations.of(context)!;

    final options = [
      if (widget.onTap != null)
        AppMenuOption(
          icon: Icons.play_arrow_outlined,
          label: l10n.menuResume,
          onTap: widget.onTap!,
        ),
      if (widget.onRestart != null)
        AppMenuOption(
          icon: Icons.replay,
          label: l10n.menuRestart,
          onTap: widget.onRestart!,
        ),
      if (widget.onClearProgress != null && (widget.progress != null && widget.progress! > 0))
        AppMenuOption(
          icon: Icons.history_toggle_off_outlined,
          label: l10n.menuClearProgress,
          onTap: widget.onClearProgress!,
        ),
      if (widget.onDetails != null)
        AppMenuOption(
          icon: Icons.info_outline,
          label: l10n.homeMoreInfo,
          onTap: widget.onDetails!,
        ),
      if (widget.onWatchlistToggle != null)
        AppMenuOption(
          icon: widget.isWatchlisted
              ? Icons.bookmark_remove
              : Icons.bookmark_add_outlined,
          label: widget.isWatchlisted
              ? l10n.menuRemoveFromWatchlist
              : l10n.menuAddToWatchlist,
          onTap: widget.onWatchlistToggle!,
        ),
      if (widget.onAddToList != null)
        AppMenuOption(
          icon: Icons.playlist_add,
          label: l10n.detailsAddToList,
          onTap: widget.onAddToList!,
        ),
      if (widget.onClearCache != null)
        AppMenuOption(
          icon: Icons.cached,
          label: l10n.menuRemoveCachedProvider,
          onTap: widget.onClearCache!,
        ),
      if (widget.onDrop != null)
        AppMenuOption(
          icon: Icons.stop_circle_outlined,
          label: l10n.menuStopWatching,
          onTap: widget.onDrop!,
        ),
      if (widget.onCancelRewatch != null)
        AppMenuOption(
          icon: Icons.cancel_presentation,
          label: l10n.menuCancelRewatch,
          onTap: widget.onCancelRewatch!,
        ),
    ];

    AppMenu.show(
      context: context,
      options: options,
      title: widget.title,
      anchorContext: anchorContext ?? _menuKey.currentContext,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? effectiveImagePath = widget.backdropPath ?? widget.posterPath;

    final imageUrl = TmdbImageHelper.backdropCardUrl(context, effectiveImagePath);

    return DpadFocusable(
      onTap: widget.onTap,
      onLongPress: () => _showContextActions(context),
      onSecondaryTap: () => _showContextActions(context),
      scale: 1.02,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      autoScroll: true,
      child: SizedBox(
        width: widget.width ?? 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                      // Backdrop Image
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: AppTheme.surface,
                            boxShadow: AppTheme.shadowCard,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 280, // Target width
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        colorBlendMode: BlendMode.darken,
                                        errorWidget: (context, url, error) =>
                                            _buildPlaceholder(),
                                      )
                                    : _buildPlaceholder(),
                              ),

                              // Subtle Static Bottom Vignette
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.center,
                                    colors: [
                                      Color(0x73000000),
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, 0.4],
                                  ),
                                ),
                              ),

                              // Play Icon
                              Builder(
                                builder: (context) {
                                  final isHighlighted =
                                      DpadFocusScope.maybeOf(context)?.isHighlighted ?? false;
                                  final theme = Theme.of(context);
                                  return Center(
                                    child: AnimatedScale(
                                      scale: isHighlighted ? 1.1 : 1.0,
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        color: isHighlighted
                                            ? theme.colorScheme.primary
                                            : Colors.white.withValues(alpha: 0.8),
                                        size: 48,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Info Badge
                              if (widget.infoText != null)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      widget.infoText!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),

                              // Progress Bar
                              if (widget.progress != null)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: LinearProgressIndicator(
                                    value: widget.progress,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.redAccent,
                                        ),
                                    minHeight: 4,
                                  ),
                                ),

                              // Border Overlay
                              const CardFocusBorder(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Title + Options Row
                      Builder(
                        builder: (context) {
                          final isHighlighted =
                              DpadFocusScope.maybeOf(context)?.isHighlighted ?? false;
                          final theme = Theme.of(context);

                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    color: isHighlighted
                                        ? theme.colorScheme.primary
                                        : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Consumer(
                                builder: (context, ref, _) {
                                  final isBigPicture =
                                      ref.watch(isBigPictureProvider);
                                  if (isBigPicture) {
                                    return const SizedBox.shrink();
                                  }
                                  final isMobile =
                                      MediaQuery.of(context).size.width < 600;
                                  return AnimatedOpacity(
                                    opacity:
                                        (isHighlighted || isMobile) ? 1.0 : 0.0,
                                    duration:
                                        const Duration(milliseconds: 200),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        canRequestFocus: false,
                                        excludeFromSemantics: true,
                                        onTap: () =>
                                            _showContextActions(context),
                                        mouseCursor:
                                            SystemMouseCursors.click,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Container(
                                          key: _menuKey,
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          child: const Icon(
                                            Icons.more_vert,
                                            color: Colors.white60,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.surface.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.movie_outlined,
              color: Colors.white.withValues(alpha: 0.2),
              size: 40,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
