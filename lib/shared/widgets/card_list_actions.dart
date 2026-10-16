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
