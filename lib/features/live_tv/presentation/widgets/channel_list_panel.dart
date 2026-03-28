import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_tile.dart';

/// Optimized Live TV panel with isolated rebuilds for better performance.
class ChannelListPanel extends ConsumerWidget {
  const ChannelListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.6),
            border: isMobile 
              ? null
              : Border(right: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: isMobile ? const _MobileLayout() : const _DesktopLayout(),
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _GroupSidebar(),
        Expanded(child: _ChannelSection()),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _MobileGroupBar(),
        Expanded(child: _ChannelSection()),
      ],
    );
  }
}

/// Left vertical rail for groups (Desktop).
class _GroupSidebar extends ConsumerWidget {
  const _GroupSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isGroupsFocused = ref.watch(liveTvPanelFocusProvider.select((f) => f == LiveTvPanelFocus.groups));
    final groupMode = ref.watch(liveTvGroupModeProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final selectedGroup = ref.watch(liveTvSelectedGroupProvider);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!isGroupsFocused) {
          ref.read(liveTvPanelFocusProvider.notifier).state = LiveTvPanelFocus.groups;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.fastOutSlowIn,
        width: isGroupsFocused ? 200 : 70,
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.4),
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Column(
          children: [
            _GroupSidebarHeader(isGroupsFocused: isGroupsFocused, label: l10n.liveTvBrowse),
            const Divider(height: 1, color: Colors.white10),
            
            // Mode Toggle
            SizedBox(
              height: 52,
              child: isGroupsFocused
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: _GroupingToggle(current: groupMode),
                  )
                : Center(
                    child: _CompactGroupingToggle(current: groupMode),
                  ),
            ),
            
            const SizedBox(height: 8),

            // Groups List
            Expanded(
              child: groupsAsync.when(
                data: (groups) => ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _GroupTile(
                      name: group,
                      isSelected: group == selectedGroup,
                      isExpanded: isGroupsFocused,
                      mode: groupMode,
                    );
                  },
                ),
                loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSidebarHeader extends ConsumerWidget {
  final bool isGroupsFocused;
  final String label;

  const _GroupSidebarHeader({required this.isGroupsFocused, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: isGroupsFocused ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          if (isGroupsFocused) const SizedBox(width: 8), 
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                ref.read(liveTvPanelFocusProvider.notifier).state = 
                  isGroupsFocused ? LiveTvPanelFocus.channels : LiveTvPanelFocus.groups;
              },
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Icon(Icons.menu, size: 22, color: Colors.white),
              ),
            ),
          ),
          if (isGroupsFocused) ...[
            const SizedBox(width: 4),
            Flexible(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isGroupsFocused ? 1.0 : 0.0,
                curve: Curves.easeIn,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Top horizontal bar for groups (Mobile).
class _MobileGroupBar extends ConsumerWidget {
  const _MobileGroupBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final selectedGroup = ref.watch(liveTvSelectedGroupProvider);
    final groupMode = ref.watch(liveTvGroupModeProvider);

    return Container(
      height: 56,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.only(left: 12, right: 8),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: _CompactGroupingToggle(current: groupMode),
          ),
          Expanded(
            child: groupsAsync.when(
              data: (groups) => ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _MobileGroupPill(
                    name: group,
                    isSelected: group == selectedGroup,
                    mode: groupMode,
                  );
                },
              ),
              loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Channel list section (Search + List).
class _ChannelSection extends ConsumerStatefulWidget {
  const _ChannelSection();

  @override
  ConsumerState<_ChannelSection> createState() => _ChannelSectionState();
}

class _ChannelSectionState extends ConsumerState<_ChannelSection> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToSelected(List<Channel> channels, Channel? selected) {
    if (selected == null || !_scrollController.hasClients) return;
    final index = channels.indexWhere((ch) => ch.lcn == selected.lcn);
    if (index < 0) return;

    final offset = (index * 60.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(filteredChannelsProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);
    final selectedGroup = ref.watch(liveTvSelectedGroupProvider);

    // Auto-scroll when selected channel changes
    ref.listen(selectedChannelProvider, (_, next) {
      if (next != null) {
        channelsAsync.whenData((channels) => _scrollToSelected(channels, next));
      }
    });

    final isMobile = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onTapDown: (_) => ref.read(liveTvPanelFocusProvider.notifier).state = LiveTvPanelFocus.channels,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SearchField(),
          if (!isMobile) const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: _ChannelListView(
              channelsAsync: channelsAsync,
              selectedChannel: selectedChannel,
              selectedGroup: selectedGroup,
              scrollController: _scrollController,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(channelSearchQueryProvider));
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      height: isMobile ? 52 : 60,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
      alignment: Alignment.center,
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: l10n.liveTvSearchPlaceholder,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white30),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: _controller.text.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.white30),
                onPressed: () {
                  _controller.clear();
                  _onChanged('');
                  setState(() {});
                },
              )
            : null,
        ),
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}

class _ChannelListView extends ConsumerWidget {
  final AsyncValue<List<Channel>> channelsAsync;
  final Channel? selectedChannel;
  final String? selectedGroup;
  final ScrollController scrollController;

  const _ChannelListView({
    required this.channelsAsync,
    required this.selectedChannel,
    required this.selectedGroup,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return channelsAsync.when(
      data: (channels) {
        final hasSubProviders = channels.any((ch) => ch.subProvider?.isNotEmpty == true);
        
        if (!hasSubProviders) {
          return ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: channels.length,
            itemExtent: 60,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return _ChannelTileWrapper(channel: channel, selectedChannel: selectedChannel);
            },
          );
        }

        final grouped = <String, List<Channel>>{};
        for (final ch in channels) {
          final key = ch.subProvider?.isNotEmpty == true ? ch.subProvider! : 'General';
          (grouped[key] ??= []).add(ch);
        }

        final allExpandedMap = ref.watch(expandedSubProvidersProvider);
        Set<String> expandedSet;
        if (allExpandedMap.containsKey(selectedGroup)) {
          expandedSet = allExpandedMap[selectedGroup]!;
        } else {
          final targetSub = selectedChannel?.subProvider?.isNotEmpty == true 
              ? selectedChannel!.subProvider! 
              : (grouped.keys.isNotEmpty ? grouped.keys.first : 'General');
          expandedSet = { targetSub };
        }

        final listItems = <dynamic>[];
        for (final entry in grouped.entries) {
          listItems.add(entry.key);
          if (expandedSet.contains(entry.key)) listItems.addAll(entry.value);
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          itemCount: listItems.length,
          itemBuilder: (context, index) {
            final item = listItems[index];
            if (item is String) {
              return _SubProviderHeader(
                title: item,
                isExpanded: expandedSet.contains(item),
                currentSet: expandedSet,
                groupKey: selectedGroup ?? '',
              );
            }
            return _ChannelTileWrapper(channel: item as Channel, selectedChannel: selectedChannel);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ChannelTileWrapper extends ConsumerWidget {
  final Channel channel;
  final Channel? selectedChannel;

  const _ChannelTileWrapper({required this.channel, this.selectedChannel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProgram = ref.watch(currentProgramProvider(channel));
    return ChannelListTile(
      channel: channel,
      isSelected: selectedChannel?.uniqueId == channel.uniqueId,
      currentProgram: currentProgram,
      onTap: () {
        ref.read(selectedChannelProvider.notifier).state = channel;
        ref.read(liveTvPanelFocusProvider.notifier).state = LiveTvPanelFocus.channels;
      },
    );
  }
}

class _GroupTile extends ConsumerWidget {
  final String name;
  final bool isSelected;
  final bool isExpanded;
  final LiveTvGroupMode mode;

  const _GroupTile({required this.name, required this.isSelected, required this.isExpanded, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(liveTvSelectedGroupProvider.notifier).state = name;
          ref.read(liveTvPanelFocusProvider.notifier).state = LiveTvPanelFocus.channels;
        },
        child: Container(
          height: 44,
          child: Stack(
            children: [
              Align(
                alignment: isExpanded ? Alignment.centerLeft : Alignment.center,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isExpanded ? 16 : 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getGroupIcon(name, mode), size: 20, color: isSelected ? AppTheme.accent : Colors.white60),
                      if (isExpanded) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  left: 0, top: 8, bottom: 8,
                  child: Container(
                    width: 3,
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(3)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileGroupPill extends ConsumerWidget {
  final String name;
  final bool isSelected;
  final LiveTvGroupMode mode;

  const _MobileGroupPill({required this.name, required this.isSelected, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ref.read(liveTvSelectedGroupProvider.notifier).state = name,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? AppTheme.accent.withOpacity(0.4) : Colors.transparent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getGroupIcon(name, mode), size: 16, color: isSelected ? AppTheme.accent : Colors.white60),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactGroupingToggle extends ConsumerWidget {
  final LiveTvGroupMode current;
  const _CompactGroupingToggle({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextMode = current == LiveTvGroupMode.category ? LiveTvGroupMode.provider : LiveTvGroupMode.category;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => ref.read(liveTvGroupModeProvider.notifier).state = nextMode,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.surface.withAlpha(128),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompactToggleButton(icon: Icons.folder_outlined, isSelected: current == LiveTvGroupMode.category),
              const SizedBox(width: 4),
              _CompactToggleButton(icon: Icons.sensors_outlined, isSelected: current == LiveTvGroupMode.provider),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;

  const _CompactToggleButton({required this.icon, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accent.withAlpha(40) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? AppTheme.accent.withAlpha(80) : Colors.transparent),
      ),
      child: Icon(icon, size: 16, color: isSelected ? AppTheme.accent : Colors.white60),
    );
  }
}

class _GroupingToggle extends ConsumerWidget {
  final LiveTvGroupMode current;
  const _GroupingToggle({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(child: _ToggleButton(label: l10n.liveTvCategories, mode: LiveTvGroupMode.category, current: current)),
          Expanded(child: _ToggleButton(label: l10n.liveTvProviders, mode: LiveTvGroupMode.provider, current: current)),
        ],
      ),
    );
  }
}

class _ToggleButton extends ConsumerWidget {
  final String label;
  final LiveTvGroupMode mode;
  final LiveTvGroupMode current;

  const _ToggleButton({required this.label, required this.mode, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = mode == current;
    return GestureDetector(
      onTap: () => ref.read(liveTvGroupModeProvider.notifier).state = mode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.accent.withOpacity(0.5) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textMuted,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SubProviderHeader extends ConsumerWidget {
  final String title;
  final bool isExpanded;
  final Set<String> currentSet;
  final String groupKey;

  const _SubProviderHeader({
    required this.title,
    required this.isExpanded,
    required this.currentSet,
    required this.groupKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Material(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            final nextSet = Set<String>.from(currentSet);
            if (nextSet.contains(title)) {
              nextSet.remove(title);
            } else {
              nextSet.add(title);
            }
            final nextMap = Map<String, Set<String>>.from(ref.read(expandedSubProvidersProvider));
            nextMap[groupKey] = nextSet;
            ref.read(expandedSubProvidersProvider.notifier).state = nextMap;
          },
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: isExpanded ? 0 : 0.25,
                  child: const Icon(Icons.chevron_right, size: 16, color: AppTheme.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _getGroupIcon(String name, LiveTvGroupMode mode) {
  if (mode == LiveTvGroupMode.provider) return Icons.lan;
  final n = name.toLowerCase();
  if (n.contains('sport')) return Icons.sports_soccer;
  if (n.contains('cinema') || n.contains('film')) return Icons.movie;
  if (n.contains('bambini') || n.contains('kids')) return Icons.child_care;
  if (n.contains('musica')) return Icons.music_note;
  if (n.contains('news') || n.contains('notizie')) return Icons.newspaper;
  if (n.contains('documentar')) return Icons.science;
  if (n.contains('generale')) return Icons.tv;
  return Icons.label_outline;
}
