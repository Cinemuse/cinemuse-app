import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';

class EpisodeMenu {
  const EpisodeMenu._();

  static Future<DateTime?> selectWatchDate(BuildContext context) {
    return showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accent,
              onPrimary: AppTheme.textWhite,
              surface: AppTheme.secondary,
              onSurface: AppTheme.textWhite,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  static List<AppMenuOption> buildEpisodeMenuOptions({
    required BuildContext context,
    required AppLocalizations l10n,
    required String mediaId,
    required int seasonNumber,
    required int episodeNumber,
    required String episodeName,
    required bool isWatched,
    required double? resumePercentage,
    required bool hasCachedStream,
    required VoidCallback onClearCache,
    void Function(int season, int episode, String name, {bool restart})? onEpisodeTap,
    Function(int season, int episode, DateTime? date)? onMarkWatched,
    Function(int season, int episode)? onTrackOptions,
    VoidCallback? onViewHistory,
    List<({int season, int episode})> Function(int season, int episode)? onFindMissingPreceding,
    Function(int season, int episode, List<({int season, int episode})> missing)? onShowMarkPrecedingModal,
    VoidCallback? onShowComments,
  }) {
    final hasProgress = (resumePercentage ?? 0) > 0 && !isWatched;

    return [
      AppMenuOption(
        icon: Icons.play_arrow_outlined,
        label: hasProgress ? l10n.menuResume : l10n.detailsPlay,
        onTap: () => onEpisodeTap?.call(seasonNumber, episodeNumber, episodeName, restart: false),
      ),
      if (hasProgress)
        AppMenuOption(
          icon: Icons.replay,
          label: l10n.menuRestart,
          onTap: () => onEpisodeTap?.call(seasonNumber, episodeNumber, episodeName, restart: true),
        ),
      if (hasCachedStream)
        AppMenuOption(
          icon: Icons.cached,
          label: l10n.menuRemoveCachedProvider,
          onTap: onClearCache,
        ),
      if (isWatched) ...[
        if (onTrackOptions != null)
          AppMenuOption(
            icon: Icons.edit,
            label: l10n.menuManageWatchHistory,
            onTap: () => onTrackOptions(seasonNumber, episodeNumber),
          ),
        if (onViewHistory != null)
          AppMenuOption(
            icon: Icons.history,
            label: l10n.menuViewWatchHistory,
            onTap: onViewHistory,
          ),
      ] else ...[
        AppMenuOption(
          icon: Icons.remove_red_eye_outlined,
          label: l10n.menuMarkWatchedNow,
          onTap: () {
            final missing = onFindMissingPreceding?.call(seasonNumber, episodeNumber) ?? [];
            if (missing.isNotEmpty && onShowMarkPrecedingModal != null) {
              onShowMarkPrecedingModal(seasonNumber, episodeNumber, missing);
            } else {
              onMarkWatched?.call(seasonNumber, episodeNumber, null);
            }
          },
        ),
        AppMenuOption(
          icon: Icons.edit_calendar,
          label: l10n.menuMarkWatchedCustomDate,
          onTap: () async {
            final date = await selectWatchDate(context);
            if (date != null) {
              onMarkWatched?.call(seasonNumber, episodeNumber, date);
            }
          },
        ),
      ],
      if (onShowComments != null)
        AppMenuOption(
          icon: Icons.forum_outlined,
          label: l10n.detailsTvTimeComments,
          onTap: onShowComments,
        ),
    ];
  }
}
