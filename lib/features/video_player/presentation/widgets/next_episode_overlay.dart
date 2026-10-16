import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/constants/playback_constants.dart';
import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

class NextEpisodeOverlay extends ConsumerStatefulWidget {
  final CinemaPlayerState playerState;
  final VoidCallback onNextEpisode;

  const NextEpisodeOverlay({
    super.key,
    required this.playerState,
    required this.onNextEpisode,
  });

  @override
  ConsumerState<NextEpisodeOverlay> createState() => _NextEpisodeOverlayState();
}

class _NextEpisodeOverlayState extends ConsumerState<NextEpisodeOverlay> {
  final _focusNode = FocusNode(debugLabel: 'NextEpisodeButton');
  bool _wasShown = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Takes the keyboard / remote focus once each time the button slides in,
  /// so Enter plays the next episode (REV-289, PROJECT.md → 6. Player).
  void _focusWhenShown(bool isShown) {
    if (isShown && !_wasShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
    _wasShown = isShown;
  }

  @override
  Widget build(BuildContext context) {
    final playerState = widget.playerState;
    if (playerState.nextEpisode == null) return const SizedBox.shrink();

    final l10n = ref.watch(localizationsProvider);
    final scrimColor = Theme.of(context).colorScheme.scrim;
    final player = playerState.controller.player;

    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, snapshot) {
        final pos = snapshot.data?.inSeconds ?? player.state.position.inSeconds;
        final dur = player.state.duration.inSeconds;
        if (dur <= 0) return const SizedBox.shrink();
        final isFinished =
            (dur - pos < PlaybackThresholds.completionRemainingSeconds) ||
            (pos / dur > PlaybackThresholds.completionPercentage);
        _focusWhenShown(isFinished);

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuart,
          bottom: isFinished ? 100 : -100,
          right: 32,
          // DpadFocusable, not a GestureDetector: a remote must reach it
          // (REV-165). Off-screen while hidden: no focus then.
          child: ExcludeFocus(
            excluding: !isFinished,
            child: DpadFocusable(
              focusNode: _focusNode,
              onTap: widget.onNextEpisode,
              scale: 1.05,
              builder: (context, isFocused, isHovered, _) {
                final isActive = isFocused || isHovered;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.textWhite.withValues(
                          alpha: isActive ? 0.95 : 0.85,
                        ),
                        AppTheme.textWhite.withValues(
                          alpha: isActive ? 0.85 : 0.65,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppTheme.radiusLg,
                    border: Border.all(
                      color: isFocused
                          ? AppTheme.focusRing
                          : AppTheme.textWhite.withValues(
                              alpha: isActive ? 0.4 : 0.2,
                            ),
                      width: isFocused ? 2.5 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scrimColor.withValues(
                          alpha: isActive ? 0.4 : 0.3,
                        ),
                        blurRadius: isActive ? 30 : 25,
                        offset: Offset(0, isActive ? 12 : 10),
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.playerNextEpisode.toUpperCase(),
                        style: TextStyle(
                          color: scrimColor.withValues(alpha: 0.85),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: scrimColor.withValues(alpha: 0.85),
                        size: 18,
                      ),
                    ],
                  ),
                );
              },
              child: const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
