import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/application/minute_clock_provider.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_empty_state.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_details_banner.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_timeline_grid.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/guide_top_bar.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/save_live_tv_change.dart';

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
  final _topBarKey = GlobalKey<GuideTopBarState>();

  /// What the focus is on, for the banner only: a move redraws the banner
  /// and the two blocks, not the whole guide (dozens of rows of 14 hours).
  /// A null program is the one on air now, re-read each minute (REV-278).
  final _focused = ValueNotifier<({Channel channel, EpgProgram? program})?>(
    null,
  );

  @override
  void dispose() {
    _focused.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(Channel ch) => saveLiveTvChange(
    context,
    ref,
    () => ref.read(favoriteChannelIdsProvider.notifier).toggle(ch.uniqueId),
  );

  /// Down from the top bar. With no channels, whatever is below (the
  /// empty list's button).
  void _focusGuide() {
    final grid = _gridKey.currentState;
    if (grid != null) {
      grid.focusFromAbove();
    } else {
      FocusManager.instance.primaryFocus?.focusInDirection(
        TraversalDirection.down,
      );
    }
  }

  void _onProgramFocused(Channel channel, EpgProgram? program) {
    final kept = (program?.isLive ?? false) ? null : program;
    final focused = _focused.value;
    if (focused?.channel.uniqueId != channel.uniqueId ||
        !identical(focused?.program, kept)) {
      _focused.value = (channel: channel, program: kept);
    }
  }

  /// With the [ref] of its own [Consumer], so a focus move redraws only the
  /// banner.
  Widget _buildBanner(
    WidgetRef ref,
    ({Channel channel, EpgProgram? program})? focused,
  ) {
    final selectedChannel = ref.watch(selectedChannelProvider);
    final favoriteIds = ref.watch(favoriteChannelIdsProvider);

    // A focused channel that left the list (playlist removed) is dropped.
    final isFocusedListed =
        ref.watch(filteredChannelsProvider).value?.contains(focused?.channel) ??
        false;
    final channel =
        (isFocusedListed ? focused?.channel : null) ?? selectedChannel;
    final program =
        (isFocusedListed ? focused?.program : null) ??
        (channel != null ? ref.watch(currentProgramProvider(channel)) : null);

    return EpgDetailsBanner(
      channel: channel,
      program: program,
      isFavorite: channel != null && favoriteIds.contains(channel.uniqueId),
      onToggleFavorite: channel != null ? () => _toggleFavorite(channel) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final channelsAsync = ref.watch(filteredChannelsProvider);
    final epgDataAsync = ref.watch(epgDataProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);
    final favoriteIds = ref.watch(favoriteChannelIdsProvider);
    final activeTab = ref.watch(liveTvTabProvider);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Column(
        children: [
          GuideTopBar(
            key: _topBarKey,
            focusNode: widget.focusNode,
            onJumpToNow: () => _gridKey.currentState?.jumpToNow(),
            onDownToGuide: _focusGuide,
          ),

          ValueListenableBuilder(
            valueListenable: _focused,
            builder: (context, focused, _) =>
                Consumer(builder: (_, ref, _) => _buildBanner(ref, focused)),
          ),

          Expanded(
            child: channelsAsync.when(
              data: (channels) {
                if (channels.isEmpty) {
                  return ChannelListEmptyState(tab: activeTab);
                }

                final epgData = epgDataAsync.value ?? {};

                return EpgTimelineGrid(
                  key: _gridKey,
                  channels: channels,
                  epgData: epgData,
                  now: ref.watch(minuteClockProvider),
                  selectedChannel: selectedChannel,
                  favoriteIds: favoriteIds,
                  onProgramFocused: _onProgramFocused,
                  onChannelSelected: widget.onChannelSelected,
                  onToggleFavorite: _toggleFavorite,
                  onUpFromTop: () => _topBarKey.currentState?.focusFromBelow(),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
              error: (_, _) => Center(
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
}
