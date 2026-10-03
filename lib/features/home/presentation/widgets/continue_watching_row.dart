import 'dart:async';
import 'dart:developer' as developer;
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/skeleton_box.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:cinemuse_app/shared/widgets/carousels/carousel_layout_calculator.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/continue_watching_card.dart';

class ContinueWatchingRow extends ConsumerStatefulWidget {
  const ContinueWatchingRow({super.key});

  @override
  ConsumerState<ContinueWatchingRow> createState() =>
      _ContinueWatchingRowState();
}

class _ContinueWatchingRowState extends ConsumerState<ContinueWatchingRow> {
  // Set of tmdbId that are hidden because they are pending removal or being removed.
  final Set<int> _hiddenItems = {};

  Future<void> _runWithOptimisticHide(
    int tmdbId,
    Future<void> Function(String userId) action,
  ) async {
    setState(() => _hiddenItems.add(tmdbId));
    try {
      final userId = ref.read(authProvider).value?.id;
      if (userId != null) {
        await action(userId);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e, st) {
      developer.log(
        'Failed optimistic action for item $tmdbId',
        name: 'ContinueWatchingRow',
        error: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) {
        setState(() => _hiddenItems.remove(tmdbId));
      }
    }
  }

  void _onCancelRewatch(WatchHistory item) {
    _runWithOptimisticHide(
      item.tmdbId,
      (userId) => ref.read(watchHistoryRepositoryProvider).cancelRewatch(
            userId,
            item.tmdbId,
            item.mediaType.name,
          ),
    );
  }

  void _onDrop(WatchHistory item) {
    _runWithOptimisticHide(item.tmdbId, (userId) async {
      await ref
          .read(watchHistoryRepositoryProvider)
          .dropFromContinueWatching(userId, item.tmdbId);
      ref.invalidate(droppedListProvider);
      ref.invalidate(continueWatchingProvider);
    });
  }

  void _onClearProgress(WatchHistory item) async {
    final tmdbId = item.tmdbId;
    final authState = ref.read(authProvider);
    final repository = ref.read(watchHistoryRepositoryProvider);
    final userId = authState.value?.id;

    if (userId != null) {
      try {
        await repository.clearProgress(
          userId: userId,
          tmdbId: tmdbId,
          mediaType: item.mediaType.name,
        );
        ref.invalidate(continueWatchingProvider);
      } catch (e, st) {
        developer.log(
          'Failed to clear progress for item $tmdbId',
          name: 'ContinueWatchingRow',
          error: e,
          stackTrace: st,
        );
      }
    }
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
        child: ErrorCard(message: mapped.message, type: mapped.type),
      );
    }

    if (historyAsync.isLoading && !historyAsync.hasValue) {
      return const ContinueWatchingSkeleton();
    }

    final items = historyAsync.value ?? [];

    // Filter out locally hidden items
    final effectiveItems = items.where((i) {
      return !_hiddenItems.contains(i.tmdbId);
    }).toList();

    if (effectiveItems.isEmpty) return const SizedBox.shrink();

    final horizontalPadding = AppTheme.getResponsiveHorizontalPadding(context);
    final dimensions = CarouselLayoutCalculator.getBackdropDimensions(
      context,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
    );

    return GenericCarouselRow(
      theme: CarouselTheme.homeRow,
      title: l10n.homeContinueWatching,
      height: dimensions.height,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      itemCount: effectiveItems.length,
      separatorBuilder: (c, i) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final historyItem = effectiveItems[index];
        return ContinueWatchingCard(
          historyItem: historyItem,
          width: dimensions.itemWidth,
          onDrop: () => _onDrop(historyItem),
          onCancelRewatch: () => _onCancelRewatch(historyItem),
          onClearProgress: () => _onClearProgress(historyItem),
        );
      },
    );
  }
}

class ContinueWatchingSkeleton extends StatelessWidget {
  const ContinueWatchingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppTheme.getResponsiveHorizontalPadding(context);
    final dimensions = CarouselLayoutCalculator.getBackdropDimensions(
      context,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            16,
          ),
          child: const SkeletonBox(width: 180, height: 25),
        ),
        GenericCarouselRow(
          theme: CarouselTheme.plain,
          height: dimensions.height,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(
                width: dimensions.itemWidth,
                height: dimensions.itemWidth * (9 / 16),
              ),
              const SizedBox(height: 10),
              SkeletonBox(width: dimensions.itemWidth * 0.55, height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
