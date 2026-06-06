import 'dart:ui';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/features/search/application/search_provider.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/shared/widgets/error_view_state.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SearchOverlay extends ConsumerStatefulWidget {
  final NavigatorState? navigator;
  const SearchOverlay({super.key, this.navigator});

  static Future<void> show(BuildContext context, {NavigatorState? navigator}) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Search',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          SearchOverlay(navigator: navigator),
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
  final FocusNode _focusNode = FocusNode();

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
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  void _handleClose() {
    _animationController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _onMediaTap(Map<String, dynamic> media) {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(searchProvider.notifier).addToHistory(query);
    }

    final type = media['media_type'] ?? media['type'] ?? 'movie';
    final id = media['id'].toString();

    Navigator.of(context).pop();

    final nav = widget.navigator ?? Navigator.of(context);

    if (type == 'person') {
      nav.push(
        MaterialPageRoute(
          builder: (context) => PersonDetailsScreen(personId: int.parse(id)),
        ),
      );
    } else {
      nav.push(
        MaterialPageRoute(
          builder: (context) => MediaDetailsScreen(
            mediaId: id,
            mediaType: type == 'tv' || type == 'series' ? 'tv' : 'movie',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final l10n = AppLocalizations.of(context)!;
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.valueOrNull == ConnectivityResult.none;

    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),

        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: 0,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(
                        maxWidth: 800,
                        maxHeight: 800,
                      ),
                      margin: const EdgeInsets.only(top: 40),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  mouseCursor: SystemMouseCursors.click,
                                  icon: const Icon(
                                    LucideIcons.arrowLeft,
                                    color: AppTheme.textMuted,
                                    size: 24,
                                  ),
                                  onPressed: _handleClose,
                                  tooltip: l10n.commonCancel,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    enabled: !isOffline,
                                    focusNode: _focusNode,
                                    cursorColor: Colors.white,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (val) {
                                      final query = val.trim();
                                      if (query.isNotEmpty) {
                                        ref
                                            .read(searchProvider.notifier)
                                            .addToHistory(query);
                                        ref
                                            .read(searchProvider.notifier)
                                            .search(query);
                                      }
                                    },
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: isOffline
                                          ? AppTheme.textMuted
                                          : Colors.white,
                                      fontWeight: FontWeight.w300,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: l10n.searchPlaceholder,
                                      hintStyle: TextStyle(
                                        color: AppTheme.textMuted.withValues(
                                          alpha: 0.5,
                                        ),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w300,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      contentPadding: EdgeInsets.zero,
                                      hoverColor: Colors.transparent,
                                    ),
                                    onChanged: (val) {
                                      ref
                                          .read(searchProvider.notifier)
                                          .onQueryChanged(val);
                                    },
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    mouseCursor: SystemMouseCursors.click,
                                    icon: const Icon(
                                      LucideIcons.x,
                                      color: AppTheme.textMuted,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref
                                          .read(searchProvider.notifier)
                                          .onQueryChanged('');
                                    },
                                    tooltip: l10n.commonClearAll,
                                  ),
                                if (searchState.status == SearchStatus.loading)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.accent,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          Flexible(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.2),
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.7,
                                minHeight: 200,
                              ),
                              child: _buildBody(searchState, l10n, isOffline),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(SearchState state, AppLocalizations l10n, bool isOffline) {
    if (isOffline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.offlineScreenTitle,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.offlineScreenMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return _buildSearchHistory(state, l10n);
    }

    if (state.status == SearchStatus.error) {
      return ErrorViewState(
        title: "Search Error",
        message: state.errorMessage ?? "An unexpected error occurred",
        onRetry: () => ref.read(searchProvider.notifier).search(state.query),
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

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.67,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: state.results.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.results.length) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          );
        }

        final item = state.results[index];
        final isPerson = item['media_type'] == 'person';

        if (isPerson) {
          final title = item['name'] ?? 'Unknown';
          final posterPath = item['profile_path'] as String?;
          final releaseDate = item['known_for_department'] as String?;
          final tmdbId = item['id'] as int;

          return MediaCard(
            title: title,
            posterPath: posterPath,
            releaseDate: releaseDate,
            rating: null,
            tmdbId: tmdbId,
            mediaType: null,
            onTap: () => _onMediaTap(item),
          );
        } else {
          final mediaItem = MediaItem.fromTmdbMap(item);
          final appLanguage = ref.watch(settingsProvider).appLanguage;

          return MediaCard(
            title: mediaItem.getLocalizedTitle(appLanguage) ?? 'Unknown',
            posterPath: mediaItem.posterPath,
            releaseDate: mediaItem.releaseDate?.year.toString(),
            rating: mediaItem.voteAverage,
            tmdbId: mediaItem.tmdbId,
            mediaType: mediaItem.mediaType,
            onTap: () => _onMediaTap(item),
          );
        }
      },
    );
  }

  Widget _buildSearchHistory(SearchState state, AppLocalizations l10n) {
    final history = state.searchHistory;
    if (history.isEmpty) {
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
              l10n.searchEmptyStateTitle,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 12, top: 16, bottom: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  enabledMouseCursor: SystemMouseCursors.click,
                ),
                child: Text(
                  l10n.commonClearAll,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  ref.read(searchProvider.notifier).clearHistory();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final query = history[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: Colors.white.withValues(alpha: 0.05),
                    splashColor: Colors.white.withValues(alpha: 0.1),
                    highlightColor: Colors.white.withValues(alpha: 0.05),
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () => _onHistoryItemTap(query),
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
                        IconButton(
                          mouseCursor: SystemMouseCursors.click,
                          icon: const Icon(
                            LucideIcons.x,
                            size: 18,
                            color: AppTheme.textMuted,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          onPressed: () {
                            ref
                                .read(searchProvider.notifier)
                                .removeFromHistory(query);
                          },
                          tooltip: l10n.commonDelete,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          ),
        ),
      ],
    );
  }

  void _onHistoryItemTap(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    ref.read(searchProvider.notifier).search(query);
    _focusNode.requestFocus();
  }
}
