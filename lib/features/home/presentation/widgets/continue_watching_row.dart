import 'dart:async';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/shared/widgets/backdrop_card.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';

class ContinueWatchingRow extends ConsumerStatefulWidget {
  const ContinueWatchingRow({super.key});

  @override
  ConsumerState<ContinueWatchingRow> createState() => _ContinueWatchingRowState();
}

class _ContinueWatchingRowState extends ConsumerState<ContinueWatchingRow> {
  WatchHistory? _pendingRemoval;
  Timer? _undoTimer;
  OverlayEntry? _undoOverlay;

  void _onRemove(WatchHistory item) {
    _clearUndo();

    setState(() {
      _pendingRemoval = item;
    });

    _showUndoOverlay(item);

    _undoTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _pendingRemoval?.tmdbId == item.tmdbId) {
        _finalizeRemoval();
      }
    });
  }

  void _showUndoOverlay(WatchHistory item) {
    _undoOverlay?.remove();
    _undoOverlay = OverlayEntry(
      builder: (context) => _UndoToast(
        title: item.media?.title ?? 'Item',
        onUndo: () {
          _onUndo();
        },
      ),
    );
    Overlay.of(context).insert(_undoOverlay!);
  }

  void _clearUndo() {
    _undoTimer?.cancel();
    _undoTimer = null;
    _undoOverlay?.remove();
    _undoOverlay = null;
  }

  Future<void> _finalizeRemoval() async {
    final item = _pendingRemoval;
    _clearUndo();
    
    if (mounted) {
      setState(() {
        _pendingRemoval = null;
      });
    }

    if (item != null) {
      final user = ref.read(authProvider).value;
      if (user != null) {
        await ref.read(watchHistoryRepositoryProvider).removeFromContinueWatching(user.id, item.tmdbId);
      }
    }
  }

  void _onUndo() {
    _clearUndo();
    setState(() {
      _pendingRemoval = null;
    });
  }

  @override
  void dispose() {
    _clearUndo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(continueWatchingProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: historyAsync.when(
        data: (items) {
          // Filter out locally pending removal
          final effectiveItems = items.where((i) => i.tmdbId != _pendingRemoval?.tmdbId).toList();
          
          if (effectiveItems.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.getResponsiveHorizontalPadding(context), 
                  24, 
                  AppTheme.getResponsiveHorizontalPadding(context), 
                  16
                ),
                child: Row(
                  children: [
                    Text(
                      "Continue Watching",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  ],
                ),
              ),
              
              SizedBox(
                height: 200, // Height for card + text
                child: ListView.separated(
                  clipBehavior: Clip.none,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.getResponsiveHorizontalPadding(context)
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: effectiveItems.length,
                  separatorBuilder: (c, i) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final historyItem = effectiveItems[index];
                    final media = historyItem.media;
                    final title = media?.title ?? 'Unknown';
                    final percentage = (historyItem.totalDuration != null && historyItem.totalDuration! > 0)
                        ? (historyItem.progressSeconds / historyItem.totalDuration!)
                        : 0.0;
                    
                    final backdrop = media?.backdropPath;
                    
                    return BackdropCard(
                      title: title,
                      backdropPath: backdrop,
                      progress: percentage,
                      infoText: historyItem.mediaType == MediaKind.tv 
                                ? "S${historyItem.season} E${historyItem.episode}" 
                                : "Movie",
                      onTap: () {
                         Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MediaDetailsScreen(
                            mediaId: historyItem.tmdbId.toString(), 
                            mediaType: historyItem.mediaType == MediaKind.tv ? 'tv' : 'movie',
                          ),
                        ));
                      },
                      onRemove: () => _onRemove(historyItem),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const ContinueWatchingSkeleton(),
        error: (e, s) {
          final mapped = ref.read(errorMapperProvider).map(e);
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.getResponsiveHorizontalPadding(context),
              vertical: 16,
            ),
            child: ErrorCard(
              message: mapped.message,
              type: mapped.type,
            ),
          );
        },
      ),
    );
  }
}

class ContinueWatchingSkeleton extends StatelessWidget {
  const ContinueWatchingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppTheme.getResponsiveHorizontalPadding(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 16),
          child: const _SkeletonBox(width: 180, height: 25),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 280, height: 280 * (9/16)),
                const SizedBox(height: 10),
                const _SkeletonBox(width: 150, height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.05, end: 0.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_opacityAnimation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class _UndoToast extends StatelessWidget {
  final String title;
  final VoidCallback onUndo;

  const _UndoToast({
    required this.title,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 32,
      right: 32,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 40 * (1 - value)),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_sweep, color: AppTheme.accent, size: 20),
                const SizedBox(width: 12),
                Text(
                  "Removed $title",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 20),
                TextButton(
                  onPressed: onUndo,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    "UNDO",
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
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
