import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

/// Modal for managing whole series tracking (Mark Remaining, Mark All, Remove All).
class SeriesTrackModal extends StatefulWidget {
  final String title;
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount}) status;
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

  @override
  State<SeriesTrackModal> createState() => _SeriesTrackModalState();
}

class _SeriesTrackModalState extends State<SeriesTrackModal> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final isNew = !widget.status.isFullyWatched && !widget.status.isPartiallyWatched;
    
    return AlertDialog(
      backgroundColor: AppTheme.secondary,
      surfaceTintColor: Colors.transparent,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.playlist_add_check, color: AppTheme.accent, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18), overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isNew 
                ? 'Mark the entire series as watched?' 
                : 'Manage your history for this series.',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          _ModalButton(
            icon: !widget.status.isFullyWatched ? Icons.done_all : Icons.replay_circle_filled,
            label: widget.status.isPartiallyWatched && !widget.status.isFullyWatched
                ? AppLocalizations.of(context)!.detailsMarkRemaining
                : (!widget.status.isFullyWatched ? AppLocalizations.of(context)!.detailsMarkAll : AppLocalizations.of(context)!.detailsRewatchSeries),
            subtitle: _selectedDate == null ? 'Today' : 'Watched on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
            color: AppTheme.accent,
            onTap: () {
              Navigator.pop(context);
              if (widget.status.isPartiallyWatched && !widget.status.isFullyWatched) {
                widget.onMarkRemaining(_selectedDate);
              } else {
                widget.onMarkAll(_selectedDate);
              }
            },
            onSecondaryTap: () async {
              final date = await _selectDate(context);
              if (date != null) setState(() => _selectedDate = date);
            },
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
                widget.onRemoveAll();
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Modal for managing a single episode's tracking options.
class TrackOptionsModal extends StatefulWidget {
  final int season;
  final int episode;
  final Function(DateTime? date) onRewatch;
  final VoidCallback onRemoveOne;
  final VoidCallback onRemoveAll;

  const TrackOptionsModal({
    super.key,
    required this.season,
    required this.episode,
    required this.onRewatch,
    required this.onRemoveOne,
    required this.onRemoveAll,
  });

  @override
  State<TrackOptionsModal> createState() => _TrackOptionsModalState();
}

class _TrackOptionsModalState extends State<TrackOptionsModal> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.secondary,
      surfaceTintColor: Colors.transparent,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.history, color: AppTheme.accent, size: 24),
          const SizedBox(width: 12),
          Text('Episode ${widget.episode}', style: const TextStyle(color: Colors.white, fontSize: 20)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Track your progress for this episode.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          _ModalButton(
            icon: Icons.replay,
            label: 'Mark a Rewatch',
            subtitle: _selectedDate == null ? 'Today' : 'Watched on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
            color: AppTheme.accent,
            onTap: () {
              Navigator.pop(context);
              widget.onRewatch(_selectedDate);
            },
            onSecondaryTap: () async {
              final date = await _selectDate(context);
              if (date != null) setState(() => _selectedDate = date);
            },
          ),
          
          const SizedBox(height: 12),
          
          _ModalButton(
            icon: Icons.remove_circle_outline,
            label: 'Remove One Watch',
            subtitle: 'Delete the latest entry',
            color: Colors.orangeAccent,
            onTap: () {
              Navigator.pop(context);
              widget.onRemoveOne();
            },
          ),
          
          const SizedBox(height: 12),
          
          _ModalButton(
            icon: Icons.delete_outline,
            label: 'Remove All History',
            subtitle: 'Clear all logs for this episode',
            color: Colors.redAccent,
            onTap: () {
              Navigator.pop(context);
              widget.onRemoveAll();
            },
          ),
        ],
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: color.withOpacity(0.7), fontSize: 11),
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

Future<DateTime?> _selectDate(BuildContext context) async {
  return await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime.now(),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accent,
            onPrimary: Colors.white,
            surface: AppTheme.secondary,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      );
    },
  );
}

/// Modal for managing a movie's tracking options.
class MovieTrackModal extends StatefulWidget {
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

  @override
  State<MovieTrackModal> createState() => _MovieTrackModalState();
}

class _MovieTrackModalState extends State<MovieTrackModal> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.secondary,
      surfaceTintColor: Colors.transparent,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.history, color: AppTheme.accent, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18), overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Manage your history for this movie.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          _ModalButton(
            icon: Icons.replay,
            label: widget.watchCount > 0 ? 'Mark a Rewatch' : 'Mark as Watched',
            subtitle: _selectedDate == null ? 'Today' : 'Watched on ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
            color: AppTheme.accent,
            onTap: () {
              Navigator.pop(context);
              widget.onRewatch(_selectedDate);
            },
            onSecondaryTap: () async {
              final date = await _selectDate(context);
              if (date != null) setState(() => _selectedDate = date);
            },
          ),
          
          if (widget.watchCount > 0) ...[
            const SizedBox(height: 12),
            
            _ModalButton(
              icon: Icons.remove_circle_outline,
              label: 'Remove One Watch',
              subtitle: 'Delete the latest entry',
              color: Colors.orangeAccent,
              onTap: () {
                Navigator.pop(context);
                widget.onRemoveOne();
              },
            ),
            
            const SizedBox(height: 12),
            
            _ModalButton(
              icon: Icons.delete_outline,
              label: 'Remove All History',
              subtitle: 'Clear all logs for this movie',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(context);
                widget.onRemoveAll();
              },
            ),
          ],
        ],
      ),
    );
  }
}
