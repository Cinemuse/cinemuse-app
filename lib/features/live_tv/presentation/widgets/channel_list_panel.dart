import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_tile.dart';

/// Left panel containing the scrollable channel list.
class ChannelListPanel extends ConsumerStatefulWidget {
  const ChannelListPanel({super.key});

  @override
  ConsumerState<ChannelListPanel> createState() => _ChannelListPanelState();
}

class _ChannelListPanelState extends ConsumerState<ChannelListPanel> {
  final ScrollController _channelScrollController = ScrollController();
  final ScrollController _groupScrollController = ScrollController();

  @override
  void dispose() {
    _channelScrollController.dispose();
    _groupScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected(List<Channel> channels, Channel? selected) {
    if (selected == null) return;
    final index = channels.indexWhere((ch) => ch.lcn == selected.lcn);
    if (index < 0) return;

    final offset = (index * 60.0).clamp(
      0.0,
      _channelScrollController.position.maxScrollExtent,
    );

    _channelScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final channelsAsync = ref.watch(filteredChannelsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final selectedGroup = ref.watch(liveTvSelectedGroupProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);
    final groupMode = ref.watch(liveTvGroupModeProvider);
    final panelFocus = ref.watch(liveTvPanelFocusProvider);

    final isGroupsFocused = panelFocus == LiveTvPanelFocus.groups;

    // Auto-scroll when selected channel changes
    ref.listen(selectedChannelProvider, (_, next) {
      if (next != null) {
        channelsAsync.whenData((channels) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_channelScrollController.hasClients) {
              _scrollToSelected(channels, next);
            }
          });
        });
      }
    });

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.6),
            border: Border(
              right: BorderSide(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          child: Row(
            children: [
              // 1. Group Rail (Categories / Providers)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!isGroupsFocused) {
                    ref.read(liveTvPanelFocusProvider.notifier).state = LiveTvPanelFocus.groups;
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.fastOutSlowIn,
                  clipBehavior: Clip.antiAlias,
                  width: isGroupsFocused ? 200 : 70, // Slightly wider for safer layout when collapsed
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withOpacity(0.4),
                    border: Border(
                      right: BorderSide(
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // 1. Static Header with Hamburger Icon
                      Container(
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
                                  child: Icon(
                                    Icons.menu,
                                    size: 22,
                                    color: Colors.white,
                                  ),
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
                                    l10n.liveTvBrowse,
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
                      ),
                      
                      const Divider(height: 1, color: Colors.white10),

                      // 2. Mode Toggle (Repositioned below header)
                      // Fixed height to prevent vertical shifting of the list below during animation
                      SizedBox(
                        height: 52,
                        child: isGroupsFocused
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                              child: _buildGroupingToggle(context, groupMode),
                            )
                          : Center(
                              child: _buildCompactGroupingToggle(context, groupMode),
                            ),
                      ),
                      
                      const SizedBox(height: 8),

                      // Groups List
                      Expanded(
                        child: groupsAsync.when(
                          data: (groups) => ListView.builder(
                            controller: _groupScrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final group = groups[index];
                              final isSelected = group == selectedGroup;
                              return _buildGroupTile(group, isSelected, isGroupsFocused, groupMode);
                            },
                          ),
                          loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Channel List Rail
              Expanded(
                child: GestureDetector(
                  onTapDown: (_) => ref.read(liveTvPanelFocusProvider.notifier).state = LiveTvPanelFocus.channels,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search area
                      // Search Field
                      Container(
                        height: 60, // Matches group rail header height
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        child: _buildSearchField(context),
                      ),

                      const Divider(height: 1, color: Colors.white10),

                      // Channel list
                      Expanded(
                        child: channelsAsync.when(
                          data: (channels) {
                            // 1. Group channels by sub-provider
                            final hasSubProviders = channels.any((ch) => ch.subProvider?.isNotEmpty == true);
                            
                            if (!hasSubProviders) {
                              return ListView.builder(
                                controller: _channelScrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                itemCount: channels.length,
                                itemExtent: 60,
                                itemBuilder: (context, index) {
                                  final channel = channels[index];
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
                                },
                              );
                            }

                            // 2. Prepare grouped list items
                            final grouped = <String, List<Channel>>{};
                            for (final ch in channels) {
                              final key = ch.subProvider?.isNotEmpty == true ? ch.subProvider! : 'General';
                              (grouped[key] ??= []).add(ch);
                            }

                            final allExpandedMap = ref.watch(expandedSubProvidersProvider);
                            final selectedGroup = ref.watch(liveTvSelectedGroupProvider);
                            
                            // Initialize this group's expanded state if it's the first visit
                            Set<String> expandedSet;
                            if (allExpandedMap.containsKey(selectedGroup)) {
                              expandedSet = allExpandedMap[selectedGroup]!;
                            } else {
                              // First visit logic
                              final targetSub = selectedChannel?.subProvider?.isNotEmpty == true 
                                  ? selectedChannel!.subProvider! 
                                  : (grouped.keys.isNotEmpty ? grouped.keys.first : 'General');
                              expandedSet = { targetSub };
                            }

                            final listItems = <dynamic>[];
                            for (final entry in grouped.entries) {
                              listItems.add(entry.key); // Header (String)
                              final isExpanded = expandedSet.contains(entry.key);
                              if (isExpanded) {
                                listItems.addAll(entry.value); // Channels
                              }
                            }

                            return ListView.builder(
                              controller: _channelScrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              itemCount: listItems.length,
                              itemBuilder: (context, index) {
                                final item = listItems[index];

                                if (item is String) {
                                  final isExpanded = expandedSet.contains(item);
                                  return _buildSubProviderHeader(context, item, isExpanded, expandedSet, selectedGroup);
                                }

                                final channel = item as Channel;
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
                              },
                            );
                          },
                          loading: () => const Center(
                            child: CircularProgressIndicator(color: AppTheme.accent),
                          ),
                          error: (error, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactGroupingToggle(BuildContext context, LiveTvGroupMode current) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCompactToggleButton(Icons.folder_outlined, LiveTvGroupMode.category, current),
        const SizedBox(width: 4),
        _buildCompactToggleButton(Icons.sensors_outlined, LiveTvGroupMode.provider, current),
      ],
    );
  }

  Widget _buildCompactToggleButton(IconData icon, LiveTvGroupMode mode, LiveTvGroupMode current) {
    final isSelected = mode == current;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => ref.read(liveTvGroupModeProvider.notifier).state = mode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.accent.withOpacity(0.3) : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: 16, // Slightly smaller for better fit
            color: isSelected ? AppTheme.accent : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupingToggle(BuildContext context, LiveTvGroupMode current) {
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
          Expanded(child: _buildToggleButton(l10n.liveTvCategories, LiveTvGroupMode.category, current)),
          Expanded(child: _buildToggleButton(l10n.liveTvProviders, LiveTvGroupMode.provider, current)),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, LiveTvGroupMode mode, LiveTvGroupMode current) {
    final isSelected = mode == current;
    return GestureDetector(
      onTap: () => ref.read(liveTvGroupModeProvider.notifier).state = mode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.accent.withOpacity(0.5) : Colors.transparent,
          ),
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

  Widget _buildGroupTile(String name, bool isSelected, bool isExpanded, LiveTvGroupMode mode) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(liveTvSelectedGroupProvider.notifier).state = name;
          // Auto-collapse and focus channels when a group is selected
          ref.read(liveTvPanelFocusProvider.notifier).state = LiveTvPanelFocus.channels;
        },
        child: Container(
          height: 44,
          child: Stack(
            children: [
              // 1. Content (Icon + Optional Text)
              Align(
                alignment: isExpanded ? Alignment.centerLeft : Alignment.center,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isExpanded ? 16 : 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Use min to allow Align to work
                    children: [
                      Icon(
                        _getGroupIcon(name, mode),
                        size: 20,
                        color: isSelected ? AppTheme.accent : Colors.white60,
                      ),
                      if (isExpanded) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isExpanded ? 1.0 : 0.0,
                            curve: Curves.easeIn,
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
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 2. Selection Indicator (Positioned overlay)
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubProviderHeader(BuildContext context, String title, bool isExpanded, Set<String> currentSet, String groupKey) {
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
                  child: const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      onChanged: (val) => ref.read(channelSearchQueryProvider.notifier).state = val,
      decoration: InputDecoration(
        hintText: l10n.liveTvSearchPlaceholder,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white30),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 13),
    );
  }
}

