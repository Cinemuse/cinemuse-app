import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_program_block.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// One channel's programs across the guide's time window, with the empty
/// stretches between them as blocks too.
///
/// The row owns its blocks' focus nodes, so they are thrown away when the
/// row scrolls off instead of piling up while the user scrolls.
class EpgProgramRow extends StatefulWidget {
  final Channel channel;
  final List<EpgProgram> programs;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double pixelsPerMinute;
  final double width;

  /// How far the guide is scrolled sideways now.
  final double Function() scrollOffset;
  final VoidCallback onTap;

  /// A block got the focus: its program (none for an empty stretch) and
  /// when it starts.
  final void Function(EpgProgram? program, DateTime start) onFocused;

  /// ← on the first block in view: back to the channel tile.
  final VoidCallback onLeftEdge;

  /// Up (-1) or Down (+1) from a block.
  final void Function(int delta) onVerticalMove;

  /// Page up (-1) or Page down (+1) from a block.
  final void Function(int direction) onPageMove;

  /// Lets the grid reach the row, for → from the channel tile.
  final void Function(EpgProgramRowState row) onMounted;
  final void Function(EpgProgramRowState row) onUnmounted;

  const EpgProgramRow({
    super.key,
    required this.channel,
    required this.programs,
    required this.windowStart,
    required this.windowEnd,
    required this.pixelsPerMinute,
    required this.width,
    required this.scrollOffset,
    required this.onTap,
    required this.onFocused,
    required this.onLeftEdge,
    required this.onVerticalMove,
    required this.onPageMove,
    required this.onMounted,
    required this.onUnmounted,
  });

  @override
  State<EpgProgramRow> createState() => EpgProgramRowState();
}

class EpgProgramRowState extends State<EpgProgramRow> {
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    widget.onMounted(this);
  }

  @override
  void didUpdateWidget(EpgProgramRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The grid's callbacks hold the row's index, which a rebuild can change.
    oldWidget.onUnmounted(this);
    widget.onMounted(this);
  }

  @override
  void dispose() {
    widget.onUnmounted(this);
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _focusNode(String key) => _focusNodes.putIfAbsent(
    key,
    () => FocusNode(debugLabel: 'GuideProg_$key'),
  );

  String _programKey(EpgProgram prog) =>
      '${prog.name}_${prog.startTime.millisecondsSinceEpoch}';

  /// Focuses the program on air at [time], or the next one, and says when
  /// it starts, as [EpgProgramRow.onFocused] will.
  DateTime focusAt(DateTime time) {
    if (widget.programs.isEmpty) {
      _focusNode('no_epg').requestFocus();
      return widget.windowStart;
    }
    final target = widget.programs.firstWhere(
      (p) => p.endTime.isAfter(time),
      orElse: () => widget.programs.last,
    );
    _focusNode(_programKey(target)).requestFocus();
    return target.startTime;
  }

  KeyEventResult _onBlockKey(KeyEvent event, double startOffset, bool isFirst) {
    final key = event.logicalKey;
    // A remote repeats a press held a fraction of a second: only the first
    // one turns a page, the repeats are swallowed (else the list scrolls a
    // page on its own, without the focus).
    if (key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown) {
      if (event is KeyDownEvent) {
        widget.onPageMove(key == LogicalKeyboardKey.pageUp ? -1 : 1);
      }
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowLeft &&
        (isFirst || startOffset <= widget.scrollOffset() + 40.0)) {
      widget.onLeftEdge();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      widget.onVerticalMove(key == LogicalKeyboardKey.arrowUp ? -1 : 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.programs.isEmpty) return _buildNoEpgPlaceholder(l10n);

    final windowStart = widget.windowStart;
    final windowEnd = widget.windowEnd;
    final slices = <Widget>[];
    DateTime cursor = windowStart;
    double accumulatedOffset = 0.0;
    bool isFirstBlock = true;

    for (final prog in widget.programs) {
      if (prog.endTime.isBefore(windowStart)) continue;
      if (prog.startTime.isAfter(windowEnd)) break;

      if (prog.startTime.isAfter(cursor)) {
        final gapMinutes = prog.startTime.difference(cursor).inMinutes;
        if (gapMinutes > 0) {
          final gapWidth = gapMinutes * widget.pixelsPerMinute;
          slices.add(
            _buildGapBlock(gapWidth, accumulatedOffset, isFirstBlock, cursor),
          );
          accumulatedOffset += gapWidth;
          isFirstBlock = false;
        }
      }

      // Starts where the row is drawn up to: guides can overlap programs,
      // and drawing the overlap twice makes the row longer than the window.
      final sliceStart = prog.startTime.isBefore(cursor)
          ? cursor
          : prog.startTime;
      final sliceEnd = prog.endTime.isAfter(windowEnd)
          ? windowEnd
          : prog.endTime;
      final sliceMinutes = sliceEnd.difference(sliceStart).inMinutes;

      if (sliceMinutes > 0) {
        final sliceWidth = sliceMinutes * widget.pixelsPerMinute;
        final startOffset = accumulatedOffset;
        final isFirst = isFirstBlock;

        slices.add(
          EpgProgramBlock(
            focusNode: _focusNode(_programKey(prog)),
            program: prog,
            channel: widget.channel,
            width: sliceWidth,
            isLive: prog.isLive,
            onTap: widget.onTap,
            onFocusChange: (focused) {
              if (focused) widget.onFocused(prog, prog.startTime);
            },
            onKeyEvent: (node, event) =>
                _onBlockKey(event, startOffset, isFirst),
          ),
        );
        accumulatedOffset += sliceWidth;
        isFirstBlock = false;
      }

      if (sliceEnd.isAfter(cursor)) {
        cursor = sliceEnd;
      }
    }

    if (cursor.isBefore(windowEnd)) {
      final trailingMinutes = windowEnd.difference(cursor).inMinutes;
      if (trailingMinutes > 0) {
        slices.add(
          _buildGapBlock(
            trailingMinutes * widget.pixelsPerMinute,
            accumulatedOffset,
            isFirstBlock,
            cursor,
          ),
        );
      }
    }

    return Container(
      decoration: _rowDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: slices,
      ),
    );
  }

  static final _rowDecoration = BoxDecoration(
    border: Border(
      bottom: BorderSide(
        color: Colors.white.withValues(alpha: 0.05),
        width: 0.5,
      ),
    ),
  );

  Widget _buildNoEpgPlaceholder(AppLocalizations l10n) {
    return Container(
      width: widget.width,
      padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 3.0),
      decoration: _rowDecoration,
      child: DpadFocusable(
        focusNode: _focusNode('no_epg'),
        onTap: widget.onTap,
        onFocusChange: (focused) {
          if (focused) widget.onFocused(null, widget.windowStart);
        },
        onKeyEvent: (node, event) => _onBlockKey(event, 0, true),
        borderRadius: BorderRadius.circular(6),
        isFocusRingInside: true,
        builder: (context, isFocused, isHovered, _) {
          final isHighlighted = isFocused || isHovered;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: isHighlighted
                  ? AppTheme.accent.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isHighlighted
                    ? AppTheme.accent
                    : Colors.white.withValues(alpha: 0.04),
              ),
            ),
            child: Text(
              l10n.liveTvNoEpg,
              style: TextStyle(
                color: isHighlighted ? Colors.white : AppTheme.textMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildGapBlock(
    double width,
    double startOffset,
    bool isFirst,
    DateTime start,
  ) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 3.0),
        child: DpadFocusable(
          focusNode: _focusNode('gap_${start.millisecondsSinceEpoch}'),
          onTap: widget.onTap,
          onFocusChange: (focused) {
            if (focused) widget.onFocused(null, start);
          },
          onKeyEvent: (node, event) => _onBlockKey(event, startOffset, isFirst),
          borderRadius: BorderRadius.circular(6),
          isFocusRingInside: true,
          builder: (context, isFocused, isHovered, _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: isFocused || isHovered
                    ? AppTheme.accent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isFocused || isHovered
                      ? AppTheme.accent
                      : Colors.white.withValues(alpha: 0.03),
                ),
              ),
              child: width > 80
                  ? Text(
                      widget.channel.name,
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : const SizedBox.shrink(),
            );
          },
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }
}
