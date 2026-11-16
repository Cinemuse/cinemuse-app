import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

/// A playback time as the player shows it: "4:05", "1:02:03".
String formatPlaybackTime(Duration d) {
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours}:$minutes:$seconds';
  }
  return '${d.inMinutes}:$seconds';
}

/// Where the mouse is along a seekbar's `Slider` track, from 0 to 1.
///
/// The slider draws its track inset on each side by the larger of the thumb
/// and overlay radius, and a click maps over that inset track. Mapping the
/// hover over the full width showed a time a few seconds off from where the
/// click jumped, more towards both ends (REV-288).
double seekbarHoverFraction({
  required double x,
  required double width,
  required double thumbRadius,
  required double overlayRadius,
}) {
  final inset = math.max(thumbRadius, overlayRadius);
  final trackWidth = width - 2 * inset;
  if (trackWidth <= 0) return 0;
  return ((x - inset) / trackWidth).clamp(0.0, 1.0);
}

/// The seekbar of a film or episode: the bar, then "12:34 / 1:45:00".
class VodSeekbar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final FocusNode? seekbarFocusNode;
  final FocusNode? playPauseFocusNode;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback? onInteraction;

  const VodSeekbar({
    super.key,
    required this.position,
    required this.duration,
    this.seekbarFocusNode,
    this.playPauseFocusNode,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final max = duration.inSeconds.toDouble();
    return _SeekbarRow(
      track: _SeekbarTrack(
        value: position.inSeconds.toDouble().clamp(0, max),
        min: 0,
        max: max,
        hoverLabel: (seconds) =>
            formatPlaybackTime(Duration(seconds: seconds.toInt())),
        focusNode: seekbarFocusNode,
        playPauseFocusNode: playPauseFocusNode,
        onChangeStart: onChangeStart,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
        onInteraction: onInteraction,
      ),
      trailing: Text(
        '${formatPlaybackTime(position)} / ${formatPlaybackTime(duration)}',
        style: TextStyle(
          color: AppTheme.textWhite.withValues(alpha: 0.85),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }
}

/// The seekbar of a live channel: the bar runs from the oldest buffered
/// moment to now, then the LIVE button, or how far behind live you are.
///
/// The bar's values are seconds behind live (negative); the callbacks get
/// the position in the stream, like the film's.
class LiveTvSeekbar extends StatelessWidget {
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

  double _positionFor(double secondsBehindLive) {
    final end = rawDuration.inSeconds.toDouble();
    return end + secondsBehindLive.clamp(-end, 0.0).truncateToDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (rawDuration <= Duration.zero) {
      return const SizedBox(height: 8);
    }

    final l10n = AppLocalizations.of(context)!;
    final live = l10n.liveTvLive.toUpperCase();
    final secondsBehindLive = -(rawDuration.inSeconds - position.inSeconds)
        .toDouble();
    final uiTotalSeconds = ((rawDuration.inSeconds / 60).ceil() * 60)
        .toDouble()
        .clamp(60.0, 7200.0);
    final isAtLive = !dragging && secondsBehindLive >= -30;

    return _SeekbarRow(
      track: _SeekbarTrack(
        value: isAtLive ? 0.0 : secondsBehindLive.clamp(-uiTotalSeconds, 0.0),
        min: -uiTotalSeconds,
        max: 0.0,
        hoverLabel: (behind) => behind > -6
            ? live
            : '-${formatPlaybackTime(Duration(seconds: -behind.toInt()))}',
        focusNode: seekbarFocusNode,
        playPauseFocusNode: playPauseFocusNode,
        onChangeStart: (v) => onChangeStart(_positionFor(v)),
        onChanged: (v) => onChanged(_positionFor(v)),
        onChangeEnd: (v) => onChangeEnd(_positionFor(v)),
        onInteraction: onInteraction,
      ),
      trailing: InkWell(
        mouseCursor: AppTheme.clickCursor,
        onTap: isAtLive
            ? null
            : () {
                onChangeStart(rawDuration.inSeconds.toDouble());
                onChangeEnd(rawDuration.inSeconds.toDouble());
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
                    ? live
                    : '-${formatPlaybackTime(Duration(seconds: secondsBehindLive.toInt().abs()))}',
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
    );
  }
}

class _SeekbarRow extends StatelessWidget {
  final Widget track;
  final Widget trailing;

  const _SeekbarRow({required this.track, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: track),
        const SizedBox(width: 12),
        trailing,
        const SizedBox(width: 8),
      ],
    );
  }
}

/// The bar itself, shared by films and live TV: the slider, the time shown
/// while hovering, and the remote's keys (left and right step 30 s, down goes
/// to play/pause).
class _SeekbarTrack extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final String Function(double value) hoverLabel;
  final FocusNode? focusNode;
  final FocusNode? playPauseFocusNode;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback? onInteraction;

  const _SeekbarTrack({
    required this.value,
    required this.min,
    required this.max,
    required this.hoverLabel,
    required this.focusNode,
    required this.playPauseFocusNode,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onInteraction,
  });

  @override
  State<_SeekbarTrack> createState() => _SeekbarTrackState();
}

class _SeekbarTrackState extends State<_SeekbarTrack> {
  static const _stepSeconds = 30;

  double? _hoverX;
  double? _hoverValue;
  bool _isFocused = false;
  DateTime? _lastStepTime;

  // Thicker only on the keys, like the ring.
  bool get _showsFocus => _isFocused && FocusRing.isKeyInput.value;
  double get _thumbRadius => _showsFocus ? 8 : 5;
  double get _overlayRadius => _showsFocus ? 14 : 10;

  @override
  void initState() {
    super.initState();
    FocusRing.isKeyInput.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    FocusRing.isKeyInput.removeListener(_handleInputChanged);
    super.dispose();
  }

  void _handleInputChanged() {
    if (_isFocused) setState(() {});
  }

  void _step(bool forward) {
    final target = (widget.value + (forward ? _stepSeconds : -_stepSeconds))
        .clamp(widget.min, widget.max);
    widget.onChangeStart(target);
    widget.onChanged(target);
    widget.onChangeEnd(target);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      widget.onInteraction?.call();
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (event is KeyDownEvent) {
        widget.playPauseFocusNode?.requestFocus();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      // A held key steps at most every 100 ms.
      final now = DateTime.now();
      if (event is KeyRepeatEvent &&
          _lastStepTime != null &&
          now.difference(_lastStepTime!).inMilliseconds < 100) {
        return KeyEventResult.handled;
      }
      _lastStepTime = now;
      _step(key == LogicalKeyboardKey.arrowRight);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          onHover: (event) {
            setState(() {
              _hoverX = event.localPosition.dx;
              final fraction = seekbarHoverFraction(
                x: _hoverX!,
                width: constraints.maxWidth,
                thumbRadius: _thumbRadius,
                overlayRadius: _overlayRadius,
              );
              _hoverValue = widget.min + fraction * (widget.max - widget.min);
            });
          },
          onExit: (_) {
            setState(() {
              _hoverX = null;
              _hoverValue = null;
            });
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Focus(
                focusNode: widget.focusNode,
                onFocusChange: (focused) {
                  setState(() => _isFocused = focused);
                },
                onKeyEvent: _handleKey,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: _showsFocus ? 5 : 2.5,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: _thumbRadius,
                    ),
                    overlayShape: RoundSliderOverlayShape(
                      overlayRadius: _overlayRadius,
                    ),
                    activeTrackColor: AppTheme.textWhite,
                    inactiveTrackColor: AppTheme.borderSubtle,
                    thumbColor: AppTheme.textWhite,
                    overlayColor: AppTheme.accentGlow,
                  ),
                  child: Slider(
                    value: widget.value,
                    min: widget.min,
                    max: widget.max,
                    onChangeStart: widget.onChangeStart,
                    onChangeEnd: widget.onChangeEnd,
                    onChanged: widget.onChanged,
                  ),
                ),
              ),
              if (_hoverX != null && _hoverValue != null)
                Positioned(
                  left: (_hoverX! - 35).clamp(0, constraints.maxWidth - 70),
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
                      widget.hoverLabel(_hoverValue!),
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
    );
  }
}
