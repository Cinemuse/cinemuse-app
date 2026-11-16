import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/search_result.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/features/search/application/search_provider.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:cinemuse_app/features/search/presentation/widgets/search_body.dart';
import 'package:cinemuse_app/features/search/presentation/widgets/search_header_row.dart';
import 'package:cinemuse_app/features/search/presentation/widgets/search_panel_frame.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SearchOverlay extends ConsumerStatefulWidget {
  final NavigatorState? navigator;

  /// Set when the search picks a title for the caller (e.g. to add it to a
  /// list) instead of opening it. A person still opens their page.
  final ValueChanged<MediaItem>? onItemSelected;

  const SearchOverlay({super.key, this.navigator, this.onItemSelected});

  static Future<void> show(
    BuildContext context, {
    NavigatorState? navigator,
    ValueChanged<MediaItem>? onItemSelected,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context)!.navSearch,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          SearchOverlay(navigator: navigator, onItemSelected: onItemSelected),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay>
    with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'SearchOverlayInput',
    onKeyEvent: _handleTextFieldKeyEvent,
  );
  final FocusNode _clearButtonFocusNode = FocusNode(
    debugLabel: 'SearchOverlayClearButton',
  );
  final FocusNode _clearHistoryFocusNode = FocusNode(
    debugLabel: 'SearchOverlayClearHistory',
  );
  final FocusNode _firstContentFocusNode = FocusNode(
    debugLabel: 'SearchOverlayFirstContent',
  );

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    final currentQuery = ref.read(searchProvider).query;
    if (currentQuery.isNotEmpty) {
      _searchController.text = currentQuery;
    }

    _searchController.addListener(_onTextChanged);

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onTextChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    _focusNode.dispose();
    _clearButtonFocusNode.dispose();
    _clearHistoryFocusNode.dispose();
    _firstContentFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  KeyEventResult _handleTextFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _focusFirstContentItem();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final offset = _searchController.selection.baseOffset;
      final isEmpty = _searchController.text.isEmpty;
      // Nothing to the left for the keys: the back arrow hides on them.
      if (isEmpty || offset <= 0) return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final offset = _searchController.selection.baseOffset;
      final textLength = _searchController.text.length;
      if (_searchController.text.isNotEmpty && offset >= textLength) {
        _clearButtonFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _focusFirstContentItem() {
    final searchState = ref.read(searchProvider);
    if (_searchController.text.trim().isEmpty) {
      if (searchState.searchHistory.isNotEmpty) {
        _firstContentFocusNode.requestFocus();
      }
    } else if (searchState.results.isNotEmpty) {
      _firstContentFocusNode.requestFocus();
    }
  }

  void _handleClose() {
    if (_animationController.isAnimating) return;
    _animationController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _onMediaTap(SearchResult result) {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(searchProvider.notifier).addToHistory(query);
    }

    Navigator.of(context).pop();

    final nav = widget.navigator ?? Navigator.of(context);
    switch (result) {
      case PersonResult(:final person):
        nav.push(
          MaterialPageRoute(
            builder: (context) => PersonDetailsScreen(personId: person.id),
          ),
        );
      case TitleResult(:final title):
        final onItemSelected = widget.onItemSelected;
        if (onItemSelected != null) {
          onItemSelected(title);
          return;
        }
        nav.push(
          MaterialPageRoute(
            builder: (context) => MediaDetailsScreen(
              mediaId: title.tmdbId.toString(),
              mediaType: title.mediaType.name,
            ),
          ),
        );
    }
  }

  void _onSubmitted(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    ref.read(searchProvider.notifier).addToHistory(query);
    ref.read(searchProvider.notifier).search(query);
  }

  void _onClear() {
    _searchController.clear();
    ref.read(searchProvider.notifier).onQueryChanged('');
    _focusNode.requestFocus();
  }

  void _onHistoryItemTap(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    ref.read(searchProvider.notifier).search(query);
    _focusNode.requestFocus();
  }

  KeyEventResult _handleCloseKeys(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.gameButtonB ||
            event.logicalKey == LogicalKeyboardKey.goBack)) {
      _handleClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      searchProvider.select((s) => s.status == SearchStatus.loading),
    );
    final isOffline =
        ref.watch(connectivityProvider).value == ConnectivityResult.none;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleClose();
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _handleCloseKeys,
        child: SearchPanelFrame(
          scale: _scaleAnimation,
          onClose: _handleClose,
          header: SearchHeaderRow(
            controller: _searchController,
            inputFocusNode: _focusNode,
            clearFocusNode: _clearButtonFocusNode,
            isOffline: isOffline,
            isLoading: isLoading,
            onClose: _handleClose,
            onClear: _onClear,
            onFocusContent: _focusFirstContentItem,
            onChanged: ref.read(searchProvider.notifier).onQueryChanged,
            onSubmitted: _onSubmitted,
          ),
          body: SearchBody(
            hasQuery: _searchController.text.trim().isNotEmpty,
            isOffline: isOffline,
            scrollController: _scrollController,
            firstContentFocusNode: _firstContentFocusNode,
            clearHistoryFocusNode: _clearHistoryFocusNode,
            onFocusInput: _focusNode.requestFocus,
            onMediaTap: _onMediaTap,
            onHistoryItemTap: _onHistoryItemTap,
          ),
        ),
      ),
    );
  }
}
