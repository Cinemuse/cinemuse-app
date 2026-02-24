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
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected(List<Channel> channels, Channel? selected) {
    if (selected == null) return;
    final index = channels.indexWhere((ch) => ch.lcn == selected.lcn);
    if (index < 0) return;

    final offset = (index * 60.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final channelsAsync = ref.watch(channelsProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);

    // Auto-scroll when selected channel changes
    ref.listen(selectedChannelProvider, (_, next) {
      if (next != null) {
        channelsAsync.whenData((channels) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Channel list
              Expanded(
                child: channelsAsync.when(
                  data: (channels) {
                    if (channels.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.liveTvNoChannels,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      itemCount: channels.length,
                      itemExtent: 60,
                      itemBuilder: (context, index) {
                        final channel = channels[index];
                        final currentProgram =
                            ref.watch(currentProgramProvider(channel));

                        return ChannelListTile(
                          channel: channel,
                          isSelected:
                              selectedChannel?.lcn == channel.lcn,
                          currentProgram: currentProgram,
                          onTap: () {
                            ref
                                .read(selectedChannelProvider.notifier)
                                .state = channel;
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.liveTvError,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(channelsProvider),
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
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
