import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

class HeroSection extends ConsumerStatefulWidget {
  final List<MediaItem> items;
  final FocusNode? focusNode;

  HeroSection({
    super.key,
    List<MediaItem>? items,
    MediaItem? media,
    this.focusNode,
  }) : items = items ?? (media != null ? [media] : const []);

  /// Responsive hero height: 46% of screen height on mobile, 75% on desktop/TV.
  static double getHeroHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 600;
    return isMobile ? size.height * 0.46 : size.height * 0.75;
  }

  @override
  ConsumerState<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends ConsumerState<HeroSection>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isAutoPlayEnabled = true;
  bool _isHeroFocused = false;
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

  void _goToPreviousPage() {
    if (!mounted || widget.items.length <= 1 || !_pageController.hasClients) return;
    final prevPage = (_pageController.page?.round() ?? _currentIndex) - 1;
    _pageController.animateToPage(
      prevPage,
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

  void _onIndicatorTap(int index, int total) {
    if (!_pageController.hasClients || index == _currentIndex) return;
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
    if (_isAutoPlayEnabled) {
      _resetAutoPlayTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final isWidescreen = !isMobile;
    final heroHeight = HeroSection.getHeroHeight(context);
    final l10n = AppLocalizations.of(context)!;
    final hasMultipleItems = widget.items.length > 1;
    final itemCount = hasMultipleItems
        ? widget.items.length * _infiniteMultiplier
        : widget.items.length;

    Widget carousel = SizedBox(
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
                isWidescreen,
                heroHeight,
              );
            },
          ),

          // 2. Bottom Seal (prevents hairline backdrop leaks during scrolling)
          _buildBottomSeal(context),

          // 3. Carousel Controls (Indicators + Pause/Play Toggle)
          if (widget.items.length > 1)
            Positioned(
              right: AppTheme.getResponsiveHorizontalPadding(context),
              bottom: isMobile ? 48 : 84,
              child: _buildControlsRow(l10n, widget.items.length, isMobile, isWidescreen),
            ),
        ],
      ),
    );

    if (isWidescreen) {
      final currentItem = widget.items.isNotEmpty
          ? widget.items[_currentIndex % widget.items.length]
          : null;

      return DpadFocusable(
        focusNode: widget.focusNode,
        onTap: currentItem != null
            ? () => _navigateToDetails(context, currentItem)
            : null,
        onFocusChange: (focused) {
          setState(() => _isHeroFocused = focused);
          if (focused) {
            _stopAutoPlayTimer();
          } else {
            _startAutoPlayTimer();
          }
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            final focusNavbar = ref.read(topNavbarFocusActionProvider);
            if (focusNavbar != null) {
              focusNavbar();
              return KeyEventResult.handled;
            }
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (widget.items.length > 1) {
              _advanceToNextPage();
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (_currentIndex > 0) {
              _goToPreviousPage();
              return KeyEventResult.handled;
            } else {
              final focusRail = ref.read(tvRailFocusActionProvider);
              focusRail?.call();
              return KeyEventResult.handled;
            }
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            final moved = node.focusInDirection(TraversalDirection.down);
            if (!moved) {
              node.nextFocus();
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        scale: 1.0,
        showFocusRing: false,
        child: carousel,
      );
    }

    return carousel;
  }

  Widget _buildSlide(
    BuildContext context,
    MediaItem item,
    bool isMobile,
    bool isWidescreen,
    double heroHeight,
  ) {
    final backdrop = item.backdropPath;
    final imageUrl = TmdbImageHelper.backdropUrl(context, backdrop);

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackgroundImage(context, imageUrl, heroHeight),
        ..._buildGradients(context, isMobile),
        // Ambient dimming when hero is not focused in widescreen mode
        if (isWidescreen)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _isHeroFocused ? 0.0 : 0.4,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
            ),
          ),
        Positioned(
          left: AppTheme.getResponsiveHorizontalPadding(context),
          bottom: isMobile ? 36 : 80,
          right: isMobile ? 90 : 180, // Leave room for indicators on the right
          child: _buildContent(context, item, isMobile, isWidescreen),
        ),
      ],
    );
  }

  Widget _buildBackgroundImage(
    BuildContext context,
    String? imageUrl,
    double heroHeight,
  ) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    if (imageUrl != null) {
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final cacheHeight = (heroHeight * pixelRatio).round();

      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        memCacheHeight: cacheHeight,
        placeholder: (context, url) => Container(color: surfaceColor),
        errorWidget: (context, url, error) => Container(color: surfaceColor),
      );
    }
    return Container(color: surfaceColor);
  }

  List<Widget> _buildGradients(BuildContext context, bool isMobile) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    return [
      // Left to Right (Primary -> Transparent)
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              bgColor,
              bgColor.withValues(alpha: isMobile ? 0.35 : 0.4),
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
              bgColor,
              bgColor,
              bgColor.withValues(alpha: isMobile ? 0.45 : 0.6),
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

  Widget _buildBottomSeal(BuildContext context) {
    return Positioned(
      bottom: -1,
      left: 0,
      right: 0,
      child: Container(
        height: 2,
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
    );
  }

  Widget _buildControlsRow(
    AppLocalizations l10n,
    int total,
    bool isMobile,
    bool isWidescreen,
  ) {
    if (isWidescreen) {
      return _buildIndicators(total, isMobile);
    }
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
        return _HeroIndicatorDot(
          isActive: index == _currentIndex,
          isMobile: isMobile,
          onTap: () => _onIndicatorTap(index, total),
        );
      }),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MediaItem item,
    bool isMobile,
    bool isWidescreen,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final title =
        item.getLocalizedTitle(locale.languageCode) ?? l10n.commonUnknown;
    final overview = item.overview ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFeaturedTag(context, l10n, isMobile),
        SizedBox(height: isMobile ? 8 : 16),
        _buildTitle(title, isMobile),
        if (!isMobile) ...[
          const SizedBox(height: 16),
          _buildOverview(context, overview),
        ],
        if (isWidescreen) ...[
          const SizedBox(height: 20),
          _buildTvInfoPill(context, l10n),
        ] else ...[
          SizedBox(height: isMobile ? 16 : 32),
          _buildActionButtons(context, item, l10n, isMobile),
        ],
      ],
    );
  }

  Widget _buildTvInfoPill(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: _isHeroFocused
            ? theme.focusColor
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isHeroFocused
              ? primary.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.15),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: _isHeroFocused ? primary : Colors.white70,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.homeMoreInfo,
            style: TextStyle(
              color: _isHeroFocused ? Colors.white : Colors.white70,
              fontSize: 15,
              fontWeight: _isHeroFocused ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedTag(
    BuildContext context,
    AppLocalizations l10n,
    bool isMobile,
  ) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: primary.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        l10n.commonFeatured,
        style: TextStyle(
          color: primary,
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
            color: Colors.white,
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

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
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 12,
              ),
              textStyle: theme.textTheme.bodyMedium!.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              shape: const StadiumBorder(),
              elevation: 6,
              shadowColor: primary.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(width: 14),

          // Sleek Circular Glass Info Button
          Tooltip(
            message: l10n.homeMoreInfo,
            child: DpadFocusable(
              onTap: () => _navigateToDetails(context, item),
              showFocusRing: false,
              child: const SizedBox.shrink(),
              builder: (context, isFocused, isHovered, _) {
                final isHighlighted = isFocused || isHovered;
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFocused
                        ? theme.focusColor
                        : (isHovered
                            ? theme.hoverColor
                            : Colors.white.withValues(alpha: 0.12)),
                    border: Border.all(
                      color: isHighlighted
                          ? primary.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.25),
                      width: 1.0,
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
                );
              },
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return FocusTraversalGroup(
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () => _navigateToPlayer(context, item),
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: Text(l10n.detailsPlayNow),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return theme.colorScheme.secondary;
                }
                return primary;
              }),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              ),
              textStyle: WidgetStatePropertyAll(
                theme.textTheme.bodyMedium!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              side: const WidgetStatePropertyAll(BorderSide.none),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              elevation: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) return 4;
                if (states.contains(WidgetState.hovered)) return 4;
                return 2;
              }),
              shadowColor: WidgetStatePropertyAll(
                primary.withValues(alpha: 0.25),
              ),
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: () => _navigateToDetails(context, item),
            icon: const Icon(Icons.info_outline_rounded, size: 28),
            label: Text(l10n.homeMoreInfo),
            style: ButtonStyle(
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused) ||
                    states.contains(WidgetState.hovered)) {
                  return BorderSide(
                    color: primary.withValues(alpha: 0.5),
                    width: 1.5,
                  );
                }
                return BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                );
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return theme.focusColor;
                }
                if (states.contains(WidgetState.hovered)) {
                  return theme.hoverColor;
                }
                return Colors.white.withValues(alpha: 0.1);
              }),
              elevation: const WidgetStatePropertyAll(0),
              shadowColor: WidgetStatePropertyAll(
                primary.withValues(alpha: 0.3),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              ),
              textStyle: WidgetStatePropertyAll(
                theme.textTheme.bodyMedium!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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

class _HeroIndicatorDot extends StatefulWidget {
  final bool isActive;
  final bool isMobile;
  final VoidCallback onTap;

  const _HeroIndicatorDot({
    required this.isActive,
    required this.isMobile,
    required this.onTap,
  });

  @override
  State<_HeroIndicatorDot> createState() => _HeroIndicatorDotState();
}

class _HeroIndicatorDotState extends State<_HeroIndicatorDot> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final width = widget.isActive
        ? (widget.isMobile ? 18.0 : 24.0)
        : (widget.isMobile ? 6.0 : (_isHovered ? 12.0 : 8.0));
    final height = widget.isMobile ? 5.0 : 6.0;

    final theme = Theme.of(context);
    final dotColor = widget.isActive
        ? theme.colorScheme.primary
        : (_isHovered
            ? Colors.white.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.4));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isMobile ? 4 : 6,
            vertical: 14,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: dotColor,
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: _isHovered ? Colors.black87 : Colors.black45,
                        blurRadius: _isHovered ? 6 : 4,
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
