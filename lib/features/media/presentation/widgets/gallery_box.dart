import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/gallery_bottom_sheet.dart';

import 'package:cinemuse_app/features/media/domain/media_item.dart';

class GalleryBox extends StatelessWidget {
  final MediaImages images;

  const GalleryBox({super.key, required this.images});

  void _openGallery(BuildContext context, int initialTabIndex) {
    GalleryBottomSheet.show(
      context: context,
      backdrops: images.backdrops,
      posters: images.posters,
      logos: images.logos,
      initialTabIndex: initialTabIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final backdrops = images.backdrops;
    final posters = images.posters;
    final logos = images.logos;

    if (backdrops.isEmpty && posters.isEmpty && logos.isEmpty) {
      return const SizedBox.shrink();
    }

    return BentoBox(
      title: l10n.detailsGallery,
      icon: Icons.image_outlined,
      action: HoverScale(
        tooltip: l10n.detailsGallery,
        onTap: () => _openGallery(context, 0),
        showFocusRing: true,
        borderRadius: AppTheme.radiusMd,
        child: const Padding(
          padding: EdgeInsets.all(4.0),
          child: Icon(Icons.chevron_right, color: AppTheme.accent, size: 20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.detailsGallerySubtitle,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
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
    return HoverScale(
      onTap: onTap,
      showFocusRing: true,
      borderRadius: AppTheme.radius12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.secondary.withValues(alpha: 0.5),
          borderRadius: AppTheme.radius12,
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.1)),
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
    );
  }
}
