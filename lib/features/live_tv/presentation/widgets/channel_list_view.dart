import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_empty_state.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_tile.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/save_live_tv_change.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';

/// The scrolling channel list of the channel list panel, in the split screen
/// or in the drawer over the player; a message when the tab has no channels.
class ChannelListView extends ConsumerStatefulWidget {
  final bool isOverlay;
  final VoidCallback? onClose;
  final ValueChanged<Channel>? onOpenPlayer;

  const ChannelListView({
    super.key,
    this.isOverlay = false,
    this.onClose,
    this.onOpenPlayer,
  });

  @override
  ConsumerState<ChannelListView> createState() => _ChannelListViewState();
}

class _ChannelListViewState extends ConsumerState<ChannelListView> {
  late final ScrollController _scrollController;
  final FocusNode _selectedChannelFocusNode = FocusNode(
    debugLabel: 'LiveTvOverlaySelectedChannelTile',
  );
  bool _hasCenteredInitial = false;

  /// The other tiles' focus nodes, by channel, so Page up / Page down can
  /// focus the tile a jump brings on screen.
  final Map<String, FocusNode> _tileNodes = {};

  static const double _rowExtent = 58.0;

  FocusNode _nodeFor(Channel channel, bool isSelected) =>
      widget.isOverlay && isSelected
      ? _selectedChannelFocusNode
      : _tileNodes.putIfAbsent(
          channel.uniqueId,
          () => FocusNode(debugLabel: 'ChannelTile_${channel.uniqueId}'),
        );

  /// Page up (-1) or Page down (+1) from the tile at [index]: one screen
  /// of channels, the list scrolling as far, so the focus keeps its place
  /// on screen. Stops at the first and last channel.
  void _movePage(List<Channel> channels, int index, int direction) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final rows = (position.viewportDimension / _rowExtent).floor();
    final target = (index + direction * (rows < 1 ? 1 : rows)).clamp(
      0,
      channels.length - 1,
    );
    if (target == index) return;
    position.jumpTo(
      (position.pixels + (target - index) * _rowExtent).clamp(
        0.0,
        position.maxScrollExtent,
      ),
    );
    // Focused once the tiles are laid out where the jump put them.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted) return;
        final channel = channels[target];
        final selected = ref.read(selectedChannelProvider);
        _nodeFor(
          channel,
          selected?.uniqueId == channel.uniqueId,
        ).requestFocus();
      })
      ..scheduleFrame();
  }

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
      ref
          .read(liveTvOverlayScrollOffsetProvider.notifier)
          .set(_scrollController.offset);
    }
  }

  @override
  void dispose() {
    if (widget.isOverlay) {
      _scrollController.removeListener(_onScroll);
    }
    _selectedChannelFocusNode.dispose();
    for (final node in _tileNodes.values) {
      node.dispose();
    }
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
    ref.read(liveTvOverlayScrollOffsetProvider.notifier).set(target);

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
          return ChannelListEmptyState(tab: tab);
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
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildFlatList(List<Channel> channels, Channel? selected) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: channels.length,
      itemExtent: _rowExtent,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final isSelected = selected?.uniqueId == channel.uniqueId;
        return _ChannelTileWrapper(
          channel: channel,
          selectedChannel: selected,
          isOverlay: widget.isOverlay,
          onClose: widget.onClose,
          onOpenPlayer: widget.onOpenPlayer,
          onPage: (direction) => _movePage(channels, index, direction),
          isFirst: index == 0,
          focusNode: _nodeFor(channel, isSelected),
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

  /// Page up (-1) or Page down (+1) from this tile.
  final ValueChanged<int> onPage;
  final bool isFirst;
  final FocusNode? focusNode;
  final bool autofocus;

  const _ChannelTileWrapper({
    required this.channel,
    this.selectedChannel,
    this.isOverlay = false,
    this.onClose,
    this.onOpenPlayer,
    required this.onPage,
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
        // Only a press turns a page; its repeats are swallowed (over the
        // player they would otherwise change the channel).
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.pageUp ||
            key == LogicalKeyboardKey.pageDown) {
          if (event is KeyDownEvent) {
            onPage(key == LogicalKeyboardKey.pageUp ? -1 : 1);
          }
          return KeyEventResult.handled;
        }
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // In overlay mode: Right or Escape closes it, towards the player;
        // Left stays, the list being at the screen's left edge.
        if (isOverlay) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            onClose?.call();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
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
