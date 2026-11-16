import 'dart:async';

import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/profile/application/agenda_providers.dart';
import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/agenda_event_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';

import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AgendaWidget extends ConsumerStatefulWidget {
  final bool isExpanded;
  const AgendaWidget({super.key, this.isExpanded = false});

  @override
  ConsumerState<AgendaWidget> createState() => _AgendaWidgetState();
}

class _AgendaWidgetState extends ConsumerState<AgendaWidget> {
  final ScrollController _scrollController = ScrollController();
  final Map<AgendaGroup, GlobalKey> _groupKeys = {
    for (var group in AgendaGroup.values) group: GlobalKey(),
  };
  bool _hasInitialScrolled = false;

  /// The drag's last move went past the list's end, to the page.
  bool _isDragMovingPage = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// At the list's end, a wheel tick already goes on to the page: Flutter does
  /// that. A finger or a trackpad is a drag, and a drag stays on the list it
  /// started on, so its push past the end is handed to the page here.
  bool _handDragToPage(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final page = Scrollable.maybeOf(context)?.position;
    switch (notification) {
      // No drag details: a glide that reached the end, which just stops there.
      case OverscrollNotification(:final overscroll, dragDetails: _?):
        page?.pointerScroll(overscroll);
        _isDragMovingPage = true;
      case ScrollUpdateNotification():
        _isDragMovingPage = false;
      case ScrollEndNotification(:final dragDetails) when _isDragMovingPage:
        _isDragMovingPage = false;
        // Fingers lifted: the page glides on, as it does away from the agenda.
        if (page case final ScrollActivityDelegate delegate?) {
          delegate.goBallistic(-(dragDetails?.primaryVelocity ?? 0));
        }
      default:
        break;
    }
    return false;
  }

  void _scrollToPriorityGroup(Map<AgendaGroup, List<AgendaEvent>> groups) {
    if (_hasInitialScrolled || !mounted) return;

    // Ordered priority list of target groups (Recently Released is excluded to hide it initially)
    final priorityTargets = [
      AgendaGroup.today,
      AgendaGroup.tomorrow,
      AgendaGroup.thisWeek,
      AgendaGroup.nextWeek,
      AgendaGroup.later,
      AgendaGroup.tbd,
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      for (final target in priorityTargets) {
        if (groups.containsKey(target) && groups[target]!.isNotEmpty) {
          final group = _groupKeys[target]?.currentContext?.findRenderObject();
          if (group != null && _scrollController.hasClients) {
            // Only the agenda's own list: Scrollable.ensureVisible would
            // also scroll the Profile page down to the agenda (REV-317).
            unawaited(
              _scrollController.position.ensureVisible(
                group,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ),
            );
            _hasInitialScrolled = true;
            break;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final agendaAsync = ref.watch(agendaProvider);
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.value == ConnectivityResult.none;

    Widget buildContent() {
      void retry() => ref.invalidate(agendaProvider);
      if (isOffline) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorCard(
            error: UserFriendlyError(
              message: l10n.offlineScreenTitle,
              hint: l10n.offlineScreenMessage,
              kind: ErrorKind.network,
            ),
            onRetry: retry,
          ),
        );
      }

      return agendaAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  l10n.agendaNoEvents,
                  style: DesktopTypography.bodySecondary.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            );
          }

          // Trigger initial scroll calculation
          _scrollToPriorityGroup(groups);

          final slivers = <Widget>[];
          for (final entry in groups.entries) {
            final group = entry.key;
            final events = entry.value;

            slivers.add(
              SliverMainAxisGroup(
                key: _groupKeys[group],
                slivers: [
                  // Sticky Header for the group
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      title: _getGroupTitle(context, group).toUpperCase(),
                      backgroundColor: AppTheme.surface,
                    ),
                  ),

                  // List of events in the group
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final event = events[index];
                      return Column(
                        children: [
                          AgendaEventRow(event: event),
                          if (index < events.length - 1)
                            Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                        ],
                      );
                    }, childCount: events.length),
                  ),
                ],
              ),
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: _handDragToPage,
            // The page moves instead: Android's stretch would show on top.
            child: NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (notification) {
                notification.disallowIndicator();
                return true;
              },
              child: CustomScrollView(
                controller: _scrollController,
                slivers: slivers,
              ),
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(48),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
        ),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorCard(
            error: ref.read(errorMapperProvider).map(err),
            onRetry: retry,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.calendar,
                      size: 20,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.agendaTitle,
                      style: DesktopTypography.bentoHeader,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(l10n.agendaSubtitle, style: DesktopTypography.captionMeta),
              ],
            ),
          ),

          // Content
          if (widget.isExpanded)
            Expanded(child: buildContent())
          else
            SizedBox(
              height: 440, // Match typical card heights
              child: buildContent(),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

String _getGroupTitle(BuildContext context, AgendaGroup group) {
  final l10n = AppLocalizations.of(context)!;
  switch (group) {
    case AgendaGroup.recentlyReleased:
      return l10n.agendaRecentlyReleased;
    case AgendaGroup.today:
      return l10n.agendaToday;
    case AgendaGroup.tomorrow:
      return l10n.agendaTomorrow;
    case AgendaGroup.thisWeek:
      return l10n.agendaThisWeek;
    case AgendaGroup.nextWeek:
      return l10n.agendaNextWeek;
    case AgendaGroup.later:
      return l10n.agendaLater;
    case AgendaGroup.tbd:
      return l10n.agendaTbd;
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final Color backgroundColor;

  _StickyHeaderDelegate({required this.title, required this.backgroundColor});

  @override
  double get minExtent => 36.0;
  @override
  double get maxExtent => 36.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      width: double.infinity,
      height: 36.0,
      color:
          backgroundColor, // Background color is essential for sticky effect to hide background content
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          title,
          style: DesktopTypography.captionMeta.copyWith(
            color: AppTheme.accent,
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
