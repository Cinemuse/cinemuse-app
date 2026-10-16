import 'dart:math' as math;

import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/title_list_actions.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The search results as a grid of cards, with a spinner cell at the end
/// while more pages can load. Up from the top row goes to [onUpFromTopRow].
class SearchResultsGrid extends ConsumerWidget {
  final List<Map<String, dynamic>> results;
  final bool hasMore;
  final ScrollController scrollController;
  final FocusNode firstItemFocusNode;
  final VoidCallback onUpFromTopRow;
  final ValueChanged<Map<String, dynamic>> onItemTap;

  const SearchResultsGrid({
    super.key,
    required this.results,
    required this.hasMore,
    required this.scrollController,
    required this.firstItemFocusNode,
    required this.onUpFromTopRow,
    required this.onItemTap,
  });

  static const _padding = 16.0;
  static const _maxCardWidth = 200.0;
  static const _spacing = 16.0;

  KeyEventResult _topRowKeys(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      onUpFromTopRow();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appLanguage = ref.watch(
      settingsProvider.select((s) => s.appLanguage),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Same column count as SliverGridDelegateWithMaxCrossAxisExtent, so
        // Up leaves the grid only from the real top row (REV-61).
        final gridWidth = constraints.maxWidth - 2 * _padding;
        final columns = math.max(
          1,
          (gridWidth / (_maxCardWidth + _spacing)).ceil(),
        );
        return GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(_padding),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _maxCardWidth,
            childAspectRatio: 0.56,
            crossAxisSpacing: _spacing,
            mainAxisSpacing: 16,
          ),
          itemCount: results.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == results.length) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              );
            }

            final item = results[index];
            final focusNode = index == 0 ? firstItemFocusNode : null;
            final onKeyEvent = index < columns ? _topRowKeys : null;

            if (item['media_type'] == 'person') {
              return MediaCard(
                title: item['name'] ?? l10n.commonUnknown,
                posterPath: item['profile_path'] as String?,
                releaseDate: item['known_for_department'] as String?,
                rating: null,
                focusNode: focusNode,
                onKeyEvent: onKeyEvent,
                onTap: () => onItemTap(item),
              );
            }
            final mediaItem = MediaItem.fromTmdbMap(item);
            return MediaCard(
              title:
                  mediaItem.getLocalizedTitle(appLanguage) ??
                  l10n.commonUnknown,
              posterPath: mediaItem.posterPath,
              releaseDate: mediaItem.releaseDate?.year.toString(),
              rating: mediaItem.voteAverage,
              listActions: TitleListActions(context, ref, mediaItem),
              focusNode: focusNode,
              onKeyEvent: onKeyEvent,
              onTap: () => onItemTap(item),
            );
          },
        );
      },
    );
  }
}
