import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/video_player/domain/youtube_watch_url.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/error_action.dart';
import 'package:cinemuse_app/shared/widgets/error_view_state.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown when the player can't start: the shared [ErrorViewState] with Go
/// back and Retry. For a YouTube video ([youtubeVideoId] set) the main button
/// opens the video on YouTube, because YouTube sometimes blocks in-app
/// playback (REV-236).
class PlayerErrorView extends StatelessWidget {
  final String? message;
  final String? youtubeVideoId;
  final VoidCallback onRetry;

  const PlayerErrorView({
    super.key,
    this.message,
    this.youtubeVideoId,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final videoId = youtubeVideoId;
    final text = videoId != null
        ? l10n.playerYoutubeBlocked
        : message ?? l10n.playerAllSourcesExhausted;

    return ErrorViewState(
      error: UserFriendlyError(message: text, kind: ErrorKind.streaming),
      onRetry: onRetry,
      extraActions: [
        ErrorAction(
          label: l10n.commonGoBack,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      mainAction: videoId == null
          ? null
          : ErrorAction(
              label: l10n.playerOpenOnYoutube,
              icon: Icons.open_in_new,
              onPressed: () => _openOnYoutube(context, videoId),
            ),
    );
  }
}

Future<void> _openOnYoutube(BuildContext context, String videoId) async {
  final failedText = AppLocalizations.of(context)!.playerOpenOnYoutubeFailed;
  bool opened;
  try {
    opened = await launchUrl(
      youtubeWatchUrl(videoId),
      mode: LaunchMode.externalApplication,
    );
  } on Exception catch (e) {
    // No browser / YouTube app can take the link: the snackbar below
    // tells the user, nothing else depends on it.
    AppLogger.warn('PlayerErrorView', 'Could not open YouTube', error: e);
    opened = false;
  }
  if (!opened && context.mounted) {
    AppSnackBar.show(context, message: failedText, isError: true);
  }
}
