import 'package:cinemuse_app/features/home/application/continue_watching_service.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
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
  // Cards hidden while their action runs (`mediaType-tmdbId`).
  final Set<String> _hiddenItems = {};

  // The history stream is debounced by 300 ms: keep the card hidden until the
  // new state arrives, so it doesn't flash back.
  static const _hideUntilHistoryUpdates = Duration(milliseconds: 500);

  static String _keyOf(WatchHistory item) =>
      '${item.mediaType.name}-${item.tmdbId}';

  /// Runs [action] for [item]; on failure shows the error in a snackbar.
  /// With [hide], the card is hidden while the action runs.
  Future<void> _run(
    WatchHistory item,
    Future<void> Function(ContinueWatchingService service) action, {
    bool hide = false,
  }) async {
    final service = ref.read(continueWatchingServiceProvider);
    final errorMapper = ref.read(errorMapperProvider);
    final key = _keyOf(item);
    if (hide) setState(() => _hiddenItems.add(key));
    try {
      await action(service);
      if (hide) await Future<void>.delayed(_hideUntilHistoryUpdates);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: errorMapper.map(e).message,
          isError: true,
        );
      }
    } finally {
      if (hide && mounted) setState(() => _hiddenItems.remove(key));
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
        child: ErrorCard(error: mapped),
      );
    }

    if (historyAsync.isLoading && !historyAsync.hasValue) {
      return const ContinueWatchingSkeleton();
    }

    final items = historyAsync.value ?? [];

    final effectiveItems = items
        .where((i) => !_hiddenItems.contains(_keyOf(i)))
        .toList();

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
          onDrop: () =>
              _run(historyItem, (s) => s.drop(historyItem), hide: true),
          onCancelRewatch: () => _run(
            historyItem,
            (s) => s.cancelRewatch(historyItem),
            hide: true,
          ),
          onClearProgress: () =>
              _run(historyItem, (s) => s.clearProgress(historyItem)),
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
