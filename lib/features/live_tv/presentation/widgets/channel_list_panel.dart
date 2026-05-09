import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_tile.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_filter_sheet.dart';

/// Minimalist Live TV channel list panel.
///
/// Layout: 3 segmented tabs → search + filter icon → flat channel list
/// with sticky section headers. No sidebar, no accordions.
class ChannelListPanel extends ConsumerWidget {
  const ChannelListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.6),
            border: _resolveBorder(context),
          ),
          child: const Column(
            children: [
              _SearchRow(),
              Divider(height: 1, color: Colors.white10),
              Expanded(child: _ChannelList()),
            ],
          ),
        ),
      ),
    );
  }

  BoxBorder? _resolveBorder(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) return null;
    return Border(
      right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    );
  }
}

// ---------------------------------------------------------------------------
// Search Row — Search field + Tab Icons + Filter icon
// ---------------------------------------------------------------------------

class _SearchRow extends ConsumerStatefulWidget {
  const _SearchRow();

  @override
  ConsumerState<_SearchRow> createState() => _SearchRowState();
}

class _SearchRowState extends ConsumerState<_SearchRow> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: ref.read(channelSearchQueryProvider));
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
    final filterIsActive = ref.watch(channelFilterProvider.select((f) => f.isActive));
    final isMobile = MediaQuery.of(context).size.width < 600;

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
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: l10n.liveTvSearchPlaceholder,
                    hintStyle:
                        const TextStyle(color: Colors.white30, fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: Colors.white30),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                size: 16, color: Colors.white30),
                            onPressed: () {
                              _controller.clear();
                              _onChanged('');
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  style:
                      const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
            // Favorites Tab Icon
            IconButton(
              onPressed: () {
                ref.read(liveTvTabProvider.notifier).state = 
                    currentTab == LiveTvTab.favorites ? LiveTvTab.all : LiveTvTab.favorites;
              },
              icon: Icon(
                currentTab == LiveTvTab.favorites ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 20,
                color: currentTab == LiveTvTab.favorites ? AppTheme.accent : Colors.white30,
              ),
              tooltip: l10n.liveTvTabFavorites,
            ),
            // Recents Tab Icon
            IconButton(
              onPressed: () {
                ref.read(liveTvTabProvider.notifier).state = 
                    currentTab == LiveTvTab.recents ? LiveTvTab.all : LiveTvTab.recents;
              },
              icon: Icon(
                Icons.history_rounded,
                size: 20,
                color: currentTab == LiveTvTab.recents ? AppTheme.accent : Colors.white30,
              ),
              tooltip: l10n.liveTvTabRecents,
            ),
            _FilterIconButton(isActive: filterIsActive),
          ],
        ),
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  final bool isActive;

  const _FilterIconButton({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Stack(
        children: [
          IconButton(
            onPressed: () => showChannelFilterSheet(context),
            icon: Icon(
              Icons.tune_rounded,
              size: 20,
              color: isActive ? AppTheme.accent : Colors.white30,
            ),
            tooltip: AppLocalizations.of(context)!.liveTvFilterChannels,
          ),
          if (isActive)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Channel List — Flat list with sticky section headers
// ---------------------------------------------------------------------------

class _ChannelList extends ConsumerStatefulWidget {
  const _ChannelList();

  @override
  ConsumerState<_ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends ConsumerState<_ChannelList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected(List<Channel> channels, Channel selected) {
    if (!_scrollController.hasClients) return;
    final index = channels.indexWhere((ch) => ch.uniqueId == selected.uniqueId);
    if (index < 0) return;

    final offset =
        (index * 60.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(sectionedChannelsProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);
    final tab = ref.watch(liveTvTabProvider);

    // Auto-scroll when selected channel changes
    ref.listen(selectedChannelProvider, (_, next) {
      if (next == null) return;
      final flat = ref.read(filteredChannelsProvider);
      flat.whenData((channels) => _scrollToSelected(channels, next));
    });

    return sectionsAsync.when(
      data: (sections) {
        if (sections.isEmpty ||
            sections.every((s) => s.channels.isEmpty)) {
          return _buildEmptyState(tab);
        }

        // If there's only one section (filtered/favorites/recents), render flat
        final isSingleSection =
            sections.length == 1 && sections.first.title.isEmpty;

        if (isSingleSection) {
          return _buildFlatList(
              sections.first.channels, selectedChannel);
        }

        return _buildSectionedList(sections, selectedChannel);
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      ),
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
      itemExtent: 60,
      itemBuilder: (context, index) {
        return _ChannelTileWrapper(
          channel: channels[index],
          selectedChannel: selected,
        );
      },
    );
  }

  Widget _buildSectionedList(
      List<ChannelSection> sections, Channel? selected) {
    // Build a flat list of items: headers + channels
    final items = <_ListItem>[];
    for (final section in sections) {
      items.add(_ListItem.header(section.title));
      for (final ch in section.channels) {
        items.add(_ListItem.channel(ch));
      }
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isHeader) {
          return _SectionHeader(title: item.headerTitle!);
        }
        return SizedBox(
          height: 60,
          child: _ChannelTileWrapper(
            channel: item.channel!,
            selectedChannel: selected,
          ),
        );
      },
    );
  }
}

/// Lightweight tagged union for list items.
class _ListItem {
  final String? headerTitle;
  final Channel? channel;

  const _ListItem._({this.headerTitle, this.channel});

  factory _ListItem.header(String title) =>
      _ListItem._(headerTitle: title);
  factory _ListItem.channel(Channel ch) => _ListItem._(channel: ch);

  bool get isHeader => headerTitle != null;
}

// ---------------------------------------------------------------------------
// Section Header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 16),
      alignment: Alignment.bottomLeft,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Channel Tile Wrapper — connects tile to providers
// ---------------------------------------------------------------------------

class _ChannelTileWrapper extends ConsumerWidget {
  final Channel channel;
  final Channel? selectedChannel;

  const _ChannelTileWrapper({
    required this.channel,
    this.selectedChannel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProgram = ref.watch(currentProgramProvider(channel));
    final favoriteIds = ref.watch(favoriteChannelIdsProvider);
    final l10n = AppLocalizations.of(context)!;

    return ChannelListTile(
      channel: channel,
      isSelected: selectedChannel?.uniqueId == channel.uniqueId,
      isFavorite: favoriteIds.contains(channel.uniqueId),
      currentProgram: currentProgram,
      onTap: () {
        ref.read(selectedChannelProvider.notifier).state = channel;
      },
      onFavoriteToggle: () {
        final notifier = ref.read(favoriteChannelIdsProvider.notifier);
        final wasFavorite = notifier.isFavorite(channel.uniqueId);
        notifier.toggle(channel.uniqueId);

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
