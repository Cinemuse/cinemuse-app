import 'package:cinemuse_app/features/profile/application/pinned_list_ids_provider.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_pin_action.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Opens a list card's menu (right-click or long-press, REV-255): open,
/// pin / unpin on Home and, when [onDelete] is set, delete. [context] is the
/// card's: the menu opens next to it, or at [position] (a right-click).
void showListCardMenu(
  BuildContext context,
  WidgetRef ref, {
  required UserList list,
  required VoidCallback onOpen,
  VoidCallback? onDelete,
  Offset? position,
}) {
  final l10n = AppLocalizations.of(context)!;
  final isPinned = ref.read(pinnedListIdsProvider).contains(list.id);
  AppMenu.show(
    context: context,
    title: switch (list.type) {
      ListType.watchlist => l10n.listWatchLater,
      ListType.favorites => l10n.listFavorites,
      _ => list.name,
    },
    anchorContext: context,
    position: position,
    options: [
      AppMenuOption(
        icon: LucideIcons.list,
        label: l10n.menuOpenList,
        onTap: onOpen,
      ),
      AppMenuOption(
        icon: isPinned ? LucideIcons.pinOff : LucideIcons.pin,
        label: isPinned ? l10n.listUnpinFromHome : l10n.listPinToHome,
        onTap: () => togglePinWithFeedback(context, ref, list.id),
      ),
      if (onDelete != null)
        AppMenuOption(
          icon: LucideIcons.trash2,
          label: l10n.detailsDeleteList,
          onTap: onDelete,
          isDestructive: true,
        ),
    ],
  );
}
