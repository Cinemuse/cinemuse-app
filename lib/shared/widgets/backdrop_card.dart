
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

class BackdropCard extends StatefulWidget {
  final String title;
  final String? backdropPath;
  final String? posterPath;
  final double? progress; // 0.0 to 1.0
  final String? infoText; // e.g. "S1 E5" or "1h 20m left"
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onDetails;
  final VoidCallback? onRestart;
  final VoidCallback? onWatchlistToggle;
  final bool isWatchlisted;

  const BackdropCard({
    super.key,
    required this.title,
    this.backdropPath,
    this.posterPath,
    this.progress,
    this.infoText,
    this.onTap,
    this.onRemove,
    this.onDetails,
    this.onRestart,
    this.onWatchlistToggle,
    this.isWatchlisted = false,
  });

  @override
  State<BackdropCard> createState() => _BackdropCardState();
}

class _BackdropCardState extends State<BackdropCard> {
  bool _isHovered = false;
  final GlobalKey _menuKey = GlobalKey();

  void _showContextActions(BuildContext context, {BuildContext? anchorContext}) {
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
      if (widget.onDetails != null)
        AppMenuOption(
          icon: Icons.info_outline,
          label: l10n.homeMoreInfo,
          onTap: widget.onDetails!,
        ),
      if (widget.onWatchlistToggle != null)
        AppMenuOption(
          icon: widget.isWatchlisted ? Icons.bookmark_remove : Icons.bookmark_add_outlined,
          label: widget.isWatchlisted ? l10n.menuRemoveFromWatchlist : l10n.menuAddToWatchlist,
          onTap: widget.onWatchlistToggle!,
        ),
      if (widget.onRemove != null)
        AppMenuOption(
          icon: Icons.delete_outline,
          label: l10n.menuRemoveFromContinueWatching,
          onTap: widget.onRemove!,
          isDestructive: true,
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

    final imageUrl = effectiveImagePath != null 
        ? "https://image.tmdb.org/t/p/w500$effectiveImagePath" 
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
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: SizedBox(
          width: 280,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Scalable Card Content
              AnimatedScale(
                scale: _isHovered ? 1.02 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: GestureDetector(
                  onTap: widget.onTap,
                  onLongPress: () => _showContextActions(context),
                  onSecondaryTapDown: (_) => _showContextActions(context),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Backdrop Image
                      AspectRatio(
                        aspectRatio: 16 / 9,
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
                              // Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imageUrl != null
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        color: Colors.black.withValues(alpha: 0.2),
                                        colorBlendMode: BlendMode.darken,
                                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                                      )
                                    : _buildPlaceholder(),
                              ),
                              
                              // Play Icon
                              Center(
                                child: AnimatedScale(
                                  scale: _isHovered ? 1.1 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.play_circle_outline, 
                                    color: _isHovered ? AppTheme.accent : Colors.white.withValues(alpha: 0.8), 
                                    size: 48,
                                  ),
                                ),
                              ),
                              
                              // Info Badge
                              if (widget.infoText != null)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    child: Text(
                                      widget.infoText!,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                                    minHeight: 4,
                                  ),
                                ),
                              
                              // Border Overlay
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Title
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: _isHovered ? AppTheme.accent : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Context Menu Button (More Options)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Builder(
                    builder: (context) {
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                                size: 16,
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
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.surface.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined, color: Colors.white.withValues(alpha: 0.2), size: 40),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
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
