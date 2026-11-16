import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'selectable_option_tile.dart';

/// One audio or subtitle track; [onPick] turns it on.
class TrackTile extends StatelessWidget {
  final dynamic track;

  /// What a subtitle track holds: forced and CC ones say so in the label.
  final SubtitleKind kind;
  final bool isSelected;

  /// The player is fetching this subtitle: a spinning circle shows.
  final bool isLoading;
  final String? customTitle;
  final Color? color;
  final VoidCallback onPick;
  final bool autofocus;

  const TrackTile({
    super.key,
    required this.track,
    this.kind = SubtitleKind.full,
    required this.isSelected,
    this.isLoading = false,
    this.customTitle,
    this.color,
    required this.onPick,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final title =
        customTitle ??
        LanguageMapper.trackLabel(
          track,
          AppLocalizations.of(context)!,
          kind: kind,
        );

    return SelectableOptionTile(
      isSelected: isSelected,
      isLoading: isLoading,
      autofocus: autofocus,
      checkColor: color,
      onTap: () {
        if (!isSelected) onPick();
      },
      child: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? (color ?? AppTheme.textWhite)
              : AppTheme.textWhite.withValues(alpha: 0.7),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 15,
        ),
      ),
    );
  }
}
