import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';

class _ModalContentWithPicker extends StatefulWidget {
  final Widget Function(
      BuildContext context, DateTime? selectedDate, VoidCallback onPickDate)
      builder;

  const _ModalContentWithPicker({super.key, required this.builder});

  @override
  State<_ModalContentWithPicker> createState() =>
      _ModalContentWithPickerState();
}

class _ModalContentWithPickerState extends State<_ModalContentWithPicker> {
  DateTime? _selectedDate;
  bool _isPickingDate = false;

  @override
  Widget build(BuildContext context) {
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
                        color: Colors.white,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _isPickingDate = false),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Date',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
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
                              TextStyle(color: Colors.white, fontSize: 20),
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
                    child: const Text('Confirm',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
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
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isNew
                    ? 'Mark the entire series as watched?'
                    : 'Manage your history for this series.',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _ModalButton(
                icon: !status.isFullyWatched
                    ? Icons.done_all
                    : Icons.replay_circle_filled,
                label: status.isPartiallyWatched && !status.isFullyWatched
                    ? AppLocalizations.of(context)!.detailsMarkRemaining
                    : (!status.isFullyWatched
                        ? AppLocalizations.of(context)!.detailsMarkAll
                        : AppLocalizations.of(context)!.detailsRewatchSeries),
                subtitle: selectedDate == null
                    ? 'Today'
                    : 'Watched on ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
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
                  label: AppLocalizations.of(context)!.detailsRemoveAll,
                  subtitle: 'Clear all logs for all seasons',
                  color: Colors.redAccent,
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

  const TrackOptionsModal({
    super.key,
    required this.season,
    required this.episode,
    required this.watchCount,
    required this.onRewatch,
    required this.onRemoveOne,
    required this.onRemoveAll,
  });

  static Future<void> show({
    required BuildContext context,
    required int season,
    required int episode,
    required int watchCount,
    required Function(DateTime? date) onRewatch,
    required VoidCallback onRemoveOne,
    required VoidCallback onRemoveAll,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    'Episode $episode',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Track your progress for this episode.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _ModalButton(
                icon: Icons.replay,
                label: watchCount > 0 ? 'Mark a Rewatch' : 'Mark as Watched',
                subtitle: selectedDate == null
                    ? 'Today'
                    : 'Watched on ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                color: AppTheme.accent,
                onTap: () {
                  Navigator.pop(context);
                  onRewatch(selectedDate);
                },
                onSecondaryTap: onPickDate,
              ),
              if (watchCount > 0) ...[
                const SizedBox(height: 12),
                _ModalButton(
                  icon: Icons.remove_circle_outline,
                  label: 'Remove One Watch',
                  subtitle: 'Delete the latest entry',
                  color: Colors.orangeAccent,
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
                  label: AppLocalizations.of(context)!.detailsRemoveAll,
                  subtitle: 'Clear all logs for this episode',
                  color: Colors.redAccent,
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

  const MovieTrackModal({
    super.key,
    required this.title,
    required this.watchCount,
    required this.onRewatch,
    required this.onRemoveOne,
    required this.onRemoveAll,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required int watchCount,
    required Function(DateTime? date) onRewatch,
    required VoidCallback onRemoveOne,
    required VoidCallback onRemoveAll,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage your history for this movie.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _ModalButton(
                icon: Icons.replay,
                label: watchCount > 0 ? 'Mark a Rewatch' : 'Mark as Watched',
                subtitle: selectedDate == null
                    ? 'Today'
                    : 'Watched on ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                color: AppTheme.accent,
                onTap: () {
                  Navigator.pop(context);
                  onRewatch(selectedDate);
                },
                onSecondaryTap: onPickDate,
              ),
              if (watchCount > 0) ...[
                const SizedBox(height: 12),
                _ModalButton(
                  icon: Icons.remove_circle_outline,
                  label: 'Remove One Watch',
                  subtitle: 'Delete the latest entry',
                  color: Colors.orangeAccent,
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
                  label: AppLocalizations.of(context)!.detailsRemoveAll,
                  subtitle: 'Clear all logs for this movie',
                  color: Colors.redAccent,
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
                      color: Colors.white,
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
                tooltip: 'Pick Date',
              ),
          ],
        ),
      ),
    );
  }
}
