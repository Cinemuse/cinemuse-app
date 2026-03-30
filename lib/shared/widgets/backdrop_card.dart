
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

  const BackdropCard({
    super.key,
    required this.title,
    this.backdropPath,
    this.posterPath,
    this.progress,
    this.infoText,
    this.onTap,
    this.onRemove,
  });

  @override
  State<BackdropCard> createState() => _BackdropCardState();
}

class _BackdropCardState extends State<BackdropCard> {
  bool _isHovered = false;
  bool _isCloseHovered = false;

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
                                color: Colors.black.withOpacity(0.5),
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
                                        color: Colors.black.withOpacity(0.2),
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
                                    color: _isHovered ? AppTheme.accent : Colors.white.withOpacity(0.8), 
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
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                                    backgroundColor: Colors.white.withOpacity(0.2),
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
                                        ? AppTheme.accent.withOpacity(0.5) 
                                        : Colors.white.withOpacity(0.1),
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

              // 2. Separate Close Button (Always positioned relative to 1.0 scale)
              if (widget.onRemove != null && _isHovered)
                Positioned(
                  top: 4,
                  right: 4,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _isCloseHovered = true),
                    onExit: (_) => setState(() => _isCloseHovered = false),
                    child: GestureDetector(
                      onTap: widget.onRemove,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isCloseHovered 
                              ? Colors.red 
                              : Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                            if (_isCloseHovered)
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 10,
                              ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
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
