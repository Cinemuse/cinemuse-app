import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/profile/application/user_data_sync_service.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pull-to-refresh sync of the watch history and lists. A failure is logged
/// and shown in a snackbar; the caller then reloads its own providers.
Future<void> refreshUserData(BuildContext context, WidgetRef ref) async {
  // Read before the await: the widget may be gone when the sync ends.
  final service = ref.read(userDataSyncServiceProvider);
  final errorMapper = ref.read(errorMapperProvider);
  try {
    await service.syncNow();
  } catch (e, st) {
    AppLogger.warn(
      'refreshUserData',
      'Pull-to-refresh sync failed',
      error: e,
      stackTrace: st,
    );
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      message: errorMapper.map(e).message,
      isError: true,
    );
  }
}
