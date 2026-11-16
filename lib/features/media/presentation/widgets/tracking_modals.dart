import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/episodes/episode_menu.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

class _ModalContentWithPicker extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    DateTime? selectedDate,
    VoidCallback onPickDate,
  )
  builder;

  const _ModalContentWithPicker({required this.builder});

  @override
  State<_ModalContentWithPicker> createState() =>
      _ModalContentWithPickerState();
}

class _ModalContentWithPickerState extends State<_ModalContentWithPicker> {
  DateTime? _selectedDate;

  // The Material calendar works with arrow keys, the wheel didn't (REV-216).
  Future<void> _pickDate() async {
    final picked = await EpisodeMenu.selectWatchDate(
      context,
      initialDate: _selectedDate,
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _selectedDate, _pickDate);
}

/// Modal for managing whole series tracking (Mark Remaining, Mark All, Remove All).
class SeriesTrackModal extends StatelessWidget {
  final String title;
  final ({bool isFullyWatched, bool isPartiallyWatched, int minWatchCount})
  status;
  final ValueChanged<DateTime?> onMarkRemaining;
  final ValueChanged<DateTime?> onMarkAll;
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
    required ValueChanged<DateTime?> onMarkRemaining,
    required ValueChanged<DateTime?> onMarkAll,
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
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: _ModalContentWithPicker(
        builder: (context, selectedDate, onPickDate) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ModalHeader(
                icon: Icons.playlist_add_check,
                title: title,
                prompt: isNew
                    ? l10n.detailsMarkEntireSeriesPrompt
                    : l10n.detailsManageHistorySeriesPrompt,
              ),
              _ModalButton(
                icon: !status.isFullyWatched
                    ? Icons.done_all
                    : Icons.replay_circle_filled,
                label: status.isPartiallyWatched && !status.isFullyWatched
                    ? l10n.detailsMarkRemaining
                    : (!status.isFullyWatched
                          ? l10n.detailsMarkAll
                          : l10n.detailsRewatchSeries),
                subtitle: _watchDateLabel(l10n, selectedDate),
                color: AppTheme.accent,
                onTap: () {
                  Navigator.pop(context);
                  if (status.isPartiallyWatched && !status.isFullyWatched) {
                    onMarkRemaining(selectedDate);
                  } else {
                    onMarkAll(selectedDate);
                  }
                },
                onPickDate: onPickDate,
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

/// Modal for one watchable item, a movie or an episode: mark it watched (or
/// a rewatch) on a chosen date, see its history, remove one or all watches.
class WatchTrackModal extends StatelessWidget {
  final String title;
  final String prompt;
  final String removeAllSubtitle;
  final int watchCount;
  final ValueChanged<DateTime?> onRewatch;
  final VoidCallback onRemoveOne;
  final VoidCallback onRemoveAll;
  final VoidCallback? onViewHistory;

  const WatchTrackModal({
    super.key,
    required this.title,
    required this.prompt,
    required this.removeAllSubtitle,
    required this.watchCount,
    required this.onRewatch,
    required this.onRemoveOne,
    required this.onRemoveAll,
    this.onViewHistory,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String prompt,
    required String removeAllSubtitle,
    required int watchCount,
    required ValueChanged<DateTime?> onRewatch,
    required VoidCallback onRemoveOne,
    required VoidCallback onRemoveAll,
    VoidCallback? onViewHistory,
  }) {
    return AppBottomSheet.show(
      context: context,
      constraints: const BoxConstraints(maxWidth: 400),
      child: WatchTrackModal(
        title: title,
        prompt: prompt,
        removeAllSubtitle: removeAllSubtitle,
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
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: _ModalContentWithPicker(
        builder: (context, selectedDate, onPickDate) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ModalHeader(icon: Icons.history, title: title, prompt: prompt),
              _ModalButton(
                icon: Icons.replay,
                label: watchCount > 0
                    ? l10n.detailsMarkRewatch
                    : l10n.detailsMarkAsWatched,
                subtitle: _watchDateLabel(l10n, selectedDate),
                color: AppTheme.accent,
                onTap: () {
                  Navigator.pop(context);
                  onRewatch(selectedDate);
                },
                onPickDate: onPickDate,
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
                  subtitle: removeAllSubtitle,
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

/// "Today", or "Watched on d/m/y" once a date was picked.
String _watchDateLabel(AppLocalizations l10n, DateTime? date) => date == null
    ? l10n.watchHistoryDateToday
    : l10n.detailsWatchedOnDate('${date.day}/${date.month}/${date.year}');

class _ModalHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String prompt;

  const _ModalHeader({
    required this.icon,
    required this.title,
    required this.prompt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.accent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prompt,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// A sheet row. With [onPickDate], holding Enter or OK on it (or a long
/// press) opens the calendar; its calendar icon is for the mouse and touch
/// only, the arrows and Tab skip it.
class _ModalButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onPickDate;

  const _ModalButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DpadFocusable(
      onTap: onTap,
      onLongPress: onPickDate,
      borderRadius: AppTheme.radius12,
      builder: (context, isFocused, isHovered, child) {
        final background = color.withValues(alpha: 0.1);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isFocused || isHovered
                ? Color.alphaBlend(background, Theme.of(context).hoverColor)
                : background,
            borderRadius: AppTheme.radius12,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: child,
        );
      },
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
          if (onPickDate != null)
            ExcludeFocus(
              child: IconButton(
                icon: const Icon(Icons.calendar_today, size: 18),
                color: color,
                onPressed: onPickDate,
                tooltip: l10n.detailsSelectDate,
              ),
            ),
        ],
      ),
    );
  }
}

class MarkPrecedingModal {
  static Future<bool?> show(BuildContext context, {required int missingCount}) {
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
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(modalContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.textWhite,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppTheme.radius12,
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
                ).copyWith(overlayColor: AppTheme.hoverOverlay()),
                child: Text(l10n.detailsOnlyThisOne),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
