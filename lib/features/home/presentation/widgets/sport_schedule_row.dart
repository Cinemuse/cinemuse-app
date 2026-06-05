import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/home/application/sport_schedule_scraper.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/sport_event_card.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:intl/intl.dart';
import 'package:cinemuse_app/shared/widgets/skeleton_box.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';

// ---------------------------------------------------------------------------
// Sealed list item model
// ---------------------------------------------------------------------------

sealed class _ScheduleItem {
  const _ScheduleItem();
}

class _DayHeaderItem extends _ScheduleItem {
  final DateTime day;
  const _DayHeaderItem(this.day);
}

class _EventItem extends _ScheduleItem {
  final SportTvEvent event;
  const _EventItem(this.event);
}

// ---------------------------------------------------------------------------
// SportScheduleRow
// ---------------------------------------------------------------------------

class SportScheduleRow extends ConsumerStatefulWidget {
  const SportScheduleRow({super.key});

  @override
  ConsumerState<SportScheduleRow> createState() => _SportScheduleRowState();
}

class _SportScheduleRowState extends ConsumerState<SportScheduleRow> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolled = false;

  // Layout constants
  static const double _cardWidth = 280.0;
  static const double _cardSpacing = 16.0;
  static const double _dayHeaderWidth = 72.0;
  static const double _dayHeaderSpacing = 16.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Builds the flat list of [_DayHeaderItem] + [_EventItem] from the raw events.
  List<_ScheduleItem> _buildItems(List<SportTvEvent> events) {
    final items = <_ScheduleItem>[];
    DateTime? lastDay;

    for (final event in events) {
      final day = event.dateTime != null
          ? DateTime(
              event.dateTime!.year,
              event.dateTime!.month,
              event.dateTime!.day,
            )
          : null;

      if (day != null && (lastDay == null || !_isSameDay(day, lastDay))) {
        items.add(_DayHeaderItem(day));
        lastDay = day;
      }
      items.add(_EventItem(event));
    }

    return items;
  }

  /// Finds the flat-list index of the first event at or after [now].
  int _findNearestEventIndex(List<_ScheduleItem> items) {
    final now = DateTime.now();
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is _EventItem && item.event.dateTime != null) {
        if (!item.event.dateTime!.isBefore(now)) return i;
      }
    }
    // All events are in the past — scroll to the last one
    for (int i = items.length - 1; i >= 0; i--) {
      if (items[i] is _EventItem) return i;
    }
    return 0;
  }

  /// Calculates the pixel offset for a given flat-list index.
  double _offsetForIndex(
    int index,
    List<_ScheduleItem> items,
    double horizontalPadding,
  ) {
    double offset = 0.0;
    for (int i = 0; i < index; i++) {
      final item = items[i];
      if (item is _DayHeaderItem) {
        offset += _dayHeaderWidth + _dayHeaderSpacing;
      } else {
        offset += _cardWidth + _cardSpacing;
      }
    }
    // Snap to the day-header before this event for better context
    if (index > 0 && items[index - 1] is _DayHeaderItem) {
      offset -= _dayHeaderWidth + _dayHeaderSpacing;
    }
    return offset.clamp(0.0, double.infinity);
  }

  void _scrollToNearest(List<_ScheduleItem> items, double horizontalPadding) {
    if (_hasScrolled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final index = _findNearestEventIndex(items);
      final offset = _offsetForIndex(index, items, horizontalPadding);
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) return; // list not laid out yet
      _scrollController.jumpTo(offset.clamp(0.0, maxExtent));
      _hasScrolled = true;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(sportScheduleProvider);
    final l10n = AppLocalizations.of(context)!;
    final horizontalPadding = AppTheme.getResponsiveHorizontalPadding(context);

    if (scheduleAsync.hasError && !scheduleAsync.hasValue) {
      final mapped = ref.read(errorMapperProvider).map(scheduleAsync.error!);
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 16,
        ),
        child: ErrorCard(
          message: mapped.message,
          type: mapped.type,
          onRetry: () => ref.refresh(sportScheduleProvider),
        ),
      );
    }

    if (scheduleAsync.isLoading && !scheduleAsync.hasValue) {
      return const SportScheduleSkeleton();
    }

    final events = scheduleAsync.value ?? [];
    if (events.isEmpty) return const SizedBox.shrink();

    final items = _buildItems(events);

    // Trigger scroll once after first data is available
    _scrollToNearest(items, horizontalPadding);

    return GenericCarouselRow(
      theme: CarouselTheme.homeRow,
      title: l10n.homeSportSchedule,
      controller: _scrollController,
      height: 236,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _buildItem(context, items[index], index, items),
    );
  }

  Widget _buildItem(
    BuildContext context,
    _ScheduleItem item,
    int index,
    List<_ScheduleItem> items,
  ) {
    final isLast = index == items.length - 1;

    if (item is _DayHeaderItem) {
      return _DayHeader(
        day: item.day,
        isFirst: index == 0,
        trailingSpacing: _dayHeaderSpacing,
      );
    }

    final event = (item as _EventItem).event;
    return Padding(
      padding: EdgeInsets.only(right: isLast ? 0 : _cardSpacing),
      child: SportEventCard(event: event),
    );
  }
}

// ---------------------------------------------------------------------------
// Day Header Widget
// ---------------------------------------------------------------------------

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final bool isFirst;
  final double trailingSpacing;

  const _DayHeader({
    required this.day,
    required this.isFirst,
    required this.trailingSpacing,
  });

  String _label(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final normalised = DateTime(day.year, day.month, day.day);
    final l10n = AppLocalizations.of(context)!;

    if (normalised == today) return l10n.agendaToday;
    if (normalised == tomorrow) return l10n.agendaTomorrow;
    return DateFormat(
      'E d\nMMM',
      Localizations.localeOf(context).toString(),
    ).format(day);
  }

  @override
  Widget build(BuildContext context) {
    final label = _label(context);
    final isToday = _isToday();

    return Padding(
      padding: EdgeInsets.only(left: isFirst ? 0 : 8, right: trailingSpacing),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 2,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    isToday ? AppTheme.accent : Colors.white24,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isToday
                    ? AppTheme.accent.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday
                      ? AppTheme.accent.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: isToday ? AppTheme.accent : Colors.white70,
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 2,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isToday ? AppTheme.accent : Colors.white24,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday() {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }
}

// ---------------------------------------------------------------------------
// Skeleton & helpers (unchanged)
// ---------------------------------------------------------------------------

class SportScheduleSkeleton extends StatelessWidget {
  const SportScheduleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppTheme.getResponsiveHorizontalPadding(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            16,
          ),
          child: const SkeletonBox(width: 180, height: 25),
        ),
        GenericCarouselRow(
          theme: CarouselTheme.plain,
          height: 236,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 280, height: 280 * (9 / 16)),
              const SizedBox(height: 10),
              const SkeletonBox(width: 150, height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
