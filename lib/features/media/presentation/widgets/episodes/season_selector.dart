import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/domain/episode_item.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The "Season N" dropdown above a show's episodes.
///
/// Stateful so the popup key and the focus node survive rebuilds: a new key
/// on every build threw the button away, and focus had nowhere to go back to
/// when the popup closed (REV-204).
class SeasonSelector extends ConsumerStatefulWidget {
  final List<SeasonSummary> seasons;
  final int selectedSeason;
  final String mediaId;

  const SeasonSelector({
    super.key,
    required this.seasons,
    required this.selectedSeason,
    required this.mediaId,
  });

  @override
  ConsumerState<SeasonSelector> createState() => _SeasonSelectorState();
}

class _SeasonSelectorState extends ConsumerState<SeasonSelector> {
  final _popupKey = GlobalKey<PopupMenuButtonState<int>>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: PopupMenuButton<int>(
        key: _popupKey,
        // The DpadFocusable below opens the menu; disabled, the button's own
        // InkWell is not a second focus stop around it.
        enabled: false,
        initialValue: widget.selectedSeason,
        onSelected: (val) => ref
            .read(selectedSeasonProvider(widget.mediaId).notifier)
            .selectSeason(val),
        child: DpadFocusable(
          onTap: () => _popupKey.currentState?.showButtonMenu(),
          borderRadius: AppTheme.radiusMd,
          builder: (context, isFocused, isHovered, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isFocused || isHovered
                    ? theme.focusColor
                    : theme.colorScheme.surfaceContainer.withValues(alpha: 0.5),
                borderRadius: AppTheme.radiusMd,
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: child,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  l10n.detailsSeasonNumber(widget.selectedSeason),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
        itemBuilder: (context) => widget.seasons
            .map(
              (s) => PopupMenuItem<int>(
                value: s.seasonNumber,
                child: Text(
                  l10n.detailsSeasonNumber(s.seasonNumber),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
