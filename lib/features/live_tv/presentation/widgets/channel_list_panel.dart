import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/save_live_tv_change.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_tile.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_filter_sheet.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// Minimalist Live TV channel list panel.
///
/// Supports standard split-screen presentation or high-performance
/// zero-blur drawer overlay when playing in full-window/fullscreen.
class ChannelListPanel extends ConsumerWidget {
  final bool isOverlay;
  final VoidCallback? onClose;

  /// Phone list: tapping the playing channel opens the big player (REV-132).
  final ValueChanged<Channel>? onOpenPlayer;

  const ChannelListPanel({
    super.key,
    this.isOverlay = false,
    this.onClose,
    this.onOpenPlayer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isOverlay) {
      return Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.gameButtonB ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
            onClose?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary.withValues(alpha: 0.98),
                AppTheme.secondary.withValues(alpha: 0.97),
              ],
            ),
            border: Border(right: BorderSide(color: AppTheme.border, width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 32,
                spreadRadius: 2,
                offset: const Offset(6, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildOverlayHeader(context, ref),
              const Divider(height: 1, color: Colors.white10),
              _SearchRow(isOverlay: true, onClose: onClose),
              const Divider(height: 1, color: Colors.white10),
              Expanded(child: _ChannelList(isOverlay: true, onClose: onClose)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.6),
        border: _resolveBorder(context),
      ),
      child: Column(
        children: [
          const _SearchRow(),
          const _CategoryChipsRow(),
          const Divider(height: 1, color: Colors.white10),
          Expanded(child: _ChannelList(onOpenPlayer: onOpenPlayer)),
        ],
      ),
    );
  }

  Widget _buildOverlayHeader(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final channelsCount = ref
        .watch(filteredChannelsProvider)
        .valueOrNull
        ?.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border, width: 1),
            ),
            child: const Icon(
              Icons.tv_rounded,
              size: 18,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.liveTvChannels,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
              letterSpacing: 0.3,
            ),
          ),
          if (channelsCount != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border, width: 0.8),
              ),
              child: Text(
                '$channelsCount',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                onClose?.call();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 20,
              ),
              tooltip: l10n.commonClose,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }

  BoxBorder? _resolveBorder(BuildContext context) {
    final isMobile = Breakpoints.isCompact(context);
    if (isMobile) return null;
    return Border(
      right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    );
  }
}

class _CategoryChipsRow extends ConsumerWidget {
  const _CategoryChipsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(channelsProvider);
    final selected = ref.watch(channelFilterProvider).selectedCategories;
    final filters = ref.read(channelFilterProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    final groups =
        channelsAsync.whenOrNull(
          data: (channels) {
            final g = channels
                .map((ch) => ch.group)
                .where((g) => g != null && g.isNotEmpty)
                .cast<String>()
                .toSet()
                .toList();
            g.sort();
            if (g.contains('DTT')) {
              g.remove('DTT');
              g.insert(0, 'DTT');
            }
            return g;
          },
        ) ??
        [];

    if (groups.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groups.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final title = isAll ? l10n.liveTvAllChannels : groups[index - 1];
          final isSelected = isAll
              ? selected.isEmpty
              : selected.contains(title);

          return _CategoryChip(
            label: title,
            isSelected: isSelected,
            onTap: () => saveLiveTvChange(
              context,
              ref,
              () => isAll ? filters.clear() : filters.toggleCategory(title),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          node.focusInDirection(TraversalDirection.down);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          node.focusInDirection(TraversalDirection.up);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      builder: (context, isFocused, isHovered, _) {
        final highlighted = isFocused || isHovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isFocused
                      ? AppTheme.accent
                      : AppTheme.accent.withValues(alpha: 0.22))
                : (isFocused
                      ? Colors.white.withValues(alpha: 0.15)
                      : (isHovered
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.04))),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isFocused
                  ? Colors.white
                  : (isSelected
                        ? AppTheme.accent.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.08)),
              width: isFocused ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected && isFocused
                  ? Colors.white
                  : (isSelected || highlighted
                        ? Colors.white
                        : AppTheme.textMuted),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}

class _SearchRow extends ConsumerStatefulWidget {
  final bool isOverlay;
  final VoidCallback? onClose;

  const _SearchRow({this.isOverlay = false, this.onClose});

  @override
  ConsumerState<_SearchRow> createState() => _SearchRowState();
}

class _SearchRowState extends ConsumerState<_SearchRow> {
  late final TextEditingController _controller;
  late final FocusNode _searchFocusNode;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(channelSearchQueryProvider),
    );
    _searchFocusNode = FocusNode(
      debugLabel: 'LiveTvSearchFocusNode',
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;

        // Escape, Gamepad B, or GoBack -> close overlay
        if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.gameButtonB ||
            key == LogicalKeyboardKey.goBack) {
          widget.onClose?.call();
          return KeyEventResult.handled;
        }

        // Arrow Down -> move focus down to category chips or channel list
        if (key == LogicalKeyboardKey.arrowDown) {
          node.focusInDirection(TraversalDirection.down);
          return KeyEventResult.handled;
        }

        // Arrow Up -> move focus up to close button in header
        if (key == LogicalKeyboardKey.arrowUp) {
          node.focusInDirection(TraversalDirection.up);
          return KeyEventResult.handled;
        }

        // Arrow Left -> if cursor is at the beginning or text is empty, close overlay
        if (widget.isOverlay && key == LogicalKeyboardKey.arrowLeft) {
          if (_controller.text.isEmpty ||
              _controller.selection.baseOffset <= 0) {
            widget.onClose?.call();
            return KeyEventResult.handled;
          }
        }

        // Arrow Right -> if cursor is at the end or text is empty, close overlay
        if (widget.isOverlay && key == LogicalKeyboardKey.arrowRight) {
          if (_controller.text.isEmpty ||
              _controller.selection.baseOffset >= _controller.text.length) {
            widget.onClose?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
    // Rebuild so the border shows the accent while focused (REV-139).
    _searchFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(channelSearchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentTab = ref.watch(liveTvTabProvider);
    final filterIsActive = ref.watch(
      channelFilterProvider.select((f) => f.isActive),
    );
    final isMobile = Breakpoints.isCompact(context);

    // Sync controller when the provider is changed externally (e.g. from sport cards)
    ref.listen<String>(channelSearchQueryProvider, (previous, next) {
      final isExternalChange = _controller.text != next;
      if (isExternalChange) {
        _controller.text = next;
        _controller.selection = TextSelection.collapsed(offset: next.length);

        // Auto-select the first filtered channel only when triggered externally (e.g. sport row)
        if (next.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final channels = ref.read(filteredChannelsProvider);
            channels.whenData((list) {
              if (list.isNotEmpty) {
                ref.read(selectedChannelProvider.notifier).select(list.first);
              }
            });
          });
        }
      }
    });

    if (widget.isOverlay) {
      return Container(
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _searchFocusNode.hasFocus
                ? AppTheme.accent
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _searchFocusNode,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            _searchFocusNode.focusInDirection(TraversalDirection.down);
          },
          decoration: InputDecoration(
            hintText: l10n.liveTvSearchPlaceholder,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: Colors.white30,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, child) {
                return value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white30,
                        ),
                        splashRadius: 16,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                          setState(() {});
                        },
                      )
                    : const SizedBox.shrink();
              },
            ),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        height: isMobile ? 48 : 52,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: isMobile ? 8 : 16),
                child: TextField(
                  controller: _controller,
                  focusNode: _searchFocusNode,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: l10n.liveTvSearchPlaceholder,
                    hintStyle: const TextStyle(
                      color: Colors.white30,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.white30,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, child) {
                        return value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white30,
                                ),
                                onPressed: () {
                                  _controller.clear();
                                  _onChanged('');
                                  setState(() {});
                                },
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
            // Favorites Tab Icon
            IconButton(
              onPressed: () {
                ref
                    .read(liveTvTabProvider.notifier)
                    .state = currentTab == LiveTvTab.favorites
                    ? LiveTvTab.all
                    : LiveTvTab.favorites;
              },
              icon: Icon(
                currentTab == LiveTvTab.favorites
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 20,
                color: currentTab == LiveTvTab.favorites
                    ? Colors.amber
                    : Colors.white30,
              ),
              tooltip: l10n.liveTvTabFavorites,
            ),
            // Recents Tab Icon
            IconButton(
              onPressed: () {
                ref
                    .read(liveTvTabProvider.notifier)
                    .state = currentTab == LiveTvTab.recents
                    ? LiveTvTab.all
                    : LiveTvTab.recents;
              },
              icon: Icon(
                Icons.history_rounded,
                size: 20,
                color: currentTab == LiveTvTab.recents
                    ? Colors.white
                    : Colors.white30,
              ),
              tooltip: l10n.liveTvTabRecents,
            ),
            _LiveTvOptionsButton(isActive: filterIsActive),
          ],
        ),
      ),
    );
  }
}

class _LiveTvOptionsButton extends StatelessWidget {
  final bool isActive;

  const _LiveTvOptionsButton({required this.isActive});

  Future<void> _showQuickMenu(BuildContext context, Offset position) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showMenu<LiveTvSheetTab>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      items: [
        PopupMenuItem(
          value: LiveTvSheetTab.categories,
          child: Row(
            children: [
              const Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.liveTvFilterChannels,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: LiveTvSheetTab.playlists,
          child: Row(
            children: [
              const Icon(
                Icons.playlist_play_rounded,
                size: 20,
                color: Colors.white70,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.liveTvManagePlaylists,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );

    if (selected != null && context.mounted) {
      showChannelFilterSheet(context, initialTab: selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onLongPressStart: (details) =>
            _showQuickMenu(context, details.globalPosition),
        onSecondaryTapDown: (details) =>
            _showQuickMenu(context, details.globalPosition),
        child: Stack(
          children: [
            IconButton(
              onPressed: () => showChannelFilterSheet(context),
              icon: Icon(
                Icons.tune_rounded,
                size: 20,
                color: isActive ? Colors.white : Colors.white30,
              ),
              tooltip: l10n.liveTvFilterAndPlaylists,
            ),
            if (isActive)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChannelList extends ConsumerStatefulWidget {
  final bool isOverlay;
  final VoidCallback? onClose;
  final ValueChanged<Channel>? onOpenPlayer;

  const _ChannelList({this.isOverlay = false, this.onClose, this.onOpenPlayer});

  @override
  ConsumerState<_ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends ConsumerState<_ChannelList> {
  late final ScrollController _scrollController;
  final FocusNode _selectedChannelFocusNode = FocusNode(
    debugLabel: 'LiveTvOverlaySelectedChannelTile',
  );
  bool _hasCenteredInitial = false;

  @override
  void initState() {
    super.initState();
    final savedOffset = widget.isOverlay
        ? ref.read(liveTvOverlayScrollOffsetProvider)
        : null;
    _scrollController = ScrollController(
      initialScrollOffset: savedOffset ?? 0.0,
    );
    if (widget.isOverlay) {
      _scrollController.addListener(_onScroll);
      if (savedOffset != null) {
        _hasCenteredInitial = true;
      }
    }
  }

  void _onScroll() {
    if (widget.isOverlay && _scrollController.hasClients) {
      ref.read(liveTvOverlayScrollOffsetProvider.notifier).state =
          _scrollController.offset;
    }
  }

  @override
  void dispose() {
    if (widget.isOverlay) {
      _scrollController.removeListener(_onScroll);
    }
    _selectedChannelFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Top of [selected]'s row (rows are 58 px, REV-139).
  double? _offsetOf(List<Channel> channels, Channel selected) {
    final index = channels.indexWhere((ch) => ch.uniqueId == selected.uniqueId);
    return index < 0 ? null : index * 58.0;
  }

  void _scrollToSelected(List<Channel> channels, Channel selected) {
    final offset = _offsetOf(channels, selected);
    if (offset == null || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _centerOnCurrentChannelOnce(List<Channel> channels, Channel? selected) {
    if (selected == null || !_scrollController.hasClients) return;
    _hasCenteredInitial = true;

    final offset = _offsetOf(channels, selected);
    if (offset == null) return;
    final viewport = _scrollController.position.viewportDimension;
    final target = (offset - (viewport / 2) + 29.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
    ref.read(liveTvOverlayScrollOffsetProvider.notifier).state = target;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedChannelFocusNode.canRequestFocus) {
        _selectedChannelFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(filteredChannelsProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);
    final tab = ref.watch(liveTvTabProvider);

    // Auto-scroll when selected channel changes in split mode only
    if (!widget.isOverlay) {
      ref.listen(selectedChannelProvider, (_, next) {
        if (next == null) return;
        ref
            .read(filteredChannelsProvider)
            .whenData((channels) => _scrollToSelected(channels, next));
      });
    }

    return channelsAsync.when(
      data: (channels) {
        if (channels.isEmpty) {
          return _buildEmptyState(tab);
        }

        if (widget.isOverlay && !_hasCenteredInitial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _hasCenteredInitial) return;
            _centerOnCurrentChannelOnce(channels, selectedChannel);
          });
        }

        return _buildFlatList(channels, selectedChannel);
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState(LiveTvTab tab) {
    final l10n = AppLocalizations.of(context)!;

    String title;
    String? subtitle;
    IconData icon;

    switch (tab) {
      case LiveTvTab.favorites:
        title = l10n.liveTvNoFavorites;
        subtitle = l10n.liveTvNoFavoritesHint;
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (tab == LiveTvTab.all) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => showChannelFilterSheet(
                  context,
                  initialTab: LiveTvSheetTab.playlists,
                ),
                icon: const Icon(Icons.playlist_add_rounded, size: 20),
                label: Text(l10n.liveTvManagePlaylists),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlatList(List<Channel> channels, Channel? selected) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: channels.length,
      itemExtent: 58.0,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final isSelected = selected?.uniqueId == channel.uniqueId;
        return _ChannelTileWrapper(
          channel: channel,
          selectedChannel: selected,
          isOverlay: widget.isOverlay,
          onClose: widget.onClose,
          onOpenPlayer: widget.onOpenPlayer,
          isFirst: index == 0,
          focusNode: (widget.isOverlay && isSelected)
              ? _selectedChannelFocusNode
              : null,
          autofocus: widget.isOverlay && isSelected,
        );
      },
    );
  }
}

class _ChannelTileWrapper extends ConsumerWidget {
  final Channel channel;
  final Channel? selectedChannel;
  final bool isOverlay;
  final VoidCallback? onClose;
  final ValueChanged<Channel>? onOpenPlayer;
  final bool isFirst;
  final FocusNode? focusNode;
  final bool autofocus;

  const _ChannelTileWrapper({
    required this.channel,
    this.selectedChannel,
    this.isOverlay = false,
    this.onClose,
    this.onOpenPlayer,
    this.isFirst = false,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProgram = ref.watch(currentProgramProvider(channel));
    final favoriteIds = ref.watch(favoriteChannelIdsProvider);
    final l10n = AppLocalizations.of(context)!;
    final isPlaying = selectedChannel?.uniqueId == channel.uniqueId;

    return ChannelListTile(
      channel: channel,
      isSelected: isPlaying,
      isFavorite: favoriteIds.contains(channel.uniqueId),
      currentProgram: currentProgram,
      focusNode: focusNode,
      autofocus: autofocus,
      onTap: isPlaying && onOpenPlayer != null
          ? () => onOpenPlayer!(channel)
          : () => ref.read(selectedChannelProvider.notifier).select(channel),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // In overlay mode: Left, Right or Escape dismisses the overlay
        if (isOverlay) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            onClose?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }

        // In split mode: Up on first item focuses top navbar
        if (event.logicalKey == LogicalKeyboardKey.arrowUp && isFirst) {
          final focusNavbar = ref.read(topNavbarFocusActionProvider);
          if (focusNavbar != null) {
            focusNavbar();
            return KeyEventResult.handled;
          }
        }

        // In split mode: Right focuses the preview player
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          final focusPlayer = ref.read(livePlayerFocusActionProvider);
          if (focusPlayer != null) {
            focusPlayer();
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      onFavoriteToggle: () {
        final notifier = ref.read(favoriteChannelIdsProvider.notifier);
        final id = channel.uniqueId;
        final wasFavorite = notifier.isFavorite(id);
        unawaited(saveLiveTvChange(context, ref, () => notifier.toggle(id)));

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasFavorite
                  ? l10n.liveTvRemovedFromFavorites
                  : l10n.liveTvAddedToFavorites,
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.surface,
          ),
        );
      },
    );
  }
}
