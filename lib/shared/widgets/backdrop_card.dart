import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/card_bottom_vignette.dart';
import 'package:cinemuse_app/shared/widgets/card_list_actions.dart';
import 'package:cinemuse_app/shared/widgets/card_title_row.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/shared/widgets/card_progress_bar.dart';

class BackdropCard extends StatefulWidget {
  final String title;
  final String? backdropPath;
  final String? posterPath;
  final double? progress; // 0.0 to 1.0

  /// The muted line under the title (see [CardTitleRow]).
  final String? subtitle;
  final String? subtitleEnd;
  final VoidCallback? onTap;
  final VoidCallback? onDrop;
  final VoidCallback? onCancelRewatch;
  final VoidCallback? onDetails;
  final VoidCallback? onRestart;
  final VoidCallback? onClearCache;
  final VoidCallback? onClearProgress;

  /// The menu's "Watchlist" and "Add to list" entries; null hides them.
  final CardListActions? listActions;
  final double? width;

  const BackdropCard({
    super.key,
    required this.title,
    this.backdropPath,
    this.posterPath,
    this.progress,
    this.subtitle,
    this.subtitleEnd,
    this.onTap,
    this.onDrop,
    this.onCancelRewatch,
    this.onDetails,
    this.onRestart,
    this.onClearCache,
    this.onClearProgress,
    this.listActions,
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
    Offset? at,
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
      if (widget.onClearProgress != null &&
          (widget.progress != null && widget.progress! > 0))
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
      ...cardListMenuOptions(l10n, widget.listActions),
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
      position: at,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? effectiveImagePath = widget.backdropPath ?? widget.posterPath;

    final imageUrl = TmdbImageHelper.backdropCardUrl(
      context,
      effectiveImagePath,
    );
    final cardWidth = widget.width ?? 280;
    // memCacheWidth is in physical pixels: decode at the real on-screen size.
    final cacheWidth = (cardWidth * MediaQuery.devicePixelRatioOf(context))
        .round();

    return DpadFocusable(
      onTap: widget.onTap,
      onLongPress: () => _showContextActions(context),
      onSecondaryTapDown: (d) =>
          _showContextActions(context, at: d.globalPosition),
      scale: 1.02,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      autoScroll: true,
      showFocusRing: false,
      child: SizedBox(
        width: cardWidth,
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
                              memCacheWidth: cacheWidth,
                              color: Colors.black.withValues(alpha: 0.2),
                              colorBlendMode: BlendMode.darken,
                              errorWidget: (context, url, error) =>
                                  _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),

                    const CardBottomVignette(),

                    // Play Icon
                    Builder(
                      builder: (context) {
                        final isHighlighted =
                            DpadFocusScope.maybeOf(context)?.isHighlighted ??
                            false;
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

                    // Progress Bar
                    if (widget.progress != null)
                      CardProgressBar(progress: widget.progress!),

                    // Border Overlay
                    const CardFocusBorder(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            CardTitleRow(
              title: widget.title,
              onMenu: () => _showContextActions(context),
              menuAnchorKey: _menuKey,
              menuIconSize: 18,
              subtitle: widget.subtitle,
              subtitleEnd: widget.subtitleEnd,
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
