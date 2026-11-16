import 'dart:async';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/hero/hero_controls_row.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/hero/hero_slide.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// The Home hero carousel: endless paging, auto-advance, arrow keys and
/// navigation. Each page is a [HeroSlide].
class HeroSection extends ConsumerStatefulWidget {
  final List<MediaItem> items;
  final FocusNode? focusNode;

  const HeroSection({super.key, required this.items, this.focusNode});

  /// Responsive hero height: 46% of screen height on mobile, 75% on desktop/TV.
  static double getHeroHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < Breakpoints.compact;
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
    _autoPlayTimer = Timer.periodic(
      _autoPlayDuration,
      (_) => _advanceToNextPage(),
    );
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
    if (!mounted || widget.items.length <= 1 || !_pageController.hasClients) {
      return;
    }
    final nextPage = (_pageController.page?.round() ?? _currentIndex) + 1;
    _pageController.animateToPage(
      nextPage,
      duration: _pageTransitionDuration,
      curve: _pageTransitionCurve,
    );
  }

  void _goToPreviousPage() {
    if (!mounted || widget.items.length <= 1 || !_pageController.hasClients) {
      return;
    }
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

    final isMobile = Breakpoints.isCompact(context);
    final isWidescreen = !isMobile;
    final heroHeight = HeroSection.getHeroHeight(context);
    final hasMultipleItems = widget.items.length > 1;
    final itemCount = hasMultipleItems
        ? widget.items.length * _infiniteMultiplier
        : widget.items.length;

    final Widget carousel = SizedBox(
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
              return HeroSlide(
                item: item,
                isMobile: isMobile,
                isWidescreen: isWidescreen,
                isHeroFocused: _isHeroFocused,
                heroHeight: heroHeight,
                onPlay: () => _navigateToPlayer(context, item),
                onDetails: () => _navigateToDetails(context, item),
              );
            },
          ),

          // 2. Bottom Seal (prevents hairline backdrop leaks during scrolling)
          Positioned(
            bottom: -1,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),

          // 3. Carousel Controls (Indicators + Pause/Play Toggle)
          if (widget.items.length > 1)
            Positioned(
              right: AppTheme.getResponsiveHorizontalPadding(context),
              bottom: isMobile ? 48 : 84,
              child: HeroControlsRow(
                total: widget.items.length,
                currentIndex: _currentIndex,
                isMobile: isMobile,
                isWidescreen: isWidescreen,
                isAutoPlayEnabled: _isAutoPlayEnabled,
                onDotTap: (index) =>
                    _onIndicatorTap(index, widget.items.length),
                onToggleAutoPlay: _toggleAutoPlay,
              ),
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
        onKeyEvent: _handleKeyEvent,
        scale: 1.0,
        showFocusRing: false,
        child: carousel,
      );
    }

    return carousel;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      ref.read(topNavbarFocusActionProvider)?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && widget.items.length > 1) {
      _advanceToNextPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_currentIndex > 0) _goToPreviousPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (!node.focusInDirection(TraversalDirection.down)) {
        node.nextFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
