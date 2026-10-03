import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/core/application/display_mode_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_playback_controls.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

class VideoBottomBar extends ConsumerStatefulWidget {
  final CinemaPlayerState playerState;
  final Duration? virtualPosition;
  final bool dragging;
  final Function(double) onChangeStart;
  final Function(double) onChangeEnd;
  final Function(double) onChanged;
  final VoidCallback onTogglePlayPause;
  final Function(bool) onSkip;
  final VoidCallback onToggleMute;
  final VoidCallback onStopPressed;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onSettingsPressed;
  final FocusNode? playPauseFocusNode;
  final FocusNode? seekbarFocusNode;

  const VideoBottomBar({
    super.key,
    required this.playerState,
    this.virtualPosition,
    required this.dragging,
    required this.onChangeStart,
    required this.onChangeEnd,
    required this.onChanged,
    required this.onTogglePlayPause,
    required this.onSkip,
    required this.onToggleMute,
    required this.onStopPressed,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.onNextEpisode,
    this.onSettingsPressed,
    this.playPauseFocusNode,
    this.seekbarFocusNode,
    this.isLive = false,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onOpenChannelGuide,
  });

  final bool isLive;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback? onOpenChannelGuide;

  @override
  ConsumerState<VideoBottomBar> createState() => _VideoBottomBarState();
}

class _VideoBottomBarState extends ConsumerState<VideoBottomBar> {
  double? _hoverX;
  Duration? _hoverDuration;
  bool _isHoveringSeekbar = false;
  bool _isSeekbarFocused = false;
  DateTime? _lastSeekbarStepTime;

  void _handleSeekbarStep(Player player, bool forward) {
    const stepSeconds = 10;
    final duration = player.state.duration;
    final currentPos = widget.virtualPosition ?? player.state.position;
    final newSec = (currentPos.inSeconds + (forward ? stepSeconds : -stepSeconds))
        .clamp(0, duration.inSeconds);

    widget.onChangeStart(newSec.toDouble());
    widget.onChanged(newSec.toDouble());
    widget.onChangeEnd(newSec.toDouble());
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.playerState.controller.player;
    final isBigPicture = ref.watch(isBigPictureProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppTheme.primary.withValues(alpha: 0.87),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seekbar (VOD and Live TV)
          StreamBuilder<Duration>(
            stream: player.stream.position,
            builder: (context, snapshot) {
              final rawDuration = player.state.duration;
              final position =
                  widget.virtualPosition ?? snapshot.data ?? Duration.zero;

              if (widget.isLive) {
                if (rawDuration <= Duration.zero) {
                  return const SizedBox(height: 8);
                }

                final secondsBehindLive =
                    -(rawDuration.inSeconds - position.inSeconds).toDouble();
                final uiTotalSeconds =
                    ((rawDuration.inSeconds / 60).ceil() * 60)
                        .toDouble()
                        .clamp(60.0, 7200.0);
                final safeMin = -uiTotalSeconds;
                final isAtLive =
                    !widget.dragging && secondsBehindLive >= -30;

                return Row(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return MouseRegion(
                            onHover: (event) {
                              setState(() {
                                _hoverX = event.localPosition.dx;
                                _isHoveringSeekbar = true;
                                final percent =
                                    (_hoverX! / constraints.maxWidth)
                                        .clamp(0.0, 1.0);
                                final hoverOffsetSeconds =
                                    ((1.0 - percent) * uiTotalSeconds).toInt();
                                _hoverDuration =
                                    Duration(seconds: hoverOffsetSeconds);
                              });
                            },
                            onExit: (_) {
                              setState(() {
                                _isHoveringSeekbar = false;
                                _hoverX = null;
                                _hoverDuration = null;
                              });
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Focus(
                                  focusNode: widget.seekbarFocusNode,
                                  onFocusChange: (focused) {
                                    setState(() => _isSeekbarFocused = focused);
                                  },
                                  onKeyEvent: (node, event) {
                                    if (event is! KeyDownEvent &&
                                        event is! KeyRepeatEvent) {
                                      return KeyEventResult.ignored;
                                    }

                                    if (event.logicalKey ==
                                        LogicalKeyboardKey.arrowDown) {
                                      if (event is KeyDownEvent) {
                                        widget.playPauseFocusNode?.requestFocus();
                                      }
                                      return KeyEventResult.handled;
                                    }

                                    if (event.logicalKey ==
                                        LogicalKeyboardKey.arrowUp) {
                                      return KeyEventResult.handled;
                                    }

                                    if (event.logicalKey ==
                                            LogicalKeyboardKey.arrowLeft ||
                                        event.logicalKey ==
                                            LogicalKeyboardKey.arrowRight) {
                                      final now = DateTime.now();
                                      if (event is KeyRepeatEvent) {
                                        if (_lastSeekbarStepTime != null &&
                                            now
                                                    .difference(
                                                      _lastSeekbarStepTime!,
                                                    )
                                                    .inMilliseconds <
                                                100) {
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      _lastSeekbarStepTime = now;
                                      _handleSeekbarStep(
                                        player,
                                        event.logicalKey ==
                                            LogicalKeyboardKey.arrowRight,
                                      );
                                      return KeyEventResult.handled;
                                    }

                                    return KeyEventResult.ignored;
                                  },
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: _isSeekbarFocused
                                          ? 5
                                          : (isBigPicture ? 4 : 2.5),
                                      thumbShape: RoundSliderThumbShape(
                                        enabledThumbRadius: _isSeekbarFocused
                                            ? 8
                                            : (isBigPicture ? 6 : 5),
                                      ),
                                      overlayShape: RoundSliderOverlayShape(
                                        overlayRadius: _isSeekbarFocused
                                            ? 14
                                            : (isBigPicture ? 12 : 10),
                                      ),
                                      activeTrackColor: Colors.white,
                                      inactiveTrackColor: Colors.white
                                          .withValues(alpha: 0.24),
                                      thumbColor: Colors.white,
                                      overlayColor: AppTheme.accentGlow,
                                    ),
                                    child: Slider(
                                      value: isAtLive
                                          ? 0.0
                                          : secondsBehindLive.clamp(safeMin, 0.0),
                                      min: safeMin,
                                      max: 0.0,
                                      onChangeStart: (v) {
                                        final clampedOffset = v.clamp(
                                          -rawDuration.inSeconds.toDouble(),
                                          0.0,
                                        );
                                        final target = rawDuration +
                                            Duration(seconds: clampedOffset.toInt());
                                        widget.onChangeStart(
                                            target.inSeconds.toDouble());
                                      },
                                      onChanged: (v) {
                                        final clampedOffset = v.clamp(
                                          -rawDuration.inSeconds.toDouble(),
                                          0.0,
                                        );
                                        final target = rawDuration +
                                            Duration(seconds: clampedOffset.toInt());
                                        widget.onChanged(
                                            target.inSeconds.toDouble());
                                      },
                                      onChangeEnd: (v) {
                                        final clampedOffset = v.clamp(
                                          -rawDuration.inSeconds.toDouble(),
                                          0.0,
                                        );
                                        final target = rawDuration +
                                            Duration(seconds: clampedOffset.toInt());
                                        widget.onChangeEnd(
                                            target.inSeconds.toDouble());
                                      },
                                    ),
                                  ),
                                ),
                                if (_isHoveringSeekbar &&
                                    _hoverX != null &&
                                    _hoverDuration != null)
                                  Positioned(
                                    left: (_hoverX! - 35).clamp(
                                      0,
                                      constraints.maxWidth - 70,
                                    ),
                                    top: -35,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          width: 0.5,
                                        ),
                                        boxShadow: AppTheme.shadowNeonSm,
                                      ),
                                      child: Text(
                                        _hoverDuration!.inSeconds <= 5
                                            ? 'LIVE'
                                            : '-${_formatDuration(_hoverDuration!)}',
                                        style: const TextStyle(
                                          color: AppTheme.textWhite,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: isAtLive
                          ? null
                          : () {
                              widget.onChangeStart(
                                  rawDuration.inSeconds.toDouble());
                              widget.onChangeEnd(
                                  rawDuration.inSeconds.toDouble());
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isAtLive
                                    ? AppTheme.favorites
                                    : AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isAtLive
                                  ? 'LIVE'
                                  : '-${_formatDuration(Duration(seconds: secondsBehindLive.toInt().abs()))}',
                              style: TextStyle(
                                color: isAtLive
                                    ? AppTheme.favorites
                                    : AppTheme.textWhite,
                                fontSize: isBigPicture ? 14 : 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              }

              // VOD Seekbar
              final duration = player.state.duration;
              return Row(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return MouseRegion(
                          onHover: (event) {
                            setState(() {
                              _hoverX = event.localPosition.dx;
                              _isHoveringSeekbar = true;
                              final percent = (_hoverX! / constraints.maxWidth)
                                  .clamp(0.0, 1.0);
                              _hoverDuration = Duration(
                                seconds: (duration.inSeconds * percent).toInt(),
                              );
                            });
                          },
                          onExit: (_) {
                            setState(() {
                              _isHoveringSeekbar = false;
                              _hoverX = null;
                              _hoverDuration = null;
                            });
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Focus(
                                focusNode: widget.seekbarFocusNode,
                                onFocusChange: (focused) {
                                  setState(() => _isSeekbarFocused = focused);
                                },
                                onKeyEvent: (node, event) {
                                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                                    return KeyEventResult.ignored;
                                  }

                                  if (event.logicalKey ==
                                      LogicalKeyboardKey.arrowDown) {
                                    if (event is KeyDownEvent) {
                                      widget.playPauseFocusNode?.requestFocus();
                                    }
                                    return KeyEventResult.handled;
                                  }

                                  if (event.logicalKey ==
                                      LogicalKeyboardKey.arrowUp) {
                                    return KeyEventResult.handled;
                                  }

                                  if (event.logicalKey ==
                                          LogicalKeyboardKey.arrowLeft ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.arrowRight) {
                                    final now = DateTime.now();
                                    if (event is KeyRepeatEvent) {
                                      if (_lastSeekbarStepTime != null &&
                                          now
                                                  .difference(
                                                    _lastSeekbarStepTime!,
                                                  )
                                                  .inMilliseconds <
                                              100) {
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    _lastSeekbarStepTime = now;
                                    _handleSeekbarStep(
                                      player,
                                      event.logicalKey ==
                                          LogicalKeyboardKey.arrowRight,
                                    );
                                    return KeyEventResult.handled;
                                  }

                                  return KeyEventResult.ignored;
                                },
                                child: Builder(
                                  builder: (context) {
                                    return SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: _isSeekbarFocused
                                            ? 5
                                            : (isBigPicture ? 4 : 2.5),
                                        thumbShape: RoundSliderThumbShape(
                                          enabledThumbRadius: _isSeekbarFocused
                                              ? 8
                                              : (isBigPicture ? 6 : 5),
                                        ),
                                        overlayShape: RoundSliderOverlayShape(
                                          overlayRadius: _isSeekbarFocused
                                              ? 14
                                              : (isBigPicture ? 12 : 10),
                                        ),
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor:
                                            Colors.white.withValues(alpha: 0.24),
                                        thumbColor: Colors.white,
                                        overlayColor:
                                            AppTheme.accentGlow,
                                      ),
                                      child: Slider(
                                        value: position.inSeconds
                                            .toDouble()
                                            .clamp(
                                              0,
                                              duration.inSeconds.toDouble(),
                                            ),
                                        min: 0,
                                        max: duration.inSeconds.toDouble(),
                                        onChangeStart: widget.onChangeStart,
                                        onChangeEnd: widget.onChangeEnd,
                                        onChanged: widget.onChanged,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (_isHoveringSeekbar &&
                                  _hoverX != null &&
                                  _hoverDuration != null)
                                Positioned(
                                  left: (_hoverX! - 35).clamp(
                                    0,
                                    constraints.maxWidth - 70,
                                  ),
                                  top: -35,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.75,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        width: 0.5,
                                      ),
                                      boxShadow: AppTheme.shadowNeonSm,
                                    ),
                                    child: Text(
                                      _formatDuration(_hoverDuration!),
                                      style: const TextStyle(
                                        color: AppTheme.textWhite,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: TextStyle(
                      color: AppTheme.textWhite.withValues(alpha: 0.85),
                      fontSize: isBigPicture ? 14 : 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
          // Bottom Controls Row
          VideoPlaybackControls(
            playerState: widget.playerState,
            onTogglePlayPause: widget.onTogglePlayPause,
            onSkip: widget.onSkip,
            onToggleMute: widget.onToggleMute,
            onStopPressed: widget.onStopPressed,
            isFullscreen: widget.isFullscreen,
            onToggleFullscreen: widget.onToggleFullscreen,
            onNextEpisode: widget.onNextEpisode,
            onSettingsPressed: widget.onSettingsPressed,
            playPauseFocusNode: widget.playPauseFocusNode,
            seekbarFocusNode: widget.seekbarFocusNode,
            isLive: widget.isLive,
            onPreviousChannel: widget.onPreviousChannel,
            onNextChannel: widget.onNextChannel,
            onOpenChannelGuide: widget.onOpenChannelGuide,
          ),
        ],
      ),
    );
  }
}
