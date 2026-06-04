import 'dart:async';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/shared/widgets/skeleton_box.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/cards/continue_watching_card.dart';

class ContinueWatchingRow extends ConsumerStatefulWidget {
  const ContinueWatchingRow({super.key});

  @override
  ConsumerState<ContinueWatchingRow> createState() => _ContinueWatchingRowState();
}

class _ContinueWatchingRowState extends ConsumerState<ContinueWatchingRow> {
  // Set of tmdbId that are hidden because they are pending removal or being removed.
  final Set<int> _hiddenItems = {};

  void _onRemove(WatchHistory item) async {
    final tmdbId = item.tmdbId;
    setState(() {
      _hiddenItems.add(tmdbId);
    });

    final l10n = AppLocalizations.of(context)!;
    final appLanguage = ref.read(settingsProvider).appLanguage;
    final title = item.media?.getLocalizedTitle(appLanguage) ?? 'Item';
    
    // Read the providers needed for finalization now
    final authState = ref.read(authProvider);
    final repository = ref.read(watchHistoryRepositoryProvider);

    final controller = AppSnackBar.show(
      context,
      message: l10n.homeRemovedFromContinueWatching(title),
      actionLabel: l10n.commonUndo.toUpperCase(),
      duration: const Duration(seconds: 5),
      showTimer: true,
      onAction: () {},
    );

    final reason = await controller.closed;
    
    if (reason == SnackBarClosedReason.action) {
      if (mounted) {
        setState(() {
          _hiddenItems.remove(tmdbId);
        });
      }
    } else {
      _finalizeRemoval(tmdbId, authState.value?.id, repository);
    }
  }

  Future<void> _finalizeRemoval(int tmdbId, String? userId, WatchHistoryRepository repository) async {
    if (userId != null) {
      try {
        await repository.removeFromContinueWatching(userId, tmdbId);
        
        // Wait a bit for the provider to update before clearing the hidden state
        // This ensures the item doesn't "reappear" if the database update is slightly delayed
        await Future.delayed(const Duration(milliseconds: 500));
      } finally {
        if (mounted) {
          setState(() {
            _hiddenItems.remove(tmdbId);
          });
        }
      }
    } else {
       if (mounted) {
          setState(() {
            _hiddenItems.remove(tmdbId);
          });
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
    final watchlistItems = ref.watch(userListsProvider).valueOrNull
        ?.where((l) => l.type == ListType.watchlist)
        .firstOrNull
        ?.items ?? [];
    
    // Filter out locally hidden items
    final effectiveItems = items.where((i) {
      return !_hiddenItems.contains(i.tmdbId);
    }).toList();
    
    if (effectiveItems.isEmpty) return const SizedBox.shrink();

    return GenericCarouselRow(
      theme: CarouselTheme.homeRow,
      title: l10n.homeContinueWatching,
      height: 216,
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.getResponsiveHorizontalPadding(context)
      ),
      itemCount: effectiveItems.length,
      separatorBuilder: (c, i) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final historyItem = effectiveItems[index];
        return ContinueWatchingCard(
          historyItem: historyItem,
          watchlistItems: watchlistItems,
          onRemove: () => _onRemove(historyItem),
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 16),
          child: const SkeletonBox(width: 180, height: 25),
        ),
        GenericCarouselRow(
          theme: CarouselTheme.plain,
          height: 216,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 280, height: 280 * (9/16)),
              const SizedBox(height: 10),
              const SkeletonBox(width: 150, height: 16),
            ],
          ),
        ),
      ],
    );
  }
}




