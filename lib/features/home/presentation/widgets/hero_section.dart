import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class HeroSection extends StatelessWidget {
  final Map<String, dynamic>? media;

  const HeroSection({super.key, this.media});

  @override
  Widget build(BuildContext context) {
    if (media == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    final backdrop = media!['backdrop_path'];
    final imageUrl = backdrop != null ? "https://image.tmdb.org/t/p/original$backdrop" : null;
    final title = media!['title'] ?? media!['name'] ?? 'Unknown';
    final overview = media!['overview'] ?? '';

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75, // 75% of screen height
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          if (imageUrl != null)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.surface),
            )
          else
            Container(color: AppTheme.surface),

          // Gradient Overlay (Left + Bottom)
          // We combine them or layer them.
          
          // Left to Right (Primary -> Transparent)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppTheme.primary, // Fully opaque on the left
                  Color(0x660f0518), // ~40% opacity
                  Colors.transparent,
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Bottom to Top (Primary -> Transparent)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppTheme.primary,
                  AppTheme.primary, // Reinforced solid bottom
                  Color(0x990f0518), // ~60% opacity
                  Colors.transparent,
                ],
                stops: [0.0, 0.05, 0.3, 1.0],
              ),
            ),
          ),

          // Bottom Seal (prevents hairline backdrop leaks during scrolling)
          Positioned(
            bottom: -1,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              color: AppTheme.primary,
            ),
          ),

          // Content Layer
          Positioned(
            left: AppTheme.getResponsiveHorizontalPadding(context),
            bottom: 80, // Slightly higher to accommodate negative margin of content below
            right: AppTheme.getResponsiveHorizontalPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // "FEATURED" Tag
                Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
                    ),
                   child: Text(
                    l10n.commonFeatured,
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // Description
                SizedBox(
                  width: 600,
                  child: Text(
                    overview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                FocusTraversalGroup(
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                           Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (_) => VideoPlayerScreen(
                                  queryId: media!['id'].toString(), 
                                  type: media!['media_type'] ?? 'movie',
                                ),
                              ),
                            );
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: Text(l10n.detailsPlayNow),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                          textStyle: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 10,
                          shadowColor: AppTheme.accent.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                           Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MediaDetailsScreen(
                                  mediaId: media!['id'].toString(), 
                                  mediaType: media!['media_type'] ?? 'movie',
                                ),
                              ),
                            );
                        },
                        icon: const Icon(Icons.info_outline_rounded, size: 28),
                        label: Text(l10n.homeMoreInfo),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                          textStyle: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
