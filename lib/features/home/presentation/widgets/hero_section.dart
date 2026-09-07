import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';

class HeroSection extends StatefulWidget {
  final List<MediaItem> items;

  HeroSection({
    super.key,
    List<MediaItem>? items,
    MediaItem? media,
  }) : items = items ?? (media != null ? [media] : const []);

  /// Responsive hero height: 46% of screen height on mobile, 75% on desktop/TV.
  static double getHeroHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 600;
    return isMobile ? size.height * 0.46 : size.height * 0.75;
  }

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isAutoPlayEnabled = true;
  Timer? _autoPlayTimer;

  static const Duration _autoPlayDuration = Duration(seconds: 7);
  static const Duration _pageTransitionDuration = Duration(milliseconds: 650);
  static const Curve _pageTransitionCurve = Curves.easeInOutCubic;

  static const int _infiniteMultiplier = 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialPage = _getInitialPage();
    _pageController = PageController(initialPage: initialPage);
    _currentIndex = 0;
    _startAutoPlayTimer();
  }

  int _getInitialPage() {
    if (widget.items.length <= 1) return 0;
    // Always start centered in the infinite page space
    const half = (_infiniteMultiplier ~/ 2);
    return half * widget.items.length;
  }

  @override
  void didUpdateWidget(covariant HeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _currentIndex = 0;
      final targetPage = _getInitialPage();

      // If initial items were empty, the controller was created with initialPage: 0.
      // Recreate controller with targetPage so left scrolling works immediately.
      if (oldWidget.items.isEmpty && widget.items.isNotEmpty) {
        _pageController.dispose();
        _pageController = PageController(initialPage: targetPage);
      } else if (_pageController.hasClients) {
        _pageController.jumpToPage(targetPage);
      }
      _resetAutoPlayTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isAutoPlayEnabled) {
        _startAutoPlayTimer();
      }
    } else {
      _stopAutoPlayTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoPlayTimer();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlayTimer() {
    if (!_isAutoPlayEnabled || widget.items.length <= 1) return;
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(_autoPlayDuration, (_) => _advanceToNextPage());
  }

  void _stopAutoPlayTimer() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  void _resetAutoPlayTimer() {
    _stopAutoPlayTimer();
    _startAutoPlayTimer();
  }

  void _advanceToNextPage() {
    if (!mounted || widget.items.length <= 1 || !_pageController.hasClients) return;
    final nextPage = (_pageController.page?.round() ?? _currentIndex) + 1;
    _pageController.animateToPage(
      nextPage,
      duration: _pageTransitionDuration,
      curve: _pageTransitionCurve,
    );
  }

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlayEnabled = !_isAutoPlayEnabled;
      if (_isAutoPlayEnabled) {
        _startAutoPlayTimer();
      } else {
        _stopAutoPlayTimer();
      }
    });
  }

  void _onPageChanged(int page) {
    if (widget.items.isEmpty) return;
    final realIndex = page % widget.items.length;
    setState(() {
      _currentIndex = realIndex;
    });
    if (_isAutoPlayEnabled) {
      _resetAutoPlayTimer();
    }

    // Pre-cache next backdrop image to ensure butter-smooth transitions
    if (widget.items.length > 1) {
      final nextIdx = (realIndex + 1) % widget.items.length;
      final nextBackdrop = widget.items[nextIdx].backdropPath;
      final nextUrl = TmdbImageHelper.backdropUrl(context, nextBackdrop);
      if (nextUrl != null) {
        precacheImage(CachedNetworkImageProvider(nextUrl), context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final heroHeight = HeroSection.getHeroHeight(context);
    final l10n = AppLocalizations.of(context)!;
    final hasMultipleItems = widget.items.length > 1;
    final itemCount = hasMultipleItems
        ? widget.items.length * _infiniteMultiplier
        : widget.items.length;

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Carousel Pages
          PageView.builder(
            controller: _pageController,
            itemCount: itemCount,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final item = widget.items[index % widget.items.length];
              return _buildSlide(
                context,
                item,
                isMobile,
                heroHeight,
              );
            },
          ),

          // 2. Bottom Seal (prevents hairline backdrop leaks during scrolling)
          _buildBottomSeal(),

          // 3. Carousel Controls (Indicators + Pause/Play Toggle)
          if (widget.items.length > 1)
            Positioned(
              right: AppTheme.getResponsiveHorizontalPadding(context),
              bottom: isMobile ? 36 : 40,
              child: _buildControlsRow(l10n, widget.items.length, isMobile),
            ),
        ],
      ),
    );
  }

  Widget _buildSlide(
    BuildContext context,
    MediaItem item,
    bool isMobile,
    double heroHeight,
  ) {
    final backdrop = item.backdropPath;
    final imageUrl = TmdbImageHelper.backdropUrl(context, backdrop);

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackgroundImage(context, imageUrl, heroHeight),
        ..._buildGradients(isMobile),
        Positioned(
          left: AppTheme.getResponsiveHorizontalPadding(context),
          bottom: isMobile ? 36 : 80,
          right: isMobile ? 90 : 160, // Leave room for indicators on the right
          child: _buildContent(context, item, isMobile),
        ),
      ],
    );
  }

  Widget _buildBackgroundImage(
    BuildContext context,
    String? imageUrl,
    double heroHeight,
  ) {
    if (imageUrl != null) {
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final cacheHeight = (heroHeight * pixelRatio).round();

      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        memCacheHeight: cacheHeight,
        placeholder: (context, url) => Container(color: AppTheme.surface),
        errorWidget: (context, url, error) => Container(color: AppTheme.surface),
      );
    }
    return Container(color: AppTheme.surface);
  }

  List<Widget> _buildGradients(bool isMobile) {
    return [
      // Left to Right (Primary -> Transparent)
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppTheme.primary,
              AppTheme.primary.withValues(alpha: isMobile ? 0.35 : 0.4),
              Colors.transparent,
            ],
            stops: isMobile ? const [0.0, 0.3, 0.85] : const [0.0, 0.4, 1.0],
          ),
        ),
      ),

      // Bottom to Top (Primary -> Transparent)
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppTheme.primary,
              AppTheme.primary,
              AppTheme.primary.withValues(alpha: isMobile ? 0.45 : 0.6),
              Colors.transparent,
            ],
            stops: isMobile
                ? const [0.0, 0.08, 0.35, 1.0]
                : const [0.0, 0.05, 0.3, 1.0],
          ),
        ),
      ),
    ];
  }

  Widget _buildBottomSeal() {
    return Positioned(
      bottom: -1,
      left: 0,
      right: 0,
      child: Container(height: 2, color: AppTheme.primary),
    );
  }

  Widget _buildControlsRow(
    AppLocalizations l10n,
    int total,
    bool isMobile,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildIndicators(total, isMobile),
        const SizedBox(width: 4),
        _buildAutoPlayToggleButton(l10n, isMobile),
      ],
    );
  }

  Widget _buildAutoPlayToggleButton(AppLocalizations l10n, bool isMobile) {
    final tooltip = _isAutoPlayEnabled
        ? l10n.homeHeroPauseCarousel
        : l10n.homeHeroResumeCarousel;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleAutoPlay,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              _isAutoPlayEnabled
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white.withValues(alpha: 0.8),
              size: isMobile ? 20 : 22,
              shadows: const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicators(int total, bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final isActive = index == _currentIndex;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!_pageController.hasClients) return;
            int targetPage = index;
            if (total > 1) {
              final currentPage = _pageController.page?.round() ?? _currentIndex;
              final currentCycle = currentPage ~/ total;
              targetPage = (currentCycle * total) + index;
            }
            _pageController.animateToPage(
              targetPage,
              duration: _pageTransitionDuration,
              curve: _pageTransitionCurve,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? (isMobile ? 18 : 24) : (isMobile ? 6 : 8),
              height: isMobile ? 5 : 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: isActive
                    ? AppTheme.accent
                    : Colors.white.withValues(alpha: 0.4),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.7),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 4,
                        ),
                      ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContent(BuildContext context, MediaItem item, bool isMobile) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final title = item.getLocalizedTitle(locale.languageCode) ?? 'Unknown';
    final overview = item.overview ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFeaturedTag(l10n, isMobile),
        SizedBox(height: isMobile ? 8 : 16),
        _buildTitle(title, isMobile),
        if (!isMobile) ...[
          const SizedBox(height: 16),
          _buildOverview(context, overview),
        ],
        SizedBox(height: isMobile ? 16 : 32),
        _buildActionButtons(context, item, l10n, isMobile),
      ],
    );
  }

  Widget _buildFeaturedTag(AppLocalizations l10n, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        l10n.commonFeatured,
        style: TextStyle(
          color: AppTheme.accent,
          fontWeight: FontWeight.bold,
          letterSpacing: isMobile ? 1.5 : 2,
          fontSize: isMobile ? 10 : 12,
        ),
      ),
    );
  }

  Widget _buildTitle(String title, bool isMobile) {
    final style = isMobile
        ? const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: AppTheme.textWhite,
          )
        : DesktopTypography.heroTitle;

    return Text(
      title,
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildOverview(BuildContext context, String overview) {
    return SizedBox(
      width: 600,
      child: Text(
        overview,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.5,
              letterSpacing: 0.0,
            ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    MediaItem item,
    AppLocalizations l10n,
    bool isMobile,
  ) {
    if (isMobile) {
      return _buildMobileActionButtons(context, item, l10n);
    }
    return _buildDesktopActionButtons(context, item, l10n);
  }

  Widget _buildMobileActionButtons(
    BuildContext context,
    MediaItem item,
    AppLocalizations l10n,
  ) {
    return FocusTraversalGroup(
      child: Row(
        children: [
          // Prominent Capsule Play Button
          ElevatedButton.icon(
            onPressed: () => _navigateToPlayer(context, item),
            icon: const Icon(
              Icons.play_arrow_rounded,
              size: 24,
            ),
            label: Text(l10n.detailsPlayNow),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 12,
              ),
              textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
              shape: const StadiumBorder(),
              elevation: 8,
              shadowColor: AppTheme.accent.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 14),

          // Sleek Circular Glass Info Button
          Tooltip(
            message: l10n.homeMoreInfo,
            child: InkWell(
              onTap: () => _navigateToDetails(context, item),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopActionButtons(
    BuildContext context,
    MediaItem item,
    AppLocalizations l10n,
  ) {
    return FocusTraversalGroup(
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () => _navigateToPlayer(context, item),
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: Text(l10n.detailsPlayNow),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 20,
              ),
              textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 10,
              shadowColor: AppTheme.accent.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: () => _navigateToDetails(context, item),
            icon: const Icon(Icons.info_outline_rounded, size: 28),
            label: Text(l10n.homeMoreInfo),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 20,
              ),
              textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPlayer(BuildContext context, MediaItem item) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          queryId: item.tmdbId.toString(),
          type: item.mediaType.name,
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context, MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaDetailsScreen(
          mediaId: item.tmdbId.toString(),
          mediaType: item.mediaType.name,
        ),
      ),
    );
  }
}
