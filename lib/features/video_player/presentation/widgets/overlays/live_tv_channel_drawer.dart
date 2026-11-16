import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_panel.dart';

/// Modal overlay drawer that slides in from the left containing the channel list
/// for quick TV zapping during live playback.
class LiveTvChannelDrawer extends ConsumerWidget {
  final VoidCallback onClose;

  const LiveTvChannelDrawer({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverlayOpen = ref.watch(liveTvChannelOverlayProvider);
    if (!isOverlayOpen) return const SizedBox.shrink();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onClose,
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 380,
          child: RepaintBoundary(
            child: FocusScope(
              autofocus: true,
              child: ChannelListPanel(isOverlay: true, onClose: onClose),
            ),
          ),
        ),
      ],
    );
  }
}
