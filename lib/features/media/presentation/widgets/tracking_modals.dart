import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';

class _ModalContentWithPicker extends StatefulWidget {
  final Widget Function(
      BuildContext context, DateTime? selectedDate, VoidCallback onPickDate)
      builder;

  const _ModalContentWithPicker({required this.builder});

  @override
  State<_ModalContentWithPicker> createState() =>
      _ModalContentWithPickerState();
}

class _ModalContentWithPickerState extends State<_ModalContentWithPicker> {
  DateTime? _selectedDate;
  bool _isPickingDate = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isPickingDate
            ? Column(
                key: const ValueKey('date_picker'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: AppTheme.textWhite,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _isPickingDate = false),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.detailsSelectDate,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: CupertinoTheme(
                      data: const CupertinoThemeData(
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle:
                              TextStyle(color: AppTheme.textWhite, fontSize: 20),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: _selectedDate ?? DateTime.now(),
                        maximumDate: DateTime.now(),
                        onDateTimeChanged: (date) {
                          _selectedDate = date;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => setState(() => _isPickingDate = false),
                    child: Text(
                      l10n.detailsConfirm,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              )
            : KeyedSubtree(
                key: const ValueKey('main_content'),
                child: widget.builder(context, _selectedDate,
                    () => setState(() => _isPickingDate = true)),
              ),
      ),
    );
  }
}

/// Modal for managing whole series tracking (Mark Remaining, Mark All, Remove All).
class SeriesTrackModal extends StatelessWidget {
  final String title;
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})
      status;
  final Function(DateTime? date) onMarkRemaining;
  final Function(DateTime? date) onMarkAll;
  final VoidCallback onRemoveAll;

  const SeriesTrackModal({
    super.key,
    required this.title,
    required this.status,
    required this.onMarkRemaining,
    required this.onMarkAll,
    required this.onRemoveAll,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})
        status,
    required Function(DateTime? date) onMarkRemaining,
    required Function(DateTime? date) onMarkAll,
    required VoidCallback onRemoveAll,
  }) {
    return AppBottomSheet.show(
      context: context,
      constraints: const BoxConstraints(maxWidth: 400),
      child: SeriesTrackModal(
        title: title,
        status: status,
        onMarkRemaining: onMarkRemaining,
        onMarkAll: onMarkAll,
        onRemoveAll: onRemoveAll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isNew = !status.isFullyWatched && !status.isPartiallyWatched;

    return AppBottomSheet(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: _ModalContentWithPicker(
        builder: (context, selectedDate, onPickDate) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.playlist_add_check,
                      color: AppTheme.accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: AppTheme.textWhite, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isNew
                    ? l10n.detailsMarkEntireSeriesPrompt
                    : l10n.detailsManageHistorySeriesPrompt,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _ModalButton(
                icon: !status.isFullyWatched
                    ? Icons.done_all
                    : Icons.replay_circle_filled,
                label: status.isPartiallyWatched && !status.isFullyWatched
                    ? l10n.detailsMarkRemaining
                    : (!status.isFullyWatched
                        ? l10n.detailsMarkAll
                        : l10n.detailsRewatchSeries),
                subtitle: selectedDate == null
                    ? l10n.watchHistoryDateToday
                    : l10n.detailsWatchedOnDate(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                color: AppTheme.accent,
                onTap: () {
                  Navigator.pop(context);
                  if (status.isPartiallyWatched && !status.isFullyWatched) {
                    onMarkRemaining(selectedDate);
                  } else {
                    onMarkAll(selectedDate);
                  }
                },
                onSecondaryTap: onPickDate,
              ),
              if (!isNew) ...[
                const SizedBox(height: 12),
                _ModalButton(
                  icon: Icons.delete_sweep_outlined,
                  label: l10n.detailsRemoveAll,
                  subtitle: l10n.detailsClearAllSeriesLogsSubtitle,
                  color: AppTheme.favorites,
                  onTap: () {
                    Navigator.pop(context);
                    onRemoveAll();
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Modal for managing a single episode's tracking options.
class TrackOptionsModal extends StatelessWidget {
  final int season;
  final int episode;
  final int watchCount;
  final Function(DateTime? date) onRewatch;
  final VoidCallback onRemoveOne;
  final VoidCallback onRemoveAll;
  final VoidCallback? onViewHistory;

  const TrackOptionsModal({
    super.key,
    required this.season,
    required this.episode,
    required this.watchCount,
    required this.onRewatch,
    required this.onRemoveOne,
    required this.onRemoveAll,
    this.onViewHistory,
  });

  static Future<void> show({
    required BuildContext context,
    required int season,
    required int episode,
    required int watchCount,
    required Function(DateTime? date) onRewatch,
    required VoidCallback onRemoveOne,
    required VoidCallback onRemoveAll,
    VoidCallback? onViewHistory,
  }) {
    return AppBottomSheet.show(
      context: context,
      constraints: const BoxConstraints(maxWidth: 400),
      child: TrackOptionsModal(
        season: season,
        episode: episode,
        watchCount: watchCount,
        onRewatch: onRewatch,
        onRemoveOne: onRemoveOne,
        onRemoveAll: onRemoveAll,
        onViewHistory: onViewHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppBottomSheet(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: _ModalContentWithPicker(
        builder: (context, selectedDate, onPickDate) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: AppTheme.accent, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    l10n.detailsEpisodeNumber(episode),
                    style: const TextStyle(color: AppTheme.textWhite, fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.detailsTrackEpisodeProgress,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _ModalButton(
                icon: Icons.replay,
                label: watchCount > 0
                    ? l10n.detailsMarkRewatch
                    : l10n.detailsMarkAsWatched,
                subtitle: selectedDate == null
                    ? l10n.watchHistoryDateToday
                    : l10n.detailsWatchedOnDate(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                color: AppTheme.accent,
                onTap: () {
                  Navigator.pop(context);
                  onRewatch(selectedDate);
                },
                onSecondaryTap: onPickDate,
              ),
              if (watchCount > 0 && onViewHistory != null) ...[
                const SizedBox(height: 12),
                _ModalButton(
                  icon: Icons.list_alt,
                  label: l10n.menuViewWatchHistory,
                  subtitle: l10n.detailsSeeAllDatesWatched,
                  color: AppTheme.badgeResolution,
                  onTap: () {
                    Navigator.pop(context);
                    onViewHistory!();
                  },
                ),
              ],
              if (watchCount > 0) ...[
                const SizedBox(height: 12),
                _ModalButton(
                  icon: Icons.remove_circle_outline,
                  label: l10n.detailsRemoveOneWatch,
                  subtitle: l10n.detailsDeleteLatestEntry,
                  color: AppTheme.badgeHdr,
                  onTap: () {
                    Navigator.pop(context);
                    onRemoveOne();
                  },
                ),
              ],
              if (watchCount > 1) ...[
                const SizedBox(height: 12),
                _ModalButton(
                  icon: Icons.delete_outline,
                  label: l10n.detailsRemoveAll,
                  subtitle: l10n.detailsClearAllEpisodeLogs,
                  color: AppTheme.favorites,
                  onTap: () {
                    Navigator.pop(context);
                    onRemoveAll();
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Modal for managing a movie's tracking options.
class MovieTrackModal extends StatelessWidget {
  final String title;
  final int watchCount;
  final Function(DateTime? date) onRewatch;
  final VoidCallback onRemoveOne;
  final VoidCallback onRemoveAll;
  final VoidCallback? onViewHistory;

  const MovieTrackModal({
    super.key,
    required this.title,
    required this.watchCount,
    required this.onRewatch,
    required this.onRemoveOne,
    required this.onRemoveAll,
    this.onViewHistory,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required int watchCount,
    required Function(DateTime? date) onRewatch,
    required VoidCallback onRemoveOne,
    required VoidCallback onRemoveAll,
    VoidCallback? onViewHistory,
  }) {
    return AppBottomSheet.show(
      context: context,
      constraints: const BoxConstraints(maxWidth: 400),
      child: MovieTrackModal(
        title: title,
        watchCount: watchCount,
        onRewatch: onRewatch,
        onRemoveOne: onRemoveOne,
        onRemoveAll: onRemoveAll,
        onViewHistory: onViewHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppBottomSheet(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: _ModalContentWithPicker(
        builder: (context, selectedDate, onPickDate) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: AppTheme.accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: AppTheme.textWhite, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.detailsTrackMovieProgress,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _ModalButton(
                icon: Icons.replay,
                label: watchCount > 0
                    ? l10n.detailsMarkRewatch
                    : l10n.detailsMarkAsWatched,
                subtitle: selectedDate == null
                    ? l10n.watchHistoryDateToday
                    : l10n.detailsWatchedOnDate(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                color: AppTheme.accent,
                onTap: () {
                  Navigator.pop(context);
                  onRewatch(selectedDate);
                },
                onSecondaryTap: onPickDate,
              ),
              if (watchCount > 0 && onViewHistory != null) ...[
                const SizedBox(height: 12),
                _ModalButton(
                  icon: Icons.list_alt,
                  label: l10n.menuViewWatchHistory,
                  subtitle: l10n.detailsSeeAllDatesWatched,
                  color: AppTheme.badgeResolution,
                  onTap: () {
                    Navigator.pop(context);
                    onViewHistory!();
                  },
                ),
              ],
              if (watchCount > 0) ...[
                const SizedBox(height: 12),
                _ModalButton(
                  icon: Icons.remove_circle_outline,
                  label: l10n.detailsRemoveOneWatch,
                  subtitle: l10n.detailsDeleteLatestEntry,
                  color: AppTheme.badgeHdr,
                  onTap: () {
                    Navigator.pop(context);
                    onRemoveOne();
                  },
                ),
              ],
              if (watchCount > 1) ...[
                const SizedBox(height: 12),
                _ModalButton(
                  icon: Icons.delete_outline,
                  label: l10n.detailsRemoveAll,
                  subtitle: l10n.detailsClearAllMovieLogs,
                  color: AppTheme.favorites,
                  onTap: () {
                    Navigator.pop(context);
                    onRemoveAll();
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ModalButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;

  const _ModalButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (onSecondaryTap != null)
              IconButton(
                icon: const Icon(Icons.calendar_today, size: 18),
                color: color,
                onPressed: onSecondaryTap,
                tooltip: l10n.detailsSelectDate,
              ),
          ],
        ),
      ),
    );
  }
}

class MarkPrecedingModal {
  static Future<bool?> show(
    BuildContext context, {
    required int missingCount,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return AppBottomSheet.show<bool>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 400),
      child: AppBottomSheet(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Builder(
          builder: (modalContext) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.playlist_add_check,
                    color: AppTheme.accent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.detailsMarkPreviousTitle,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.detailsMarkPreviousDesc(missingCount.toString()),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(modalContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.textWhite,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.detailsMarkAll,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(modalContext, false),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(l10n.detailsOnlyThisOne),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
