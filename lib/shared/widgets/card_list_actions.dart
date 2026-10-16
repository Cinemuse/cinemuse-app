import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';

/// The "Watchlist" and "Add to list" entries of a card's menu.
///
/// Shared cards only know this interface: the feature screens give them an
/// implementation wired to the user's lists, so `shared/` never imports a
/// feature (REV-40).
abstract interface class CardListActions {
  /// Read when the menu opens, so the entry matches the lists at that moment.
  bool get isWatchlisted;

  void toggleWatchlist();

  void addToList();
}

/// The menu entries for [actions]; none when it is null.
List<AppMenuOption> cardListMenuOptions(
  AppLocalizations l10n,
  CardListActions? actions,
) {
  if (actions == null) return const [];
  final isWatchlisted = actions.isWatchlisted;
  return [
    AppMenuOption(
      icon: isWatchlisted ? Icons.bookmark_remove : Icons.bookmark_add_outlined,
      label: isWatchlisted
          ? l10n.menuRemoveFromWatchlist
          : l10n.menuAddToWatchlist,
      onTap: actions.toggleWatchlist,
    ),
    AppMenuOption(
      icon: Icons.playlist_add,
      label: l10n.detailsAddToList,
      onTap: actions.addToList,
    ),
  ];
}
