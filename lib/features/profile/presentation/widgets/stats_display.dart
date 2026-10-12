import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/domain/profile_stats.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math';

class StatsDisplay extends ConsumerWidget {
  const StatsDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // null until the first stats arrive: the cards show "–" (REV-269).
    final stats = ref.watch(profileStatsProvider).valueOrNull;
    // Only the narrow Profile layout uses this; the wide one places the
    // three cards itself (profile_overview.dart).
    return _MobileStatsDisplay(stats: stats);
  }
}

/// Shown until the first stats arrive, so "no data" is never a 0 (REV-269).
const _noValue = '–';

String _formatCount(ProfileStats? stats, int Function(ProfileStats) pick) =>
    stats == null ? _noValue : pick(stats).toString();

String _formatTime(
  AppLocalizations l10n,
  ProfileStats? stats,
  int Function(ProfileStats) pick,
) {
  if (stats == null) return _noValue;
  final minutes = pick(stats);
  return l10n.statsDaysHours(minutes ~/ 1440, (minutes % 1440) ~/ 60);
}

// --- Card 1: Time Breakdown ---
class TimeBreakdownCard extends StatelessWidget {
  final ProfileStats? stats;

  const TimeBreakdownCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _BaseCard(
      icon: LucideIcons.clock,
      title: l10n.statsTimeBreakdown.toUpperCase(),
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
                      _formatTime(l10n, stats, (s) => s.totalMinutesWatched),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 32, // slightly smaller to fit
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.statsAllTime.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
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
                      _SubStatItem(
                        value: _formatTime(l10n, stats, (s) => s.movieMinutes),
                        label: l10n.statsMovies.toUpperCase(),
                      ),
                      const SizedBox(height: 8),
                      _SubStatItem(
                        value: _formatTime(l10n, stats, (s) => s.seriesMinutes),
                        label: l10n.statsSeries.toUpperCase(),
                      ),
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
                value: _formatTime(
                  l10n,
                  stats,
                  (s) => s.last7Days.totalMinutes,
                ),
                label: l10n.statsLast7Days.toUpperCase(),
              ),
              _FooterStat(
                value: _formatTime(
                  l10n,
                  stats,
                  (s) => s.last30Days.totalMinutes,
                ),
                label: l10n.statsLast30Days.toUpperCase(),
                showBorder: true,
              ),
              _FooterStat(
                value: _formatTime(
                  l10n,
                  stats,
                  (s) => s.last365Days.totalMinutes,
                ),
                label: l10n.statsLastYear.toUpperCase(),
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
  final ProfileStats? stats;

  const MoviesStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _BaseCard(
      icon: LucideIcons.film,
      title: l10n.statsMoviesStats.toUpperCase(),
      iconColor: AppTheme.accent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text(
                  _formatCount(stats, (s) => s.totalMovies),
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.statsMovies.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
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
                value: _formatCount(stats, (s) => s.last7Days.movieCount),
                label: l10n.statsLast7Days.toUpperCase(),
              ),
              _FooterStat(
                value: _formatCount(stats, (s) => s.last30Days.movieCount),
                label: l10n.statsLast30Days.toUpperCase(),
                showBorder: true,
              ),
              _FooterStat(
                value: _formatCount(stats, (s) => s.last365Days.movieCount),
                label: l10n.statsLastYear.toUpperCase(),
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
  final ProfileStats? stats;

  const SeriesStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _BaseCard(
      icon: LucideIcons.tv,
      title: l10n.statsSeriesStats.toUpperCase(),
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
                      _formatCount(stats, (s) => s.totalEpisodes),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.statsEpisodes.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
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
                      _SubStatItem(
                        value: _formatCount(stats, (s) => s.totalSeries),
                        label: l10n.statsSeries.toUpperCase(),
                      ),
                      const SizedBox(height: 8),
                      _SubStatItem(
                        value: _formatCount(stats, (s) => s.totalSeasons),
                        label: l10n.statsSeasons.toUpperCase(),
                      ),
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
                value: _formatCount(stats, (s) => s.last7Days.episodeCount),
                label: l10n.statsLast7Days.toUpperCase(),
              ),
              _FooterStat(
                value: _formatCount(stats, (s) => s.last30Days.episodeCount),
                label: l10n.statsLast30Days.toUpperCase(),
                showBorder: true,
              ),
              _FooterStat(
                value: _formatCount(stats, (s) => s.last365Days.episodeCount),
                label: l10n.statsLastYear.toUpperCase(),
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

class _BaseCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Widget child;

  const _BaseCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  letterSpacing: 1.0,
                ),
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
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            height: 1.0,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _FooterStat extends StatelessWidget {
  final String value;
  final String label;
  final bool showBorder;

  const _FooterStat({
    required this.value,
    required this.label,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: showBorder
            ? const BoxDecoration(
                border: Border(left: BorderSide(color: Colors.white10)),
              )
            : null,
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileStatsDisplay extends StatefulWidget {
  final ProfileStats? stats;

  const _MobileStatsDisplay({required this.stats});

  @override
  State<_MobileStatsDisplay> createState() => _MobileStatsDisplayState();
}

class _MobileStatsDisplayState extends State<_MobileStatsDisplay>
    with SingleTickerProviderStateMixin {
  int? _expandedIndex;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
    final l10n = AppLocalizations.of(context)!;

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
            final index = _expandedIndex!;
            // The small card that had focus is gone after the flip.
            currentWidget = DpadFocusable(
              onTap: () => _toggleExpanded(index),
              autofocus: true,
              showFocusRing: true,
              borderRadius: BorderRadius.circular(16),
              child: switch (index) {
                0 => TimeBreakdownCard(stats: widget.stats),
                1 => MoviesStatsCard(stats: widget.stats),
                _ => SeriesStatsCard(stats: widget.stats),
              },
            );
          } else {
            currentWidget = _buildCollapsedRow(l10n);
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

  Widget _buildCollapsedRow(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: _buildSmallCard(
            0,
            LucideIcons.clock,
            l10n.statsTime.toUpperCase(),
            Colors.blue,
            _formatTime(l10n, widget.stats, (s) => s.totalMinutesWatched),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallCard(
            1,
            LucideIcons.film,
            l10n.statsMovies.toUpperCase(),
            AppTheme.accent,
            _formatCount(widget.stats, (s) => s.totalMovies),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallCard(
            2,
            LucideIcons.tv,
            l10n.statsSeries.toUpperCase(),
            Colors.green,
            _formatCount(widget.stats, (s) => s.totalSeries),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallCard(
    int index,
    IconData icon,
    String title,
    Color color,
    String value,
  ) {
    return DpadFocusable(
      onTap: () => _toggleExpanded(index),
      showFocusRing: true,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 110,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
