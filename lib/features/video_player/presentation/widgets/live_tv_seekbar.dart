import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

/// Seekbar component for Live TV streams, handling timeshift offsets and live indicators.
class LiveTvSeekbar extends StatefulWidget {
  final Player player;
  final Duration rawDuration;
  final Duration position;
  final bool dragging;
  final FocusNode? seekbarFocusNode;
  final FocusNode? playPauseFocusNode;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback? onInteraction;

  const LiveTvSeekbar({
    super.key,
    required this.player,
    required this.rawDuration,
    required this.position,
    required this.dragging,
    this.seekbarFocusNode,
    this.playPauseFocusNode,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    this.onInteraction,
  });

  @override
  State<LiveTvSeekbar> createState() => _LiveTvSeekbarState();
}

class _LiveTvSeekbarState extends State<LiveTvSeekbar> {
  double? _hoverX;
  Duration? _hoverDuration;
  bool _isHoveringSeekbar = false;
  bool _isSeekbarFocused = false;
  DateTime? _lastSeekbarStepTime;

  void _handleSeekbarStep(bool forward) {
    const stepSeconds = 30;
    final duration = widget.player.state.duration;
    final currentPos = widget.position;
    final newSec =
        (currentPos.inSeconds + (forward ? stepSeconds : -stepSeconds)).clamp(
          0,
          duration.inSeconds,
        );

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
    if (widget.rawDuration <= Duration.zero) {
      return const SizedBox(height: 8);
    }

    final l10n = AppLocalizations.of(context)!;
    final secondsBehindLive =
        -(widget.rawDuration.inSeconds - widget.position.inSeconds).toDouble();
    final uiTotalSeconds = ((widget.rawDuration.inSeconds / 60).ceil() * 60)
        .toDouble()
        .clamp(60.0, 7200.0);
    final safeMin = -uiTotalSeconds;
    final isAtLive = !widget.dragging && secondsBehindLive >= -30;

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
                    final percent = (_hoverX! / constraints.maxWidth).clamp(
                      0.0,
                      1.0,
                    );
                    final hoverOffsetSeconds =
                        ((1.0 - percent) * uiTotalSeconds).toInt();
                    _hoverDuration = Duration(seconds: hoverOffsetSeconds);
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

                        if (event is KeyDownEvent) {
                          widget.onInteraction?.call();
                        }

                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          if (event is KeyDownEvent) {
                            widget.playPauseFocusNode?.requestFocus();
                          }
                          return KeyEventResult.handled;
                        }

                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          return KeyEventResult.handled;
                        }

                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                            event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          final now = DateTime.now();
                          if (event is KeyRepeatEvent) {
                            if (_lastSeekbarStepTime != null &&
                                now
                                        .difference(_lastSeekbarStepTime!)
                                        .inMilliseconds <
                                    100) {
                              return KeyEventResult.handled;
                            }
                          }
                          _lastSeekbarStepTime = now;
                          _handleSeekbarStep(
                            event.logicalKey == LogicalKeyboardKey.arrowRight,
                          );
                          return KeyEventResult.handled;
                        }

                        return KeyEventResult.ignored;
                      },
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: _isSeekbarFocused ? 5 : 2.5,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: _isSeekbarFocused ? 8 : 5,
                          ),
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: _isSeekbarFocused ? 14 : 10,
                          ),
                          activeTrackColor: AppTheme.textWhite,
                          inactiveTrackColor: AppTheme.borderSubtle,
                          thumbColor: AppTheme.textWhite,
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
                              -widget.rawDuration.inSeconds.toDouble(),
                              0.0,
                            );
                            final target =
                                widget.rawDuration +
                                Duration(seconds: clampedOffset.toInt());
                            widget.onChangeStart(target.inSeconds.toDouble());
                          },
                          onChanged: (v) {
                            final clampedOffset = v.clamp(
                              -widget.rawDuration.inSeconds.toDouble(),
                              0.0,
                            );
                            final target =
                                widget.rawDuration +
                                Duration(seconds: clampedOffset.toInt());
                            widget.onChanged(target.inSeconds.toDouble());
                          },
                          onChangeEnd: (v) {
                            final clampedOffset = v.clamp(
                              -widget.rawDuration.inSeconds.toDouble(),
                              0.0,
                            );
                            final target =
                                widget.rawDuration +
                                Duration(seconds: clampedOffset.toInt());
                            widget.onChangeEnd(target.inSeconds.toDouble());
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
                            color: AppTheme.surfaceOverlay,
                            borderRadius: AppTheme.radiusSm,
                            border: Border.all(
                              color: AppTheme.borderSubtle,
                              width: 0.5,
                            ),
                            boxShadow: AppTheme.shadowNeonSm,
                          ),
                          child: Text(
                            _hoverDuration!.inSeconds <= 5
                                ? l10n.liveTvLive.toUpperCase()
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
          mouseCursor: AppTheme.clickCursor,
          onTap: isAtLive
              ? null
              : () {
                  widget.onChangeStart(widget.rawDuration.inSeconds.toDouble());
                  widget.onChangeEnd(widget.rawDuration.inSeconds.toDouble());
                },
          borderRadius: AppTheme.radiusMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAtLive ? AppTheme.favorites : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isAtLive
                      ? l10n.liveTvLive.toUpperCase()
                      : '-${_formatDuration(Duration(seconds: secondsBehindLive.toInt().abs()))}',
                  style: TextStyle(
                    color: isAtLive ? AppTheme.favorites : AppTheme.textWhite,
                    fontSize: 12,
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
}
