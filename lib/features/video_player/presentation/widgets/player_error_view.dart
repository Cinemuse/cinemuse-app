import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/video_player/domain/youtube_watch_url.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown when the player can't start. For a YouTube video ([youtubeVideoId]
/// set) it offers to open the video on YouTube, because YouTube sometimes
/// blocks in-app playback (REV-236).
// TODO(REV-237): move onto the shared ErrorViewState once it is rebuilt.
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error,
              color: Theme.of(context).colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              text,
              style: const TextStyle(color: AppTheme.textWhite),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                const _GoBackButton(),
                if (videoId != null) ...[
                  OutlinedButton(
                    onPressed: onRetry,
                    style: _outlinedStyle,
                    child: Text(l10n.commonRetry),
                  ),
                  _OpenOnYoutubeButton(videoId: videoId),
                ] else
                  ElevatedButton(
                    autofocus: true,
                    onPressed: onRetry,
                    child: Text(l10n.commonRetry),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final _outlinedStyle = OutlinedButton.styleFrom(
  foregroundColor: AppTheme.textWhite,
  side: const BorderSide(color: AppTheme.borderSubtle),
  shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
);

class _GoBackButton extends StatelessWidget {
  const _GoBackButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      style: _outlinedStyle,
      child: Text(AppLocalizations.of(context)!.commonGoBack),
    );
  }
}

class _OpenOnYoutubeButton extends StatelessWidget {
  final String videoId;

  const _OpenOnYoutubeButton({required this.videoId});

  Future<void> _open(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      autofocus: true,
      onPressed: () => _open(context),
      icon: const Icon(Icons.open_in_new),
      label: Text(AppLocalizations.of(context)!.playerOpenOnYoutube),
    );
  }
}
