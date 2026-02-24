import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/live_video_controls.dart';

/// The live video player section with custom controls overlay.
class LivePlayerSection extends StatelessWidget {
  final Channel? channel;
  final Player? player;
  final mkv.VideoController? videoController;
  final String? streamError;
  final ValueChanged<String>? onNumberInput;
  final VoidCallback? onConfirmNumber;
  final String numberBuffer;

  const LivePlayerSection({
    super.key,
    this.channel,
    this.player,
    this.videoController,
    this.streamError,
    this.onNumberInput,
    this.onConfirmNumber,
    this.numberBuffer = '',
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: streamError != null
            ? _buildErrorState(l10n)
            : videoController != null && player != null
                ? mkv.Video(
                    controller: videoController!,
                    controls: (videoState) => LiveVideoControls(
                      player: player!,
                      channel: channel,
                      videoState: videoState,
                      onNumberInput: onNumberInput,
                      onConfirmNumber: onConfirmNumber,
                      numberBuffer: numberBuffer,
                    ),
                  )
                : _buildPlaceholder(l10n),
      ),
    );
  }

  Widget _buildPlaceholder(AppLocalizations l10n) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Container(
        color: AppTheme.surface.withOpacity(0.5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.live_tv_rounded,
                color: AppTheme.textMuted.withOpacity(0.5),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.liveTvSelectChannel,
                style: TextStyle(
                  color: AppTheme.textMuted.withOpacity(0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return Container(
      color: AppTheme.surface.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.signal_wifi_off_rounded,
              color: Colors.red.withOpacity(0.7),
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              'Stream unavailable',
              style: TextStyle(
                color: AppTheme.textWhite,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This channel may be geo-restricted or temporarily offline.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
