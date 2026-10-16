import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/search/presentation/widgets/search_hover_button.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// The recent searches under an empty search box, with "Clear all";
/// a hint with the film / TV / person icons when there are none.
class SearchHistoryList extends StatelessWidget {
  final List<String> history;
  final FocusNode firstItemFocusNode;
  final FocusNode clearAllFocusNode;

  /// Moves the focus back to the search box.
  final VoidCallback onFocusInput;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  const SearchHistoryList({
    super.key,
    required this.history,
    required this.firstItemFocusNode,
    required this.clearAllFocusNode,
    required this.onFocusInput,
    required this.onSelect,
    required this.onRemove,
    required this.onClearAll,
  });

  void _remove(String query) {
    onRemove(query);
    if (history.length <= 1) onFocusInput();
  }

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const _EmptyHistory();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HistoryHeader(
          clearAllFocusNode: clearAllFocusNode,
          firstItemFocusNode: firstItemFocusNode,
          onFocusInput: onFocusInput,
          onClearAll: () {
            onClearAll();
            onFocusInput();
          },
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final query = history[index];
              final isFirst = index == 0;
              return _HistoryTile(
                query: query,
                focusNode: isFirst ? firstItemFocusNode : null,
                onTap: () => onSelect(query),
                onRemove: () => _remove(query),
                onKeyEvent: isFirst ? _firstItemKeys : null,
              );
            },
          ),
        ),
      ],
    );
  }

  /// Up goes to the search box, Right to "Clear all".
  KeyEventResult _firstItemKeys(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      onFocusInput();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      clearAllFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.film, size: 24, color: Colors.white24),
              SizedBox(width: 16),
              Icon(LucideIcons.tv, size: 24, color: Colors.white24),
              SizedBox(width: 16),
              Icon(LucideIcons.user, size: 24, color: Colors.white24),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.searchEmptyStateTitle,
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

/// "RECENT SEARCHES • Hold to delete" and the "Clear all" button.
class _HistoryHeader extends StatelessWidget {
  final FocusNode clearAllFocusNode;
  final FocusNode firstItemFocusNode;
  final VoidCallback onFocusInput;
  final VoidCallback onClearAll;

  const _HistoryHeader({
    required this.clearAllFocusNode,
    required this.firstItemFocusNode,
    required this.onFocusInput,
    required this.onClearAll,
  });

  KeyEventResult _clearAllKeys(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      onFocusInput();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      firstItemFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 12, top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.searchRecentSearches.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                // The only delete hint for remote users: the per-item
                // delete button can't get D-pad focus.
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '•  ${l10n.searchHoldToDelete}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textMuted.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SearchHoverButton(
            focusNode: clearAllFocusNode,
            borderRadius: BorderRadius.circular(6),
            highlightAlpha: 0.1,
            onTap: onClearAll,
            onKeyEvent: _clearAllKeys,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                l10n.commonClearAll,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textWhite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One recent search: tap to search it again, hold or "×" to delete it.
class _HistoryTile extends StatelessWidget {
  final String query;
  final FocusNode? focusNode;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final FocusOnKeyEventCallback? onKeyEvent;

  const _HistoryTile({
    required this.query,
    required this.focusNode,
    required this.onTap,
    required this.onRemove,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SearchHoverButton(
        focusNode: focusNode,
        borderRadius: BorderRadius.circular(8),
        highlightAlpha: 0.08,
        onTap: onTap,
        onLongPress: onRemove,
        onKeyEvent: onKeyEvent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                LucideIcons.clock,
                size: 16,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  query,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // The remote deletes by holding the row (see the header hint).
              Focus(
                canRequestFocus: false,
                descendantsAreFocusable: false,
                skipTraversal: true,
                child: IconButton(
                  mouseCursor: SystemMouseCursors.click,
                  icon: const Icon(
                    LucideIcons.x,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: onRemove,
                  tooltip: AppLocalizations.of(context)!.commonDelete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
