import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

/// Seekbar component for VOD video playback, handling timeline scrubbing,
/// hover time preview tooltips, and TV D-Pad navigation.
class VodSeekbar extends StatefulWidget {
  final Player player;
  final Duration position;
  final Duration duration;
  final bool isBigPicture;
  final FocusNode? seekbarFocusNode;
  final FocusNode? playPauseFocusNode;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback? onInteraction;

  const VodSeekbar({
    super.key,
    required this.player,
    required this.position,
    required this.duration,
    required this.isBigPicture,
    this.seekbarFocusNode,
    this.playPauseFocusNode,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    this.onInteraction,
  });

  @override
  State<VodSeekbar> createState() => _VodSeekbarState();
}

class _VodSeekbarState extends State<VodSeekbar> {
  double? _hoverX;
  Duration? _hoverDuration;
  bool _isHoveringSeekbar = false;
  bool _isSeekbarFocused = false;
  DateTime? _lastSeekbarStepTime;

  void _handleSeekbarStep(bool forward) {
    const stepSeconds = 30;
    final duration = widget.duration;
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
    final duration = widget.duration;
    final position = widget.position;

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
                          trackHeight: _isSeekbarFocused
                              ? 5
                              : (widget.isBigPicture ? 4 : 2.5),
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: _isSeekbarFocused
                                ? 8
                                : (widget.isBigPicture ? 6 : 5),
                          ),
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: _isSeekbarFocused
                                ? 14
                                : (widget.isBigPicture ? 12 : 10),
                          ),
                          activeTrackColor: AppTheme.textWhite,
                          inactiveTrackColor: AppTheme.borderSubtle,
                          thumbColor: AppTheme.textWhite,
                          overlayColor: AppTheme.accentGlow,
                        ),
                        child: Slider(
                          value: position.inSeconds.toDouble().clamp(
                            0,
                            duration.inSeconds.toDouble(),
                          ),
                          min: 0,
                          max: duration.inSeconds.toDouble(),
                          onChangeStart: widget.onChangeStart,
                          onChangeEnd: widget.onChangeEnd,
                          onChanged: widget.onChanged,
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
            fontSize: widget.isBigPicture ? 14 : 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
