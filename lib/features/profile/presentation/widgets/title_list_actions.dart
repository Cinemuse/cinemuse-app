import 'dart:async';

import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/add_to_list_sheet.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_action_feedback.dart';
import 'package:cinemuse_app/shared/widgets/card_list_actions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A card's "Watchlist" and "Add to list" entries for one title, wired to
/// the user's lists.
class TitleListActions implements CardListActions {
  final BuildContext _context;
  final WidgetRef _ref;
  final MediaItem media;

  TitleListActions(this._context, this._ref, this.media);

  @override
  bool get isWatchlisted => _ref.read(
    isInSystemListProvider((
      tmdbId: media.tmdbId,
      mediaType: media.mediaType,
      type: ListType.watchlist,
    )),
  );

  @override
  void toggleWatchlist() {
    // Not awaited: a menu tap has nothing to wait for, and a failure
    // already shows as an error snackbar.
    unawaited(
      runListAction(_context, _ref, (lists) => lists.toggleWatchlist(media)),
    );
  }

  @override
  void addToList() {
    // Not awaited: the sheet saves and reports its own changes.
    unawaited(AddToListSheet.show(_context, media));
  }
}
