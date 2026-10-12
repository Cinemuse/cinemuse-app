import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_filter_sheet.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_details_banner.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_timeline_grid.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/save_live_tv_change.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// Complete Cinemuse classic EPG TV Guide screen.
class LiveTvGuideScreen extends ConsumerStatefulWidget {
  final FocusNode? focusNode;
  final void Function(Channel channel)? onChannelSelected;

  const LiveTvGuideScreen({super.key, this.focusNode, this.onChannelSelected});

  @override
  ConsumerState<LiveTvGuideScreen> createState() => _LiveTvGuideScreenState();
}

class _LiveTvGuideScreenState extends ConsumerState<LiveTvGuideScreen> {
  final GlobalKey<EpgTimelineGridState> _gridKey =
      GlobalKey<EpgTimelineGridState>();

  Channel? _focusedChannel;

  Future<void> _toggleFavorite(Channel ch) => saveLiveTvChange(
    context,
    ref,
    () => ref.read(favoriteChannelIdsProvider.notifier).toggle(ch.uniqueId),
  );
  EpgProgram? _focusedProgram;
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(channelSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Waits like the phone field, so big playlists don't re-filter per key.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(channelSearchQueryProvider.notifier).state = value;
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(channelSearchQueryProvider.notifier).state = '';
  }

  void _onProgramFocused(Channel channel, EpgProgram? program) {
    if (_focusedChannel?.uniqueId != channel.uniqueId ||
        !identical(_focusedProgram, program)) {
      setState(() {
        _focusedChannel = channel;
        _focusedProgram = program;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final channelsAsync = ref.watch(filteredChannelsProvider);
    final allChannelsAsync = ref.watch(channelsProvider);
    final epgDataAsync = ref.watch(epgDataProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);
    final favoriteIds = ref.watch(favoriteChannelIdsProvider);
    final activeTab = ref.watch(liveTvTabProvider);
    // Searches set elsewhere (a sport card on Home) show here too (REV-129).
    ref.listen<String>(channelSearchQueryProvider, (_, next) {
      if (_searchController.text != next) _searchController.text = next;
    });

    // A focused channel that left the list (playlist removed) is dropped.
    final isFocusedListed =
        channelsAsync.valueOrNull?.contains(_focusedChannel) ?? false;
    final effectiveChannel =
        (isFocusedListed ? _focusedChannel : null) ?? selectedChannel;
    final effectiveProgram =
        (isFocusedListed ? _focusedProgram : null) ??
        (effectiveChannel != null
            ? ref.watch(currentProgramProvider(effectiveChannel))
            : null);

    final isFav =
        effectiveChannel != null &&
        favoriteIds.contains(effectiveChannel.uniqueId);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Column(
        children: [
          _buildTopBar(context, l10n, allChannelsAsync.valueOrNull ?? []),

          EpgDetailsBanner(
            channel: effectiveChannel,
            program: effectiveProgram,
            isFavorite: isFav,
            onWatch:
                effectiveChannel != null && widget.onChannelSelected != null
                ? () => widget.onChannelSelected!(effectiveChannel)
                : null,
            onToggleFavorite: effectiveChannel != null
                ? () => _toggleFavorite(effectiveChannel)
                : null,
          ),

          Expanded(
            child: channelsAsync.when(
              data: (channels) {
                if (channels.isEmpty) {
                  return _buildEmptyState(activeTab, l10n);
                }

                final epgData = epgDataAsync.valueOrNull ?? {};

                return EpgTimelineGrid(
                  key: _gridKey,
                  channels: channels,
                  epgData: epgData,
                  selectedChannel: selectedChannel,
                  favoriteIds: favoriteIds,
                  onProgramFocused: _onProgramFocused,
                  onChannelSelected: widget.onChannelSelected,
                  onToggleFavorite: _toggleFavorite,
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
              error: (_, __) => Center(
                child: Text(
                  l10n.liveTvError,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    AppLocalizations l10n,
    List<Channel> allChannels,
  ) {
    final activeTab = ref.watch(liveTvTabProvider);
    final filter = ref.watch(channelFilterProvider);

    final categories = allChannels
        .map((c) => c.group)
        .where((g) => g != null && g.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    categories.sort();
    if (categories.contains('DTT')) {
      categories.remove('DTT');
      categories.insert(0, 'DTT');
    }

    final selectedCategories = filter.selectedCategories;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        node.nextFocus();
                        return KeyEventResult.handled;
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.arrowUp) {
                        final focusNavbar = ref.read(
                          topNavbarFocusActionProvider,
                        );
                        if (focusNavbar != null) {
                          focusNavbar();
                          return KeyEventResult.handled;
                        }
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.escape) {
                        node.unfocus();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: l10n.liveTvSearchPlaceholder,
                        hintStyle: const TextStyle(
                          color: Colors.white30,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: Colors.white38,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (context, value, child) {
                            return value.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.white38,
                                    ),
                                    onPressed: _clearSearch,
                                  )
                                : const SizedBox.shrink();
                          },
                        ),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Filter Tabs (All / Favorites / Recents)
              _buildTabButton(
                focusNode: widget.focusNode,
                icon: Icons.grid_view_rounded,
                label: l10n.liveTvTabAll,
                isSelected: activeTab == LiveTvTab.all,
                onTap: () {
                  ref.read(liveTvTabProvider.notifier).state = LiveTvTab.all;
                },
              ),
              const SizedBox(width: 6),
              _buildTabButton(
                icon: Icons.star_rounded,
                label: l10n.liveTvTabFavorites,
                isSelected: activeTab == LiveTvTab.favorites,
                onTap: () {
                  ref.read(liveTvTabProvider.notifier).state =
                      LiveTvTab.favorites;
                },
              ),
              const SizedBox(width: 6),
              _buildTabButton(
                icon: Icons.history_rounded,
                label: l10n.liveTvTabRecents,
                isSelected: activeTab == LiveTvTab.recents,
                onTap: () {
                  ref.read(liveTvTabProvider.notifier).state =
                      LiveTvTab.recents;
                },
              ),
              const SizedBox(width: 12),

              DpadFocusable(
                onTap: () => _gridKey.currentState?.jumpToNow(),
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    final focusNavbar = ref.read(topNavbarFocusActionProvider);
                    if (focusNavbar != null) {
                      focusNavbar();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                borderRadius: BorderRadius.circular(8),
                builder: (context, isFocused, isHovered, _) {
                  return Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isFocused
                          ? AppTheme.accent.withValues(alpha: 0.25)
                          : (isHovered
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFocused
                            ? AppTheme.accent
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.my_location_rounded,
                          size: 16,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.liveTvJumpToNow,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: const SizedBox.shrink(),
              ),

              const SizedBox(width: 8),

              DpadFocusable(
                onTap: () => showChannelFilterSheet(context),
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    final focusNavbar = ref.read(topNavbarFocusActionProvider);
                    if (focusNavbar != null) {
                      focusNavbar();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                borderRadius: BorderRadius.circular(8),
                builder: (context, isFocused, isHovered, _) {
                  return Container(
                    height: 38,
                    width: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isFocused
                          ? AppTheme.accent.withValues(alpha: 0.25)
                          : (isHovered
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFocused
                            ? AppTheme.accent
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                      boxShadow: isFocused ? AppTheme.shadowFocusGlow : null,
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: Colors.white70,
                    ),
                  );
                },
                child: const SizedBox.shrink(),
              ),
            ],
          ),

          // Category Chips Row (if categories available)
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final title = isAll
                      ? l10n.liveTvAllChannels
                      : categories[index - 1];
                  final isSelected = isAll
                      ? selectedCategories.isEmpty
                      : selectedCategories.contains(title);

                  return _buildCategoryChip(
                    title: title,
                    isSelected: isSelected,
                    onTap: () => saveLiveTvChange(context, ref, () {
                      final filters = ref.read(channelFilterProvider.notifier);
                      return isAll
                          ? filters.clear()
                          : filters.toggleCategory(title);
                    }),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    FocusNode? focusNode,
  }) {
    return DpadFocusable(
      focusNode: focusNode,
      onTap: onTap,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          final focusNavbar = ref.read(topNavbarFocusActionProvider);
          if (focusNavbar != null) {
            focusNavbar();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      borderRadius: BorderRadius.circular(8),
      builder: (context, isFocused, isHovered, _) {
        return Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.2)
                : (isFocused
                      ? Colors.white.withValues(alpha: 0.12)
                      : (isHovered
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.03))),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accent
                  : (isFocused
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.08)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.accent : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildCategoryChip({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return DpadFocusable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      builder: (context, isFocused, isHovered, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent
                : (isFocused
                      ? Colors.white.withValues(alpha: 0.15)
                      : (isHovered
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.04))),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isFocused
                  ? Colors.white
                  : (isSelected
                        ? AppTheme.accent
                        : Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textMuted,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState(LiveTvTab tab, AppLocalizations l10n) {
    String title;
    IconData icon;

    switch (tab) {
      case LiveTvTab.favorites:
        title = l10n.liveTvNoFavorites;
        icon = Icons.star_outline_rounded;
        break;
      case LiveTvTab.recents:
        title = l10n.liveTvNoRecents;
        icon = Icons.history_rounded;
        break;
      case LiveTvTab.all:
        title = l10n.liveTvNoChannels;
        icon = Icons.tv_off_rounded;
        break;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (tab == LiveTvTab.all) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => showChannelFilterSheet(
                context,
                initialTab: LiveTvSheetTab.playlists,
              ),
              icon: const Icon(Icons.playlist_add_rounded, size: 20),
              label: Text(l10n.liveTvManagePlaylists),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
