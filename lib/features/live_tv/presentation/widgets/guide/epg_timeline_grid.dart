import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_channel_matcher.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_time_ruler.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_channel_column.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_program_row.dart';

/// Timeline grid for the EPG TV Guide.
///
/// - Rows are virtualized vertically (synchronized [ListView.builder]s), but
///   each row builds its whole time window
/// - The window starts two hours before [now]'s hour and moves on every hour
/// - Repaint boundaries on channel tiles and program rows
/// - Programs per channel cached until the channels or the guide change
/// - Arrow-key navigation between channel tiles and program blocks: Up and
///   Down keep the time picked with Left and Right
class EpgTimelineGrid extends StatefulWidget {
  final List<Channel> channels;
  final Map<String, List<EpgProgram>> epgData;

  /// The time now, from the minute clock.
  final DateTime now;
  final Channel? selectedChannel;
  final Set<String> favoriteIds;
  final double pixelsPerHour;
  final int totalHours;
  final void Function(Channel channel, EpgProgram? program)? onProgramFocused;
  final void Function(Channel channel)? onChannelSelected;
  final void Function(Channel channel)? onToggleFavorite;

  /// Up from the first row.
  final VoidCallback? onUpFromTop;

  const EpgTimelineGrid({
    super.key,
    required this.channels,
    required this.epgData,
    required this.now,
    this.selectedChannel,
    this.favoriteIds = const {},
    this.pixelsPerHour = 300.0,
    this.totalHours = 14,
    this.onProgramFocused,
    this.onChannelSelected,
    this.onToggleFavorite,
    this.onUpFromTop,
  });

  @override
  State<EpgTimelineGrid> createState() => EpgTimelineGridState();
}

class EpgTimelineGridState extends State<EpgTimelineGrid> {
  final _horizontalRulerController = ScrollController();
  final _horizontalProgramsController = ScrollController();
  final _verticalChannelsController = ScrollController();
  final _verticalProgramsController = ScrollController();

  late DateTime _windowStart;
  late DateTime _windowEnd;
  late double _pixelsPerMinute;
  late double _totalWidth;

  bool _isSyncing = false;

  /// True while the grid scrolls itself, so it doesn't count as the user's.
  bool _isAutoScrolling = false;

  /// When the user last scrolled sideways: the hourly move goes back to the
  /// live line only if they haven't for a while.
  DateTime? _lastUserScrollAt;
  static const _followNowAfter = Duration(minutes: 5);

  // Keyed by the Channel object (no `==`): cleared when the lists change.
  final Map<Channel, List<EpgProgram>> _programsCache = {};
  final Map<int, FocusNode> _channelFocusNodes = {};

  /// The program rows on screen, by index.
  final Map<int, EpgProgramRowState> _rows = {};

  /// The time Up and Down keep: set by Left and Right, and by → from a
  /// channel.
  DateTime? _anchorTime;

  /// The block this grid just focused itself, which keeps [_anchorTime].
  ({int index, DateTime start})? _landing;

  /// The channel of the row the focus was on last: where Down from above
  /// lands while it is on screen. Kept by channel, not by row: the list
  /// changes under it (search, tabs, categories).
  String? _lastChannelId;

  static const double _channelColumnWidth = 200.0;
  static const double _rowHeight = 64.0;

  /// The space DpadFocusable keeps between a focused control and the list's
  /// edge, scrolling when there is less.
  static const double _focusMargin = 24.0;

  @override
  void initState() {
    super.initState();
    _calculateTimelineWindow();
    _linkScrolling(_horizontalProgramsController, _horizontalRulerController);
    _linkScrolling(_verticalProgramsController, _verticalChannelsController);
    _horizontalProgramsController.addListener(() {
      if (!_isAutoScrolling) _lastUserScrollAt = widget.now;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToNowInstantly());
  }

  @override
  void didUpdateWidget(EpgTimelineGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldStart = _windowStart;
    _calculateTimelineWindow();
    if (_windowStart != oldStart) {
      final shift =
          _windowStart.difference(oldStart).inMinutes * _pixelsPerMinute;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _followWindowMove(shift),
      );
    }
    if (widget.epgData != oldWidget.epgData ||
        widget.channels != oldWidget.channels) {
      _programsCache.clear();
    }
  }

  void _calculateTimelineWindow() {
    final now = widget.now;
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

  /// After the window moved [shift] pixels on: back to the live line if the
  /// user left the guide alone, else the same programs stay in view.
  void _followWindowMove(double shift) {
    if (!mounted || !_horizontalProgramsController.hasClients) return;
    final lastScroll = _lastUserScrollAt;
    if (lastScroll == null ||
        widget.now.difference(lastScroll) >= _followNowAfter) {
      _jumpToNowInstantly();
    } else {
      _jumpTo(_horizontalProgramsController.offset - shift);
    }
  }

  void _jumpTo(double offset) {
    final position = _horizontalProgramsController.position;
    _isAutoScrolling = true;
    position.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
    _isAutoScrolling = false;
  }

  /// Keeps [a] and [b] at the same offset, whichever one is scrolled.
  void _linkScrolling(ScrollController a, ScrollController b) {
    void follow(ScrollController from, ScrollController to) {
      if (_isSyncing || !to.hasClients) return;
      _isSyncing = true;
      to.jumpTo(from.offset);
      _isSyncing = false;
    }

    a.addListener(() => follow(a, b));
    b.addListener(() => follow(b, a));
  }

  FocusNode _getChannelFocusNode(int index) {
    return _channelFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'GuideChannel_$index'),
    );
  }

  double _horizontalOffset() => _horizontalProgramsController.hasClients
      ? _horizontalProgramsController.offset
      : 0.0;

  DateTime _timeAt(double offset) =>
      _windowStart.add(Duration(minutes: (offset / _pixelsPerMinute).round()));

  /// The time now while it is in view, else the time at the left edge.
  DateTime _timeInView() {
    final left = _horizontalOffset();
    final width = _horizontalProgramsController.hasClients
        ? _horizontalProgramsController.position.viewportDimension
        : 0.0;
    final now = widget.now;
    final isNowInView =
        !now.isBefore(_timeAt(left)) && now.isBefore(_timeAt(left + width));
    return isNowInView ? now : _timeAt(left);
  }

  void _navigateFromChannelToRow(int index) =>
      _focusInRow(index, _timeInView());

  void _focusInRow(int index, DateTime time) {
    final start = _rows[index]?.focusAt(time);
    if (start == null) return;
    _anchorTime = time;
    _landing = (index: index, start: start);
  }

  /// A block got the focus: one the user moved to with Left or Right sets
  /// the time Up and Down keep.
  void _onBlockFocused(int index, DateTime start) {
    _lastChannelId = widget.channels[index].uniqueId;
    final landing = _landing;
    _landing = null;
    if (landing?.index == index && landing?.start == start) return;
    final left = _timeAt(_horizontalOffset());
    _anchorTime = start.isBefore(left) ? left : start;
  }

  void _moveVertically(int index, int delta) {
    final target = index + delta;
    if (target < 0) {
      widget.onUpFromTop?.call();
    } else if (target < widget.channels.length) {
      _whenBuilt(
        target,
        () => _focusInRow(target, _anchorTime ?? _timeInView()),
      );
    }
  }

  /// Page up (-1) or Page down (+1) from row [index]: one screen of
  /// channels, the guide scrolling as far, so the focus keeps its place on
  /// screen and its column (the channel, or the program at the same time).
  /// Stops at the first and last channel.
  void _movePage(int index, int direction, {required bool onChannel}) {
    if (!_verticalProgramsController.hasClients) return;
    final position = _verticalProgramsController.position;
    final rows = (position.viewportDimension / _rowHeight).floor();
    final target = (index + direction * (rows < 1 ? 1 : rows)).clamp(
      0,
      widget.channels.length - 1,
    );
    if (target == index) return;
    position.jumpTo(
      (position.pixels + (target - index) * _rowHeight).clamp(
        0.0,
        position.maxScrollExtent,
      ),
    );
    // Focused once the rows are laid out where the jump put them.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted) return;
        _whenBuilt(
          target,
          onChannel
              ? () => _getChannelFocusNode(target).requestFocus()
              : () => _focusInRow(target, _anchorTime ?? _timeInView()),
        );
      })
      ..scheduleFrame();
  }

  void _focusChannel(int index) =>
      _whenBuilt(index, () => _getChannelFocusNode(index).requestFocus());

  /// Runs [action] once row [index] is built, scrolling to it first if it
  /// is far off: just to the edge it comes from, so a held arrow that runs
  /// ahead of the scrolling doesn't throw the row to the top.
  void _whenBuilt(int index, VoidCallback action) {
    if (_rows.containsKey(index) &&
        _getChannelFocusNode(index).context != null) {
      action();
      return;
    }
    if (!_verticalProgramsController.hasClients) return;
    final position = _verticalProgramsController.position;
    final top = index * _rowHeight;
    final offset = top < position.pixels
        ? top
        : top + _rowHeight - position.viewportDimension;
    position.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  /// Down from above: the channel of the row the focus was on last while it
  /// is on screen, else the top channel on screen, so the guide never jumps
  /// away from what is shown. The programs are entered only with → from a
  /// channel.
  void focusFromAbove() {
    final last = widget.channels.indexWhere(
      (c) => c.uniqueId == _lastChannelId,
    );
    final controller = _verticalChannelsController;
    if (!controller.hasClients) {
      _focusChannel(last < 0 ? 0 : last);
      return;
    }
    final position = controller.position;
    final top = position.pixels;
    final bottom = top + position.viewportDimension;
    final isLastOnScreen =
        last >= 0 &&
        last * _rowHeight < bottom &&
        (last + 1) * _rowHeight > top;
    // The first row clear of the top edge by the margin a focused control
    // keeps (DpadFocusable), so landing on it doesn't scroll at all.
    final firstOnScreen = top < 0.5
        ? 0
        : ((top + _focusMargin - 0.5) / _rowHeight).ceil().clamp(
            0,
            widget.channels.length - 1,
          );
    _focusChannel(isLastOnScreen ? last : firstOnScreen);
  }

  /// Where the "Now" line is about 200px from the left edge, for a balance
  /// of past and future.
  double _nowScrollOffset() =>
      widget.now.difference(_windowStart).inMinutes * _pixelsPerMinute - 200.0;

  void _jumpToNowInstantly() {
    if (_horizontalProgramsController.hasClients) _jumpTo(_nowScrollOffset());
  }

  /// "Jump to Live": also counts as leaving the guide alone, so the hourly
  /// move keeps following the live line.
  Future<void> jumpToNow() async {
    if (!_horizontalProgramsController.hasClients) return;
    _lastUserScrollAt = null;
    _isAutoScrolling = true;
    try {
      await _horizontalProgramsController.animateTo(
        _nowScrollOffset().clamp(
          0.0,
          _horizontalProgramsController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isAutoScrolling = false;
    }
  }

  @override
  void dispose() {
    _horizontalRulerController.dispose();
    _horizontalProgramsController.dispose();
    _verticalChannelsController.dispose();
    _verticalProgramsController.dispose();

    for (final node in _channelFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  double? _calculateNowOffset() {
    final now = widget.now;
    if (now.isBefore(_windowStart) || now.isAfter(_windowEnd)) return null;
    return now.difference(_windowStart).inMinutes * _pixelsPerMinute;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nowOffset = _calculateNowOffset();

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
                onNavigateUpFromTop: widget.onUpFromTop,
                onPage: (index, direction) =>
                    _movePage(index, direction, onChannel: true),
                onChannelTap: widget.onChannelSelected,
                onChannelFocus: (index, ch) {
                  _lastChannelId = ch.uniqueId;
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
                          itemBuilder: (context, index) => RepaintBoundary(
                            child: SizedBox(
                              height: _rowHeight,
                              width: _totalWidth,
                              child: _buildRow(index),
                            ),
                          ),
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

  Widget _buildRow(int index) {
    final channel = widget.channels[index];
    return EpgProgramRow(
      // A new channel at this index gets a new row, with its own nodes.
      key: ValueKey(channel.uniqueId),
      channel: channel,
      programs: _getProgramsForChannel(channel),
      windowStart: _windowStart,
      windowEnd: _windowEnd,
      pixelsPerMinute: _pixelsPerMinute,
      width: _totalWidth,
      scrollOffset: _horizontalOffset,
      onTap: () => widget.onChannelSelected?.call(channel),
      onFocused: (program, start) {
        _onBlockFocused(index, start);
        widget.onProgramFocused?.call(channel, program);
      },
      onLeftEdge: () => _getChannelFocusNode(index).requestFocus(),
      onVerticalMove: (delta) => _moveVertically(index, delta),
      onPageMove: (direction) => _movePage(index, direction, onChannel: false),
      onMounted: (row) => _rows[index] = row,
      onUnmounted: (row) {
        if (_rows[index] == row) _rows.remove(index);
      },
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

  /// Same lookup as the banner and the channel list (REV-128).
  List<EpgProgram> _getProgramsForChannel(Channel channel) {
    return _programsCache.putIfAbsent(
      channel,
      () => EpgChannelMatcher.findPrograms(channel, widget.epgData),
    );
  }
}
