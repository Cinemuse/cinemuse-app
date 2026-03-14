import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/live_video_controls.dart';

import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The live video player section with custom controls overlay.
class LivePlayerSection extends StatelessWidget {
  final Channel? channel;
  final AsyncValue<CinemaPlayerState>? playerState;
  final ValueChanged<String>? onNumberInput;
  final VoidCallback? onConfirmNumber;
  final String numberBuffer;

  const LivePlayerSection({
    super.key,
    this.channel,
    this.playerState,
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
        child: playerState == null
            ? _buildPlaceholder(l10n)
            : playerState!.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => _buildErrorState(l10n, e.toString()),
                data: (state) {
                  if (state.isResolving || state.currentStream == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.error != null) {
                     return _buildErrorState(l10n, state.error!);
                  }

                  return mkv.Video(
                    controller: state.controller,
                    filterQuality: FilterQuality.none,
                    controls: (videoState) => LiveVideoControls(
                      playerState: state,
                      channel: channel,
                      videoState: videoState,
                      onNumberInput: onNumberInput,
                      onConfirmNumber: onConfirmNumber,
                      numberBuffer: numberBuffer,
                    ),
                  );
                },
              ),
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

  Widget _buildErrorState(AppLocalizations l10n, String error) {
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
                error.contains('Failed to open') 
                  ? 'This channel may be geo-restricted or temporarily offline.'
                  : error,
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
