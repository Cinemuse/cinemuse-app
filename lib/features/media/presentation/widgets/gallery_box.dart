import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/gallery_bottom_sheet.dart';

class GalleryBox extends StatelessWidget {
  final Map<String, dynamic>? details;

  const GalleryBox({super.key, this.details});

  void _openGallery(BuildContext context, int initialTabIndex) {
    final backdrops = (details?['images']?['backdrops'] as List?) ?? [];
    final posters = (details?['images']?['posters'] as List?) ?? [];
    final logos = (details?['images']?['logos'] as List?) ?? [];

    GalleryBottomSheet.show(
      context: context,
      backdrops: backdrops,
      posters: posters,
      logos: logos,
      initialTabIndex: initialTabIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final backdrops = (details?['images']?['backdrops'] as List?) ?? [];
    final posters = (details?['images']?['posters'] as List?) ?? [];
    final logos = (details?['images']?['logos'] as List?) ?? [];

    if (backdrops.isEmpty && posters.isEmpty && logos.isEmpty) {
      return const SizedBox.shrink();
    }

    return BentoBox(
      title: l10n.detailsGallery,
      icon: Icons.image_outlined,
      action: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _openGallery(context, 0),
          child: HoverScale(
            child: const Icon(
              Icons.chevron_right,
              color: AppTheme.accent,
              size: 20,
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.detailsGallerySubtitle,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (backdrops.isNotEmpty)
                _GalleryPill(
                  label: l10n.detailsBackdropsCount(backdrops.length),
                  icon: Icons.wallpaper_outlined,
                  onTap: () => _openGallery(context, 0),
                ),
              if (posters.isNotEmpty)
                _GalleryPill(
                  label: l10n.detailsPostersCount(posters.length),
                  icon: Icons.portrait_outlined,
                  onTap: () => _openGallery(context, 1),
                ),
              if (logos.isNotEmpty)
                _GalleryPill(
                  label: l10n.detailsLogosCount(logos.length),
                  icon: Icons.category_outlined,
                  onTap: () => _openGallery(context, 2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GalleryPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GalleryPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: HoverScale(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.border.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
