import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class GalleryBottomSheet extends StatelessWidget {
  final List<String> backdrops;
  final List<String> posters;
  final List<String> logos;
  final int initialTabIndex;

  const GalleryBottomSheet({
    super.key,
    required this.backdrops,
    required this.posters,
    required this.logos,
    required this.initialTabIndex,
  });

  /// Static helper to launch the bottom sheet
  static void show({
    required BuildContext context,
    required List<String> backdrops,
    required List<String> posters,
    required List<String> logos,
    required int initialTabIndex,
  }) {
    AppBottomSheet.show(
      context: context,
      heightFactor: 0.85,
      child: AppBottomSheet(
        blurSigma: 10.0,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.95),
        showHandle: true,
        padding: const EdgeInsets.only(top: 8),
        child: GalleryBottomSheet(
          backdrops: backdrops,
          posters: posters,
          logos: logos,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  String _getImageUrl(String path, String size) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  void _openFullscreenViewer(
    BuildContext context,
    List<String> items,
    int initialIndex,
  ) {
    final urls = items.map((item) => _getImageUrl(item, 'original')).toList();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: AppTheme.primary.withValues(alpha: 0.95),
        pageBuilder: (context, _, __) => FullscreenImageViewer(
          imageUrls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppTheme.accent,
            labelColor: AppTheme.textWhite,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: l10n.detailsBackdrops),
              Tab(text: l10n.detailsPosters),
              Tab(text: l10n.detailsLogos),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: [
                _buildGrid(
                  context: context,
                  items: backdrops,
                  crossAxisCount: 2,
                  aspectRatio: 16 / 9,
                  previewSize: 'w780',
                  memCacheWidth: 780,
                ),
                _buildGrid(
                  context: context,
                  items: posters,
                  crossAxisCount: 3,
                  aspectRatio: 2 / 3,
                  previewSize: 'w500',
                  memCacheWidth: 500,
                ),
                _buildLogoGrid(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid({
    required BuildContext context,
    required List<String> items,
    required int crossAxisCount,
    required double aspectRatio,
    required String previewSize,
    required int memCacheWidth,
  }) {
    if (items.isEmpty) {
      return _buildEmptyState(context);
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final url = _getImageUrl(items[index], previewSize);
        return GestureDetector(
          onTap: () => _openFullscreenViewer(context, items, index),
          child: ClipRRect(
            borderRadius: AppTheme.radiusMd,
            child: CachedNetworkImage(
              imageUrl: url,
              memCacheWidth: memCacheWidth,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppTheme.secondary.withValues(alpha: 0.5),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.secondary.withValues(alpha: 0.5),
                child: Icon(
                  Icons.broken_image,
                  color: AppTheme.textWhite.withValues(alpha: 0.24),
                  size: 24,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoGrid(BuildContext context) {
    if (logos.isEmpty) {
      return _buildEmptyState(context);
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: logos.length,
      itemBuilder: (context, index) {
        final url = _getImageUrl(logos[index], 'w500');
        return GestureDetector(
          onTap: () => _openFullscreenViewer(context, logos, index),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.3),
              borderRadius: AppTheme.radiusMd,
              border: Border.all(
                color: AppTheme.textWhite.withValues(alpha: 0.05),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                memCacheWidth: 400,
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accent,
                  ),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.broken_image,
                  color: AppTheme.textWhite.withValues(alpha: 0.24),
                  size: 24,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            color: AppTheme.textMuted,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.detailsNoImages,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
