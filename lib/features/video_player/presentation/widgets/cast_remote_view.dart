import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class CastRemoteView extends ConsumerWidget {
  final CinemaPlayerState playerState;
  final PlayerParams params;
  final VoidCallback onBackPressed;

  const CastRemoteView({
    super.key,
    required this.playerState,
    required this.params,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerControllerProvider(params).notifier);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Stack(
        children: [
          // Background Gradient or Backdrop
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.2),
                    AppTheme.primary,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppTheme.textWhite,
                        ),
                        onPressed: onBackPressed,
                      ),
                      const SizedBox(width: 8),
                      // The title is shown big below, and Stop is the
                      // labelled button at the bottom (REV-176).
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.castCastingTo(
                            playerState.selectedCastDevice?.name ??
                                AppLocalizations.of(context)!.castDefaultDevice,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Media Poster/Placeholder
                Flexible(
                  child: Container(
                    width: 200,
                    height: 300,
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOverlay,
                      borderRadius: AppTheme.radiusMd,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGlow,
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.movie,
                      size: 80,
                      color: AppTheme.borderSubtle,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title and Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        playerState.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppTheme.textWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (params.type == 'tv' &&
                          params.season != null &&
                          params.episode != null)
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.castSeasonEpisode(params.season!, params.episode!),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),

                // Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                          activeTrackColor: AppTheme.accent,
                          inactiveTrackColor: AppTheme.borderSubtle,
                          thumbColor: AppTheme.accent,
                        ),
                        child: _CastSeekbar(
                          position: playerState.remotePosition,
                          duration: playerState.remoteDuration,
                          onSeek: notifier.seek,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(playerState.remotePosition),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatDuration(playerState.remoteDuration),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Playback Controls
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(
                          Icons.replay_10,
                          color: AppTheme.textWhite,
                        ),
                        onPressed: () {
                          notifier.seek(
                            _clampToRemote(
                              playerState.remotePosition -
                                  const Duration(seconds: 10),
                            ),
                          );
                        },
                      ),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.accent,
                        child: IconButton(
                          iconSize: 50,
                          icon: Icon(
                            playerState.remotePlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: AppTheme.primary,
                          ),
                          onPressed: () {
                            if (playerState.remotePlaying) {
                              notifier.pause();
                            } else {
                              notifier.play();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(
                          Icons.forward_10,
                          color: AppTheme.textWhite,
                        ),
                        onPressed: () {
                          notifier.seek(
                            _clampToRemote(
                              playerState.remotePosition +
                                  const Duration(seconds: 10),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Dedicated Stop Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.stop),
                    label: Text(
                      AppLocalizations.of(context)!.commonStopCasting,
                    ),
                    onPressed: notifier.stopCasting,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The ±10 s buttons must not send a negative time or one past the end
  /// (REV-168). An unknown duration (zero) has no upper bound.
  Duration _clampToRemote(Duration target) {
    if (target < Duration.zero) return Duration.zero;
    final end = playerState.remoteDuration;
    return end > Duration.zero && target > end ? end : target;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

/// Follows the finger while dragging and seeks once on release: a seek per
/// drag frame flooded the Chromecast, and the thumb jumped back to the last
/// reported position until the next status update (REV-168).
class _CastSeekbar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _CastSeekbar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<_CastSeekbar> createState() => _CastSeekbarState();
}

class _CastSeekbarState extends State<_CastSeekbar> {
  double? _shownSeconds;
  bool _isDragging = false;

  @override
  void didUpdateWidget(_CastSeekbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The TV reported a new position: show it again.
    if (!_isDragging && widget.position != oldWidget.position) {
      _shownSeconds = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inSeconds.toDouble().clamp(
      1.0,
      double.infinity,
    );
    final value = _shownSeconds ?? widget.position.inSeconds.toDouble();
    return Slider(
      value: value.clamp(0.0, max),
      max: max,
      onChangeStart: (_) => _isDragging = true,
      onChanged: (v) => setState(() => _shownSeconds = v),
      onChangeEnd: (v) {
        _isDragging = false;
        widget.onSeek(Duration(seconds: v.toInt()));
      },
    );
  }
}
