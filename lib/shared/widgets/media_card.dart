
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaCard extends StatefulWidget {
  final String title;
  final String? posterPath;
  final String? releaseDate;
  final double? rating;
  final VoidCallback? onTap;

  const MediaCard({
    super.key,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.rating,
    this.onTap,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _isHovered = false;

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
          child: AnimatedScale(
            scale: _isHovered ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
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
                            color: Colors.black.withOpacity(0.5),
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
                // MetadataRow
                Row(
                  children: [
                    if (widget.rating != null && widget.rating! > 0)
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                    if (widget.rating != null && widget.rating! > 0)
                      const SizedBox(width: 4),
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
