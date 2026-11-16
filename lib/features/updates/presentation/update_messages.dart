import 'dart:async';

import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/features/updates/presentation/update_error_message.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Looks for a new version each time the app opens and says so in a short
/// message at the bottom; the dot on the Settings button and Settings'
/// Info & updates page stay until the update. A download that fails shows
/// its error the same way. A failed check at app start stays quiet: only
/// the Info & updates page shows it.
class UpdateMessages extends ConsumerStatefulWidget {
  /// Off under the update-required screen, which shows the update itself.
  final bool showsMessages;
  final Widget child;

  const UpdateMessages({
    super.key,
    required this.showsMessages,
    required this.child,
  });

  @override
  ConsumerState<UpdateMessages> createState() => _UpdateMessagesState();
}

class _UpdateMessagesState extends ConsumerState<UpdateMessages> {
  /// The steps after "Update now": an error then comes from the download.
  static const _updating = {
    UpdateStatus.available,
    UpdateStatus.downloading,
    UpdateStatus.readyToInstall,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Nothing waits for it: the message shows when the check is done.
      unawaited(_checkForUpdates());
    });
  }

  Future<void> _checkForUpdates() async {
    await ref.read(updateProvider.notifier).checkForUpdates();
    if (!mounted || !widget.showsMessages || !ref.read(hasUpdateProvider)) {
      return;
    }
    final version = ref.read(updateProvider).latestVersionLabel!;
    AppSnackBar.show(
      context,
      message: AppLocalizations.of(context)!.updateAvailableMessage(version),
      duration: const Duration(seconds: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(updateProvider, (previous, next) {
      if (!widget.showsMessages ||
          next.status != UpdateStatus.error ||
          !_updating.contains(previous?.status)) {
        return;
      }
      AppSnackBar.show(
        context,
        message: updateErrorMessage(AppLocalizations.of(context)!, next),
        isError: true,
      );
    });
    return widget.child;
  }
}
