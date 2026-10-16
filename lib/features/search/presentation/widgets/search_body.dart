import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/features/search/application/search_provider.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:cinemuse_app/features/search/presentation/widgets/search_history_list.dart';
import 'package:cinemuse_app/features/search/presentation/widgets/search_results_grid.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/error_view_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// What shows under the search box: offline box, history, error,
/// "no results" or the results grid.
class SearchBody extends ConsumerWidget {
  final bool hasQuery;
  final bool isOffline;
  final ScrollController scrollController;
  final FocusNode firstContentFocusNode;
  final FocusNode clearHistoryFocusNode;
  final VoidCallback onFocusInput;
  final ValueChanged<Map<String, dynamic>> onMediaTap;
  final ValueChanged<String> onHistoryItemTap;

  const SearchBody({
    super.key,
    required this.hasQuery,
    required this.isOffline,
    required this.scrollController,
    required this.firstContentFocusNode,
    required this.clearHistoryFocusNode,
    required this.onFocusInput,
    required this.onMediaTap,
    required this.onHistoryItemTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    if (isOffline) {
      return ErrorViewState(
        error: UserFriendlyError(
          message: l10n.offlineScreenMessage,
          title: l10n.offlineScreenTitle,
          kind: ErrorKind.network,
        ),
        // Checks the connection again; the screen updates when it's back.
        onRetry: () => ref.invalidate(connectivityProvider),
      );
    }

    if (!hasQuery) {
      return SearchHistoryList(
        history: state.searchHistory,
        firstItemFocusNode: firstContentFocusNode,
        clearAllFocusNode: clearHistoryFocusNode,
        onFocusInput: onFocusInput,
        onSelect: onHistoryItemTap,
        onRemove: notifier.removeFromHistory,
        onClearAll: notifier.clearHistory,
      );
    }

    if (state.status == SearchStatus.error) {
      final message = state.errorMessage ?? l10n.commonUnexpectedError;
      return ErrorViewState(
        error: UserFriendlyError(message: message),
        onRetry: () => notifier.search(state.query),
      );
    }

    if (state.status == SearchStatus.noResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.search, size: 48, color: Colors.white12),
            const SizedBox(height: 16),
            Text(
              l10n.searchNoResults(state.query),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SearchResultsGrid(
      results: state.results,
      hasMore: state.hasMore,
      scrollController: scrollController,
      firstItemFocusNode: firstContentFocusNode,
      onUpFromTopRow: onFocusInput,
      onItemTap: onMediaTap,
    );
  }
}
