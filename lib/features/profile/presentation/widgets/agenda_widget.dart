import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/agenda_providers.dart';
import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
          final key = _groupKeys[target];
          if (key?.currentContext != null) {
            Scrollable.ensureVisible(
              key!.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: 0.0,
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
    final isOffline = connectivity.valueOrNull == ConnectivityResult.none;

    Widget buildContent() {
      if (isOffline) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.offlineScreenTitle,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.offlineScreenMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
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
                  style: DesktopTypography.bodySecondary.copyWith(color: AppTheme.textMuted),
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
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final event = events[index];
                        return Column(
                          children: [
                            _AgendaEventItem(event: event),
                            if (index < events.length - 1)
                              Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                          ],
                        );
                      },
                      childCount: events.length,
                    ),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            controller: _scrollController,
            slivers: slivers,
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        ),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              l10n.commonError,
              style: const TextStyle(color: Colors.redAccent),
            ),
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
                    const Icon(LucideIcons.calendar, size: 20, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      l10n.agendaTitle,
                      style: DesktopTypography.bentoHeader,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.agendaSubtitle,
                  style: DesktopTypography.captionMeta,
                ),
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
      case AgendaGroup.recentlyReleased: return l10n.agendaRecentlyReleased;
      case AgendaGroup.today: return l10n.agendaToday;
      case AgendaGroup.tomorrow: return l10n.agendaTomorrow;
      case AgendaGroup.thisWeek: return l10n.agendaThisWeek;
      case AgendaGroup.nextWeek: return l10n.agendaNextWeek;
      case AgendaGroup.later: return l10n.agendaLater;
      case AgendaGroup.tbd: return l10n.agendaTbd;
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      width: double.infinity,
      height: 36.0,
      color: backgroundColor, // Background color is essential for sticky effect to hide background content
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
    return title != oldDelegate.title || backgroundColor != oldDelegate.backgroundColor;
  }
}

class _AgendaEventItem extends StatelessWidget {
  final AgendaEvent event;

  const _AgendaEventItem({required this.event});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: () {
        // TODO: Navigate to details
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // Poster Small
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 48,
                height: 72,
                color: Colors.white10,
                child: event.posterPath != null
                    ? Image.network(
                        'https://image.tmdb.org/t/p/w200${event.posterPath}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(LucideIcons.film, size: 20, color: Colors.white24),
                      )
                    : const Icon(LucideIcons.film, size: 20, color: Colors.white24),
              ),
            ),
            const SizedBox(width: 16),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: DesktopTypography.bodySecondary.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.type == MediaKind.tv && event.seasonNumber != null)
                    Builder(
                      builder: (context) {
                        final sLabel = l10n.detailsSeasonNumber(event.seasonNumber!).split(' ').first[0]; // 'S'
                        final eLabel = l10n.detailsEpisodeNumber(event.episodeNumber!).split(' ').first; // 'EP' or 'E'
                        
                        // Check if episodeName is redundant
                        final epName = event.episodeName ?? "";
                        final isRedundant = epName.toLowerCase().contains('episode ${event.episodeNumber}') || 
                                           epName.toLowerCase() == 'episode ${event.episodeNumber}' ||
                                           epName.trim() == event.episodeNumber.toString();
                        
                        return Text(
                          '$sLabel${event.seasonNumber} $eLabel${event.episodeNumber}${!isRedundant && epName.isNotEmpty ? ' • $epName' : ''}',
                          style: DesktopTypography.captionMeta.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: event.type == MediaKind.tv 
                              ? Colors.blue.withValues(alpha: 0.3) 
                              : AppTheme.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          (event.type == MediaKind.tv ? l10n.agendaSeries : l10n.agendaMovie).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: event.type == MediaKind.tv ? Colors.blue[300] : AppTheme.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        event.isTbd 
                          ? (event.customReleaseDate ?? l10n.agendaTbdLabel)
                          : DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(event.releaseDate),
                        style: DesktopTypography.captionMeta.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
