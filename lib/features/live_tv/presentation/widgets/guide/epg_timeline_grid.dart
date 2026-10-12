import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_channel_matcher.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_time_ruler.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_channel_column.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_program_block.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// Timeline grid for the EPG TV Guide.
///
/// - Rows are virtualized vertically (synchronized [ListView.builder]s), but
///   each row builds its whole time window
/// - Repaint boundaries on channel tiles and program rows
/// - Programs per channel cached until the channels or the guide change
/// - Arrow-key navigation between channel tiles and program blocks
class EpgTimelineGrid extends StatefulWidget {
  final List<Channel> channels;
  final Map<String, List<EpgProgram>> epgData;
  final Channel? selectedChannel;
  final Set<String> favoriteIds;
  final double pixelsPerHour;
  final int totalHours;
  final void Function(Channel channel, EpgProgram? program)? onProgramFocused;
  final void Function(Channel channel)? onChannelSelected;
  final void Function(Channel channel)? onToggleFavorite;

  const EpgTimelineGrid({
    super.key,
    required this.channels,
    required this.epgData,
    this.selectedChannel,
    this.favoriteIds = const {},
    this.pixelsPerHour = 300.0,
    this.totalHours = 14,
    this.onProgramFocused,
    this.onChannelSelected,
    this.onToggleFavorite,
  });

  @override
  State<EpgTimelineGrid> createState() => EpgTimelineGridState();
}

class EpgTimelineGridState extends State<EpgTimelineGrid> {
  late final ScrollController _horizontalRulerController;
  late final ScrollController _horizontalProgramsController;
  late final ScrollController _verticalChannelsController;
  late final ScrollController _verticalProgramsController;

  late DateTime _windowStart;
  late DateTime _windowEnd;
  late double _pixelsPerMinute;
  late double _totalWidth;

  bool _isSyncingHorizontal = false;
  bool _isSyncingVertical = false;

  // Keyed by the Channel object (no `==`): cleared when the lists change.
  final Map<Channel, List<EpgProgram>> _programsCache = {};
  final Map<int, FocusNode> _channelFocusNodes = {};
  final Map<String, FocusNode> _programFocusNodes = {};

  static const double _channelColumnWidth = 200.0;
  static const double _rowHeight = 64.0;

  @override
  void initState() {
    super.initState();
    _horizontalRulerController = ScrollController();
    _horizontalProgramsController = ScrollController();
    _verticalChannelsController = ScrollController();
    _verticalProgramsController = ScrollController();

    _calculateTimelineWindow();

    _horizontalProgramsController.addListener(_onProgramsHorizontalScroll);
    _horizontalRulerController.addListener(_onRulerHorizontalScroll);
    _verticalProgramsController.addListener(_onProgramsVerticalScroll);
    _verticalChannelsController.addListener(_onChannelsVerticalScroll);

    // Initial horizontal scroll to current time
    WidgetsBinding.instance.addPostFrameCallback((_) {
      jumpToNow(animate: false);
    });
  }

  @override
  void didUpdateWidget(EpgTimelineGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pixelsPerHour != oldWidget.pixelsPerHour ||
        widget.totalHours != oldWidget.totalHours) {
      _calculateTimelineWindow();
    }
    if (widget.epgData != oldWidget.epgData ||
        widget.channels != oldWidget.channels) {
      _programsCache.clear();
    }
  }

  void _calculateTimelineWindow() {
    final now = DateTime.now();
    // Start timeline 2 hours before the current hour, rounded down
    _windowStart = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).subtract(const Duration(hours: 2));

    _windowEnd = _windowStart.add(Duration(hours: widget.totalHours));
    _pixelsPerMinute = widget.pixelsPerHour / 60.0;
    _totalWidth = widget.totalHours * widget.pixelsPerHour;
  }

  void _onProgramsHorizontalScroll() {
    if (_isSyncingHorizontal) return;
    _isSyncingHorizontal = true;
    if (_horizontalRulerController.hasClients) {
      _horizontalRulerController.jumpTo(_horizontalProgramsController.offset);
    }
    _isSyncingHorizontal = false;
  }

  void _onRulerHorizontalScroll() {
    if (_isSyncingHorizontal) return;
    _isSyncingHorizontal = true;
    if (_horizontalProgramsController.hasClients) {
      _horizontalProgramsController.jumpTo(_horizontalRulerController.offset);
    }
    _isSyncingHorizontal = false;
  }

  void _onProgramsVerticalScroll() {
    if (_isSyncingVertical) return;
    _isSyncingVertical = true;
    if (_verticalChannelsController.hasClients) {
      _verticalChannelsController.jumpTo(_verticalProgramsController.offset);
    }
    _isSyncingVertical = false;
  }

  void _onChannelsVerticalScroll() {
    if (_isSyncingVertical) return;
    _isSyncingVertical = true;
    if (_verticalProgramsController.hasClients) {
      _verticalProgramsController.jumpTo(_verticalChannelsController.offset);
    }
    _isSyncingVertical = false;
  }

  FocusNode _getChannelFocusNode(int index) {
    return _channelFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'GuideChannel_$index'),
    );
  }

  FocusNode _getProgramFocusNode(String key) {
    return _programFocusNodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'GuideProg_$key'),
    );
  }

  void _navigateFromChannelToRow(int index) {
    if (index < 0 || index >= widget.channels.length) return;
    final channel = widget.channels[index];
    final programs = _getProgramsForChannel(channel);

    if (programs.isEmpty) {
      final key = '${channel.uniqueId}_no_epg';
      _getProgramFocusNode(key).requestFocus();
      return;
    }

    final currentOffset = _horizontalProgramsController.hasClients
        ? _horizontalProgramsController.offset
        : 0.0;
    final currentTime = _windowStart.add(
      Duration(minutes: (currentOffset / _pixelsPerMinute).round()),
    );

    EpgProgram? targetProg;
    for (final p in programs) {
      if (p.endTime.isAfter(currentTime)) {
        targetProg = p;
        break;
      }
    }
    targetProg ??= programs.last;

    final key =
        '${channel.uniqueId}_${targetProg.name}_${targetProg.startTime.millisecondsSinceEpoch}';
    final node = _getProgramFocusNode(key);
    node.requestFocus();
  }

  /// Scrolls the timeline horizontally to position the "Now" indicator line.
  void jumpToNow({bool animate = true}) {
    if (!_horizontalProgramsController.hasClients) return;

    final now = DateTime.now();
    final minutesFromStart = now.difference(_windowStart).inMinutes;
    final nowOffset = minutesFromStart * _pixelsPerMinute;

    // Center "Now" about 200px from the left edge for optimal past/future balance
    final target = (nowOffset - 200.0).clamp(
      0.0,
      _horizontalProgramsController.position.maxScrollExtent,
    );

    if (animate) {
      _horizontalProgramsController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _horizontalProgramsController.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _horizontalProgramsController.removeListener(_onProgramsHorizontalScroll);
    _horizontalRulerController.removeListener(_onRulerHorizontalScroll);
    _verticalProgramsController.removeListener(_onProgramsVerticalScroll);
    _verticalChannelsController.removeListener(_onChannelsVerticalScroll);

    _horizontalRulerController.dispose();
    _horizontalProgramsController.dispose();
    _verticalChannelsController.dispose();
    _verticalProgramsController.dispose();

    for (final node in _channelFocusNodes.values) {
      node.dispose();
    }
    for (final node in _programFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  double? _calculateNowOffset() {
    final now = DateTime.now();
    if (now.isBefore(_windowStart) || now.isAfter(_windowEnd)) return null;
    return now.difference(_windowStart).inMinutes * _pixelsPerMinute;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nowOffset = _calculateNowOffset();

    if (widget.channels.isEmpty) {
      return Center(
        child: Text(
          l10n.liveTvNoChannels,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
        ),
      );
    }

    return Column(
      children: [
        // -------------------------------------------------------------
        // Header Row: Sticky Corner Label + Horizontal Time Ruler
        // -------------------------------------------------------------
        SizedBox(
          height: 42,
          child: Row(
            children: [
              _buildCornerHeader(l10n),
              Expanded(
                child: SingleChildScrollView(
                  controller: _horizontalRulerController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: EpgTimeRuler(
                    windowStart: _windowStart,
                    totalWidth: _totalWidth,
                    pixelsPerHour: widget.pixelsPerHour,
                    totalHours: widget.totalHours,
                    nowOffset: nowOffset,
                  ),
                ),
              ),
            ],
          ),
        ),

        // -------------------------------------------------------------
        // Body: Synchronized Virtualized Grid (Channels + Programs)
        // -------------------------------------------------------------
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sticky Left Channel Column
              EpgChannelColumn(
                controller: _verticalChannelsController,
                channels: widget.channels,
                selectedChannel: widget.selectedChannel,
                favoriteIds: widget.favoriteIds,
                columnWidth: _channelColumnWidth,
                rowHeight: _rowHeight,
                focusNodeBuilder: _getChannelFocusNode,
                onNavigateRight: _navigateFromChannelToRow,
                onChannelTap: widget.onChannelSelected,
                onChannelFocus: (ch) {
                  final progs = _getProgramsForChannel(ch);
                  final current = progs.isNotEmpty
                      ? progs.firstWhere(
                          (p) => p.isLive,
                          orElse: () => progs.first,
                        )
                      : null;
                  widget.onProgramFocused?.call(ch, current);
                },
                onToggleFavorite: widget.onToggleFavorite,
              ),

              // Horizontally & Vertically Virtualized Programs Grid
              Expanded(
                child: SingleChildScrollView(
                  controller: _horizontalProgramsController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: _totalWidth,
                    child: Stack(
                      children: [
                        // Vertically virtualized program rows
                        ListView.builder(
                          controller: _verticalProgramsController,
                          physics: const ClampingScrollPhysics(),
                          itemExtent: _rowHeight,
                          cacheExtent: _rowHeight * 6,
                          itemCount: widget.channels.length,
                          itemBuilder: (context, index) {
                            final channel = widget.channels[index];
                            return RepaintBoundary(
                              child: SizedBox(
                                height: _rowHeight,
                                width: _totalWidth,
                                child: _buildChannelProgramRow(
                                  index,
                                  channel,
                                  l10n,
                                ),
                              ),
                            );
                          },
                        ),

                        // Vertical "NOW" Indicator Line running through visible rows
                        if (nowOffset != null)
                          Positioned(
                            left: nowOffset,
                            top: 0,
                            bottom: 0,
                            width: 2,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.accent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accent.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 4,
                                      spreadRadius: 1,
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCornerHeader(AppLocalizations l10n) {
    return Container(
      width: _channelColumnWidth,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        border: Border(
          right: BorderSide(color: AppTheme.border, width: 1),
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.tv_rounded, size: 16, color: AppTheme.accent),
          const SizedBox(width: 8),
          Text(
            l10n.liveTvChannels.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the horizontal list of program blocks for a single channel.
  Widget _buildChannelProgramRow(
    int rowIndex,
    Channel channel,
    AppLocalizations l10n,
  ) {
    final programs = _getProgramsForChannel(channel);

    if (programs.isEmpty) {
      return _buildNoEpgPlaceholder(rowIndex, channel, l10n);
    }

    final slices = <Widget>[];
    DateTime cursor = _windowStart;
    double accumulatedOffset = 0.0;
    bool isFirstBlock = true;

    for (final prog in programs) {
      // Skip programs that ended before the window
      if (prog.endTime.isBefore(_windowStart)) continue;
      // Stop if program starts after the window
      if (prog.startTime.isAfter(_windowEnd)) break;

      // Fill gap before program if any
      if (prog.startTime.isAfter(cursor)) {
        final gapMinutes = prog.startTime.difference(cursor).inMinutes;
        if (gapMinutes > 0) {
          final gapWidth = gapMinutes * _pixelsPerMinute;
          slices.add(
            _buildGapBlock(
              rowIndex,
              channel,
              gapWidth,
              accumulatedOffset,
              isFirstBlock,
              cursor,
              prog.startTime,
              l10n,
            ),
          );
          accumulatedOffset += gapWidth;
          isFirstBlock = false;
        }
      }

      // Calculate visible program slice
      final sliceStart = prog.startTime.isBefore(_windowStart)
          ? _windowStart
          : prog.startTime;
      final sliceEnd = prog.endTime.isAfter(_windowEnd)
          ? _windowEnd
          : prog.endTime;
      final sliceMinutes = sliceEnd.difference(sliceStart).inMinutes;

      if (sliceMinutes > 0) {
        final sliceWidth = sliceMinutes * _pixelsPerMinute;
        final startOffset = accumulatedOffset;
        final isFirst = isFirstBlock;
        final key =
            '${channel.uniqueId}_${prog.name}_${prog.startTime.millisecondsSinceEpoch}';

        slices.add(
          EpgProgramBlock(
            focusNode: _getProgramFocusNode(key),
            program: prog,
            channel: channel,
            width: sliceWidth,
            isLive: prog.isLive,
            onTap: () => widget.onChannelSelected?.call(channel),
            onFocusChange: (focused) {
              if (focused) widget.onProgramFocused?.call(channel, prog);
            },
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                final currentOffset = _horizontalProgramsController.hasClients
                    ? _horizontalProgramsController.offset
                    : 0.0;
                if (startOffset <= currentOffset + 40.0 || isFirst) {
                  _getChannelFocusNode(rowIndex).requestFocus();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
          ),
        );
        accumulatedOffset += sliceWidth;
        isFirstBlock = false;
      }

      if (sliceEnd.isAfter(cursor)) {
        cursor = sliceEnd;
      }
    }

    // Fill trailing gap to the end of the window
    if (cursor.isBefore(_windowEnd)) {
      final trailingMinutes = _windowEnd.difference(cursor).inMinutes;
      if (trailingMinutes > 0) {
        final trailingWidth = trailingMinutes * _pixelsPerMinute;
        slices.add(
          _buildGapBlock(
            rowIndex,
            channel,
            trailingWidth,
            accumulatedOffset,
            isFirstBlock,
            cursor,
            _windowEnd,
            l10n,
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: slices,
      ),
    );
  }

  /// Same lookup as the banner and the channel list (REV-128).
  List<EpgProgram> _getProgramsForChannel(Channel channel) {
    return _programsCache.putIfAbsent(
      channel,
      () => EpgChannelMatcher.findPrograms(channel, widget.epgData),
    );
  }

  Widget _buildNoEpgPlaceholder(
    int rowIndex,
    Channel channel,
    AppLocalizations l10n,
  ) {
    final key = '${channel.uniqueId}_no_epg';
    return Container(
      width: _totalWidth,
      padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 3.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: DpadFocusable(
        focusNode: _getProgramFocusNode(key),
        onTap: () => widget.onChannelSelected?.call(channel),
        onFocusChange: (focused) {
          if (focused) widget.onProgramFocused?.call(channel, null);
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _getChannelFocusNode(rowIndex).requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        borderRadius: BorderRadius.circular(6),
        builder: (context, isFocused, isHovered, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: isFocused
                  ? AppTheme.accent.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isFocused
                    ? AppTheme.accent
                    : Colors.white.withValues(alpha: 0.04),
              ),
            ),
            child: Text(
              l10n.liveTvNoEpg,
              style: TextStyle(
                color: isFocused ? Colors.white : AppTheme.textMuted,
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
    int rowIndex,
    Channel channel,
    double width,
    double startOffset,
    bool isFirst,
    DateTime start,
    DateTime end,
    AppLocalizations l10n,
  ) {
    final key = '${channel.uniqueId}_gap_${start.millisecondsSinceEpoch}';
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 3.0),
        child: DpadFocusable(
          focusNode: _getProgramFocusNode(key),
          onTap: () => widget.onChannelSelected?.call(channel),
          onFocusChange: (focused) {
            if (focused) widget.onProgramFocused?.call(channel, null);
          },
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              final currentOffset = _horizontalProgramsController.hasClients
                  ? _horizontalProgramsController.offset
                  : 0.0;
              if (startOffset <= currentOffset + 40.0 || isFirst) {
                _getChannelFocusNode(rowIndex).requestFocus();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          borderRadius: BorderRadius.circular(6),
          builder: (context, isFocused, isHovered, _) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: isFocused
                    ? AppTheme.accent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isFocused
                      ? AppTheme.accent
                      : Colors.white.withValues(alpha: 0.03),
                ),
              ),
              child: width > 80
                  ? Text(
                      channel.name,
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
