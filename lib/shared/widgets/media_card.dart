import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/shared/widgets/card_bottom_vignette.dart';
import 'package:cinemuse_app/shared/widgets/card_list_actions.dart';
import 'package:cinemuse_app/shared/widgets/card_title_row.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/shared/widgets/card_progress_bar.dart';

class MediaCard extends StatefulWidget {
  final String title;
  final String? posterPath;
  final String? releaseDate;
  final double? rating;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onRemoveFromList;
  final VoidCallback? onRestore;

  /// The menu's "Watchlist" and "Add to list" entries; null hides them
  /// (a person, or a list that offers its own actions).
  final CardListActions? listActions;

  // Optional playback progress (0.0 to 1.0) & metadata subtitle (e.g. S1 E5)
  final double? progress;
  final String? infoText;

  // Optional count of grouped watch-history items, shown in the badge
  final int? stackCount;

  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const MediaCard({
    super.key,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.rating,
    this.onTap,
    this.onPlay,
    this.onRemoveFromList,
    this.onRestore,
    this.listActions,
    this.progress,
    this.infoText,
    this.stackCount,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  final GlobalKey _menuKey = GlobalKey();

  void _showContextActions(
    BuildContext context, {
    BuildContext? anchorContext,
    Offset? at,
  }) {
    final l10n = AppLocalizations.of(context)!;

    final options = [
      if (widget.onPlay != null)
        AppMenuOption(
          icon: Icons.play_arrow_outlined,
          label: l10n.menuPlay,
          onTap: widget.onPlay!,
        ),
      if (widget.onTap != null)
        AppMenuOption(
          icon: Icons.info_outline,
          label: l10n.homeMoreInfo,
          onTap: widget.onTap!,
        ),
      ...cardListMenuOptions(l10n, widget.listActions),
      if (widget.onRemoveFromList != null)
        AppMenuOption(
          icon: Icons.remove_circle_outline,
          label: l10n.menuRemoveFromList,
          onTap: widget.onRemoveFromList!,
        ),
      if (widget.onRestore != null)
        AppMenuOption(
          icon: Icons.restore,
          label: l10n.menuRestoreContinueWatching,
          onTap: widget.onRestore!,
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

  Widget? _buildOverlayBadge() {
    final isStacked = widget.stackCount != null && widget.stackCount! > 1;
    final hasInfo = widget.infoText != null && widget.infoText!.isNotEmpty;

    if (!isStacked && !hasInfo) return null;

    final String badgeText;
    if (isStacked) {
      badgeText = (hasInfo)
          ? '${widget.stackCount} • ${widget.infoText!}'
          : '${widget.stackCount}';
    } else {
      badgeText = widget.infoText!;
    }

    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.7),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isStacked) ...[
              const Icon(
                Icons.layers_rounded,
                color: AppTheme.accent,
                size: 11,
              ),
              const SizedBox(width: 3.5),
            ],
            Text(
              badgeText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final year = widget.releaseDate?.split('-').first ?? '';
    final imageUrl = TmdbImageHelper.posterUrl(context, widget.posterPath);

    return DpadFocusable(
      focusNode: widget.focusNode,
      onKeyEvent: widget.onKeyEvent,
      onTap: widget.onTap,
      onLongPress: () => _showContextActions(context),
      onSecondaryTapDown: (d) =>
          _showContextActions(context, at: d.globalPosition),
      scale: 1.05,

      // CardFocusBorder draws the ring around the picture only.
      showFocusRing: false,
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppTheme.surface,
                      boxShadow: AppTheme.shadowCard,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageUrl != null)
                                LayoutBuilder(
                                  builder: (context, constraints) =>
                                      CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        // Physical pixels: the card's real
                                        // width times the screen density.
                                        memCacheWidth:
                                            constraints.hasBoundedWidth
                                            ? (constraints.maxWidth *
                                                      MediaQuery.devicePixelRatioOf(
                                                        context,
                                                      ))
                                                  .round()
                                            : null,
                                        fadeInDuration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        placeholderFadeInDuration:
                                            Duration.zero,
                                        placeholder: (context, url) =>
                                            Container(color: AppTheme.surface),
                                        errorWidget: (context, url, error) =>
                                            const Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                color: Colors.white24,
                                              ),
                                            ),
                                      ),
                                )
                              else
                                const Center(
                                  child: Icon(
                                    Icons.movie,
                                    color: Colors.white24,
                                    size: 48,
                                  ),
                                ),

                              const CardBottomVignette(),

                              Builder(
                                builder: (context) {
                                  final isHighlighted =
                                      DpadFocusScope.maybeOf(
                                        context,
                                      )?.isHighlighted ??
                                      false;
                                  return AnimatedOpacity(
                                    opacity: isHighlighted ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.center,
                                          colors: [
                                            Colors.black87,
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Optional Playback Progress Bar
                              if (widget.progress != null)
                                CardProgressBar(progress: widget.progress!),
                            ],
                          ),
                        ),

                        // Border Overlay (On Top)
                        const CardFocusBorder(),

                        // Unified Stack & Episode Overlay Badge (Top-Right)
                        if (_buildOverlayBadge() case final badge?) badge,
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CardTitleRow(
              title: widget.title,
              onMenu: () => _showContextActions(context),
              menuAnchorKey: _menuKey,
              showsFullTitleOnHover: true,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (widget.rating != null && widget.rating! > 0) ...[
                  const Icon(Icons.star, size: 12, color: AppTheme.star),
                  const SizedBox(width: 4),
                  Text(
                    widget.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (widget.rating != null &&
                    widget.rating! > 0 &&
                    year.isNotEmpty)
                  const SizedBox(width: 6),
                if (year.isNotEmpty)
                  Flexible(
                    child: Text(
                      year,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
