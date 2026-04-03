import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/premium_hover_text.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

class MediaCard extends ConsumerStatefulWidget {
  final String title;
  final String? posterPath;
  final String? releaseDate;
  final double? rating;
  final bool isWatchlisted;
  final VoidCallback? onWatchlistToggle;
  final VoidCallback? onTap;
  
  // New props for centralized logic
  final int? tmdbId;
  final MediaKind? mediaType;

  const MediaCard({
    super.key,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.rating,
    this.isWatchlisted = false,
    this.onWatchlistToggle,
    this.onTap,
    this.onPlay,
    this.tmdbId,
    this.mediaType,
  });

  final VoidCallback? onPlay;

  @override
  ConsumerState<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends ConsumerState<MediaCard> {
  bool _isHovered = false;
  final GlobalKey _menuKey = GlobalKey();

  void _showContextActions(BuildContext context, {BuildContext? anchorContext}) {
    final l10n = AppLocalizations.of(context)!;
    
    // Determine if already watchlisted to show toggle correctly
    bool isWatchlisted = false;
    if (widget.tmdbId != null && widget.mediaType != null) {
      isWatchlisted = ref.read(userListsProvider).valueOrNull
          ?.where((l) => l.type == ListType.watchlist)
          .firstOrNull
          ?.items
          .any((i) => i.tmdbId == widget.tmdbId && i.mediaType == widget.mediaType) ?? false;
    } else if (widget.onWatchlistToggle != null) {
      isWatchlisted = widget.isWatchlisted;
    }

    final options = [
      if (widget.onPlay != null)
        AppMenuOption(
          icon: Icons.play_arrow_outlined,
          label: l10n.menuPlay,
          onTap: widget.onPlay!,
        ),
      AppMenuOption(
        icon: Icons.info_outline,
        label: l10n.homeMoreInfo,
        onTap: widget.onTap ?? () {},
      ),
      if ((widget.tmdbId != null && widget.mediaType != null) || widget.onWatchlistToggle != null)
        AppMenuOption(
          icon: isWatchlisted ? Icons.bookmark_remove : Icons.bookmark_add_outlined,
          label: isWatchlisted ? l10n.menuRemoveFromWatchlist : l10n.menuAddToWatchlist,
          onTap: () {
            if (widget.onWatchlistToggle != null) {
              widget.onWatchlistToggle!.call();
            } else {
              ref.read(userListsProvider.notifier).toggleWatchlist(
                MediaItem(
                  tmdbId: widget.tmdbId!,
                  mediaType: widget.mediaType!,
                  titleEn: widget.title,
                  posterPath: widget.posterPath,
                  releaseDate: widget.releaseDate != null ? DateTime.tryParse(widget.releaseDate!) : null,
                  voteAverage: widget.rating,
                  updatedAt: DateTime.now(),
                ),
              );
            }
          },
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
    final year = widget.releaseDate?.split('-').first ?? '';
    final imageUrl = widget.posterPath != null 
        ? "https://image.tmdb.org/t/p/w500${widget.posterPath}" 
        : null;

    return Focus(
      onFocusChange: (value) => setState(() => _isHovered = value),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final isEnter = event.logicalKey == LogicalKeyboardKey.enter;
          final isSelect = event.logicalKey == LogicalKeyboardKey.select;
          if (isEnter || isSelect) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: () => _showContextActions(context),
          onSecondaryTapDown: (_) => _showContextActions(context),
          child: AnimatedScale(
              scale: _isHovered ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster Image
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 0.7,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppTheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: _isHovered ? 16 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Image Content (Clipped)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (imageUrl != null)
                                  CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 300, // Optimize memory usage
                                    placeholder: (context, url) => Container(
                                      color: AppTheme.surface,
                                      child: const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => const Center(
                                      child: Icon(Icons.broken_image, color: Colors.white24),
                                    ),
                                  )
                                else
                                  const Center(child: Icon(Icons.movie, color: Colors.white24, size: 48)),

                                // Gradient Overlay
                                AnimatedOpacity(
                                  opacity: _isHovered ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.center,
                                        colors: [Colors.black87, Colors.transparent],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Border Overlay (On Top)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isHovered 
                                    ? AppTheme.accent.withValues(alpha: 0.5) 
                                    : Colors.white.withValues(alpha: 0.1),
                                width: _isHovered ? 2 : 1,
                              ),
                            ),
                          ),
                        
                        // Context Menu Button (More Options)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Consumer(
                            builder: (context, ref, child) {
                              final isMobile = MediaQuery.of(context).size.width < 600;
                              return AnimatedOpacity(
                                opacity: (_isHovered || isMobile) ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _showContextActions(context),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      key: _menuKey,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.more_vert,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
                const SizedBox(height: 8),
                // Title
                PremiumHoverText(
                  text: widget.title,
                  style: GoogleFonts.outfit(
                    color: _isHovered ? AppTheme.accent : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                // MetadataRow
                Row(
                  children: [
                    if (widget.rating != null && widget.rating! > 0)
                      const Icon(Icons.star, size: 12, color: AppTheme.star),
                    if (widget.rating != null && widget.rating! > 0)
                      const SizedBox(width: 4),
                    if (widget.rating != null && widget.rating! > 0)
                      const Text(
                        "", // Placeholder logic if needed, otherwise removed rating display
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    if (widget.rating != null && widget.rating! > 0)
                      Text(
                        widget.rating!.toStringAsFixed(1),
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    if (widget.rating != null && widget.rating! > 0 && year.isNotEmpty)
                      const SizedBox(width: 8),
                    if (year.isNotEmpty) 
                      Text(
                        year,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
