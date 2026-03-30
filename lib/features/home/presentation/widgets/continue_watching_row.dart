import 'dart:async';
import 'dart:ui';
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
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';

class ContinueWatchingRow extends ConsumerStatefulWidget {
  const ContinueWatchingRow({super.key});

  @override
  ConsumerState<ContinueWatchingRow> createState() => _ContinueWatchingRowState();
}

class _ContinueWatchingRowState extends ConsumerState<ContinueWatchingRow> {
  // Map of tmdbId -> {item, timer} to support multiple simultaneous removals
  final Map<int, ({WatchHistory item, Timer timer})> _pendingRemovals = {};
  
  // Set of tmdbId that have been finalized but not yet reflected in the provider's data.
  // This prevents the "reappearing" bug when the undo timer elapses.
  final Set<int> _flushingRemovals = {};
  
  // List of tmdbId in order of removal to manage the stack UI
  final List<int> _activeToastIds = [];

  OverlayEntry? _undoOverlay;

  void _onRemove(WatchHistory item) {
    setState(() {
      // If there's already a timer for this item, cancel it before replacing
      _pendingRemovals[item.tmdbId]?.timer.cancel();

      final timer = Timer(const Duration(seconds: 5), () {
        _finalizeRemoval(item.tmdbId);
      });

      _pendingRemovals[item.tmdbId] = (item: item, timer: timer);
      
      // Add to toast list if not already there
      if (!_activeToastIds.contains(item.tmdbId)) {
        _activeToastIds.add(item.tmdbId);
      }
    });

    _updateUndoOverlay();
  }

  void _updateUndoOverlay() {
    if (_activeToastIds.isEmpty) {
      _hideOverlay();
      return;
    }

    if (_undoOverlay == null) {
      _undoOverlay = OverlayEntry(
        builder: (context) => _UndoStack(
          ids: _activeToastIds,
          pendingRemovals: _pendingRemovals,
          onUndo: _onUndo,
        ),
      );
      Overlay.of(context).insert(_undoOverlay!);
    } else {
      _undoOverlay?.markNeedsBuild();
    }
  }

  void _hideOverlay() {
    _undoOverlay?.remove();
    _undoOverlay = null;
  }

  Future<void> _finalizeRemoval(int tmdbId) async {
    final pending = _pendingRemovals[tmdbId];
    if (pending == null) return;

    setState(() {
      _pendingRemovals.remove(tmdbId);
      _flushingRemovals.add(tmdbId);
      _activeToastIds.remove(tmdbId);
    });

    // Refresh overlay to reflect removed toast
    _updateUndoOverlay();

    final user = ref.read(authProvider).value;
    if (user != null) {
      try {
        await ref.read(watchHistoryRepositoryProvider).removeFromContinueWatching(user.id, tmdbId);
        
        // Wait a bit for the provider to update before clearing the flushing state
        // This ensures the item doesn't "reappear" if the database update is slightly delayed
        await Future.delayed(const Duration(milliseconds: 500));
      } finally {
        if (mounted) {
          setState(() {
            _flushingRemovals.remove(tmdbId);
          });
        }
      }
    } else {
       if (mounted) {
          setState(() {
            _flushingRemovals.remove(tmdbId);
          });
       }
    }
  }

  void _onUndo(int tmdbId) {
    final pending = _pendingRemovals[tmdbId];
    if (pending != null) {
      pending.timer.cancel();
      setState(() {
        _pendingRemovals.remove(tmdbId);
        _activeToastIds.remove(tmdbId);
      });
      _updateUndoOverlay();
    }
  }

  @override
  void dispose() {
    for (final pending in _pendingRemovals.values) {
      pending.timer.cancel();
    }
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(continueWatchingProvider);
    final l10n = AppLocalizations.of(context)!;

    // If we have some data, but everything is currently being "flushed" or "pended",
    // we want to maintain the column structure but potentially return SizedBox.shrink() 
    // if the list becomes empty.

    // We want to avoid the "blink" when the provider refreshes.
    // We use .when only for initial load/error if no data is present.
    if (historyAsync.hasError && !historyAsync.hasValue) {
       final mapped = ref.read(errorMapperProvider).map(historyAsync.error!);
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
    }

    if (historyAsync.isLoading && !historyAsync.hasValue) {
      return const ContinueWatchingSkeleton();
    }

    final items = historyAsync.value ?? [];
    
    // Filter out locally pending or flushing removals
    final effectiveItems = items.where((i) {
      return !_pendingRemovals.containsKey(i.tmdbId) && !_flushingRemovals.contains(i.tmdbId);
    }).toList();
    
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
                l10n.homeContinueWatching,
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
          height: 200,
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
              final appLanguage = ref.watch(settingsProvider).appLanguage;
              final title = media?.getLocalizedTitle(appLanguage) ?? 'Loading metadata...';
              final percentage = (historyItem.totalDuration != null && historyItem.totalDuration! > 0)
                  ? (historyItem.progressSeconds / historyItem.totalDuration!)
                  : 0.0;
              
              final backdrop = media?.backdropPath;
              
              return BackdropCard(
                key: ValueKey(historyItem.tmdbId),
                title: title,
                backdropPath: backdrop,
                posterPath: media?.posterPath,
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

  const _SkeletonBox({
    required this.width,
    required this.height,
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
            color: Colors.white.withValues(alpha: _opacityAnimation.value),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}

class _UndoStack extends ConsumerWidget {
  final List<int> ids;
  final Map<int, ({WatchHistory item, Timer timer})> pendingRemovals;
  final Function(int) onUndo;

  const _UndoStack({
    required this.ids,
    required this.pendingRemovals,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLanguage = ref.watch(settingsProvider).appLanguage;
    return Stack(
      children: ids.map((id) {
        final index = ids.indexOf(id);
        final pending = pendingRemovals[id];
        if (pending == null) return const SizedBox.shrink();
        
        // Calculate bottom position based on index in list.
        // Newest is at the end of the list, should be at bottom (32).
        // Reduced gap for a tighter feel (offset 64).
        final bottomOffset = 32.0 + (ids.length - 1 - index) * 64.0;

        return AnimatedPositioned(
          key: ValueKey('undo_pos_$id'),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          bottom: bottomOffset,
          right: 32,
          child: _UndoToast(
            key: ValueKey('undo_item_$id'),
            title: pending.item.media?.getLocalizedTitle(appLanguage) ?? 'Item',
            onUndo: () => onUndo(id),
          ),
        );
      }).toList(),
    );
  }
}

class _UndoToast extends StatefulWidget {
  final String title;
  final VoidCallback onUndo;

  const _UndoToast({
    super.key,
    required this.title,
    required this.onUndo,
  });

  @override
  State<_UndoToast> createState() => _UndoToastState();
}

class _UndoToastState extends State<_UndoToast> with SingleTickerProviderStateMixin {
  late AnimationController _countdownController;

  @override
  void initState() {
    super.initState();
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();
  }

  @override
  void dispose() {
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(40 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    blurRadius: 15,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete_sweep_rounded, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    l10n.homeRemovedFromContinueWatching(widget.title),
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: AnimatedBuilder(
                          animation: _countdownController,
                          builder: (context, child) {
                            return CircularProgressIndicator(
                              value: 1.0 - _countdownController.value,
                              strokeWidth: 2,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                            );
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onUndo,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: const CircleBorder(),
                        ),
                        child: Text(
                          "UNDO",
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

