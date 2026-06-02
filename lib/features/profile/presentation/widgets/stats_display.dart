import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/domain/profile_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math';

class StatsDisplay extends ConsumerWidget {
  const StatsDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(profileStatsProvider);
    final stats = statsAsync.valueOrNull ?? ProfileStats.empty();

    // Helpers
    String formatDuration(int minutes) {
      final d = minutes ~/ 1440;
      final h = (minutes % 1440) ~/ 60;
      return '${d}d ${h}h';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Simple responsive switch
        final isDesktop = constraints.maxWidth > 900;

        if (!isDesktop) {
            return _MobileStatsDisplay(
              stats: stats,
              formatDuration: formatDuration,
            );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: TimeBreakdownCard(stats: stats, formatDuration: formatDuration)),
            const SizedBox(width: 24),
            Expanded(child: MoviesStatsCard(stats: stats)),
            const SizedBox(width: 24),
            Expanded(child: SeriesStatsCard(stats: stats)),
          ],
        );
      },
    );
  }
}

// --- Card 1: Time Breakdown ---
class TimeBreakdownCard extends StatelessWidget {
  final ProfileStats stats;
  final String Function(int) formatDuration;

  const TimeBreakdownCard({super.key, required this.stats, required this.formatDuration});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      icon: LucideIcons.clock,
      title: 'TIME BREAKDOWN',
      iconColor: Colors.blue,
      child: Column(
        children: [
          // Hero
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // All Time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatDuration(stats.totalMinutesWatched),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 32, // slightly smaller to fit
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('ALL TIME', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
                const SizedBox(width: 24),
                // Breakdown
                Container(
                  padding: const EdgeInsets.only(left: 24),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: Colors.white10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        _SubStatItem(value: formatDuration(stats.movieMinutes), label: 'MOVIES'),
                        const SizedBox(height: 8),
                        _SubStatItem(value: formatDuration(stats.seriesMinutes), label: 'SERIES'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 16),
          // Footer
          Row(
            children: [
               _FooterStat(
                   value: formatDuration(stats.last7Days.totalMinutes), 
                   label: 'LAST 7 DAYS',
               ),
               _FooterStat(
                   value: formatDuration(stats.last30Days.totalMinutes), 
                   label: 'LAST 30 DAYS',
                   showBorder: true,
               ),
               _FooterStat(
                   value: formatDuration(stats.last365Days.totalMinutes), 
                   label: 'LAST YEAR',
                   showBorder: true,
               ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Card 2: Movies Stats ---
class MoviesStatsCard extends StatelessWidget {
  final ProfileStats stats;

  const MoviesStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      icon: LucideIcons.film,
      title: 'MOVIES STATS',
      iconColor: AppTheme.accent,
      child: Column(
        children: [
            Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
                children: [
                    Text(
                      stats.totalMovies.toString(),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('MOVIES', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 16),
          // Footer
          Row(
            children: [
               _FooterStat(
                   value: stats.last7Days.movieCount.toString(), 
                   label: 'LAST 7 DAYS',
               ),
               _FooterStat(
                   value: stats.last30Days.movieCount.toString(), 
                   label: 'LAST 30 DAYS',
                   showBorder: true,
               ),
               _FooterStat(
                   value: stats.last365Days.movieCount.toString(), 
                   label: 'LAST YEAR',
                   showBorder: true,
               ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Card 3: Series Stats ---
class SeriesStatsCard extends StatelessWidget {
  final ProfileStats stats;

  const SeriesStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      icon: LucideIcons.tv,
      title: 'SERIES STATS',
      iconColor: Colors.green,
      child: Column(
        children: [
          // Hero
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Episodes Big
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      stats.totalEpisodes.toString(),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('EPISODES', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
                const SizedBox(width: 24),
                // Breakdown
                Container(
                  padding: const EdgeInsets.only(left: 24),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: Colors.white10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        _SubStatItem(value: stats.totalSeries.toString(), label: 'SERIES'),
                        const SizedBox(height: 8),
                        _SubStatItem(value: stats.totalSeasons.toString(), label: 'SEASONS'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 16),
          // Footer
          Row(
            children: [
               _FooterStat(
                   value: stats.last7Days.episodeCount.toString(), 
                   label: 'LAST 7 DAYS',
               ),
               _FooterStat(
                   value: stats.last30Days.episodeCount.toString(), 
                   label: 'LAST 30 DAYS',
                   showBorder: true,
               ),
               _FooterStat(
                   value: stats.last365Days.episodeCount.toString(), 
                   label: 'LAST YEAR',
                   showBorder: true,
               ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Shared Components ---

class BaseCard extends StatelessWidget {
    final IconData icon;
    final String title;
    final Color iconColor;
    final Widget child;

    const BaseCard({super.key, required this.icon, required this.title, required this.iconColor, required this.child});

    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                ]
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                        children: [
                            Icon(icon, color: iconColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                                title, 
                                style: const TextStyle(
                                    color: Colors.grey, 
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 12, 
                                    letterSpacing: 1.0
                                )
                            ),
                        ],
                    ),
                    const SizedBox(height: 8), // Spacer before content
                    child,
                ],
            ),
        );
    }
}

class _SubStatItem extends StatelessWidget {
    final String value;
    final String label;
    const _SubStatItem({required this.value, required this.label});

    @override
    Widget build(BuildContext context) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, height: 1.0)),
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
        );
    }
}

class _FooterStat extends StatelessWidget {
    final String value;
    final String label;
    final bool showBorder;

    const _FooterStat({required this.value, required this.label, this.showBorder = false});

    @override
    Widget build(BuildContext context) {
        return Expanded(
            child: Container(
                decoration: showBorder ? const BoxDecoration(
                    border: Border(left: BorderSide(color: Colors.white10)),
                ) : null,
                child: Column(
                    children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                              value, 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            label, 
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                        ),
                    ],
                ),
            ),
        );
    }
}

class _MobileStatsDisplay extends StatefulWidget {
  final ProfileStats stats;
  final String Function(int) formatDuration;
  
  const _MobileStatsDisplay({required this.stats, required this.formatDuration});

  @override
  State<_MobileStatsDisplay> createState() => _MobileStatsDisplayState();
}

class _MobileStatsDisplayState extends State<_MobileStatsDisplay> with SingleTickerProviderStateMixin {
  int? _expandedIndex;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void _toggleExpanded(int index) {
    if (_expandedIndex == index) {
      _controller.reverse().then((_) {
        if (mounted) {
          setState(() {
            _expandedIndex = null;
          });
        }
      });
    } else {
      if (_expandedIndex == null) {
        setState(() {
          _expandedIndex = index;
        });
        _controller.forward();
      } else {
        _controller.reverse().then((_) {
          if (mounted) {
            setState(() {
              _expandedIndex = index;
            });
            _controller.forward();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isBack = angle > pi / 2;

          Widget currentWidget;
          if (isBack && _expandedIndex != null) {
            switch (_expandedIndex) {
              case 0:
                currentWidget = GestureDetector(
                  onTap: () => _toggleExpanded(0),
                  child: TimeBreakdownCard(
                    stats: widget.stats, 
                    formatDuration: widget.formatDuration,
                  ),
                );
                break;
              case 1:
                currentWidget = GestureDetector(
                  onTap: () => _toggleExpanded(1),
                  child: MoviesStatsCard(
                    stats: widget.stats,
                  ),
                );
                break;
              case 2:
                currentWidget = GestureDetector(
                  onTap: () => _toggleExpanded(2),
                  child: SeriesStatsCard(
                    stats: widget.stats,
                  ),
                );
                break;
              default:
                currentWidget = const SizedBox.shrink();
            }
          } else {
            currentWidget = _buildCollapsedRow();
          }

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(isBack ? angle - pi : angle),
            alignment: Alignment.center,
            child: currentWidget,
          );
        },
      ),
    );
  }

  Widget _buildCollapsedRow() {
    return Row(
      children: [
        Expanded(child: _buildSmallCard(0, LucideIcons.clock, 'TIME', Colors.blue, widget.formatDuration(widget.stats.totalMinutesWatched))),
        const SizedBox(width: 12),
        Expanded(child: _buildSmallCard(1, LucideIcons.film, 'MOVIES', AppTheme.accent, widget.stats.totalMovies.toString())),
        const SizedBox(width: 12),
        Expanded(child: _buildSmallCard(2, LucideIcons.tv, 'SERIES', Colors.green, widget.stats.totalEpisodes.toString())),
      ],
    );
  }

  Widget _buildSmallCard(int index, IconData icon, String title, Color color, String value) {
    return GestureDetector(
      onTap: () => _toggleExpanded(index),
      child: Container(
        height: 110,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
          boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
