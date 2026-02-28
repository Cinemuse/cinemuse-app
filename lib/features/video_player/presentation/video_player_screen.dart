import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/custom_video_controls.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_settings_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class VideoPlayerScreen extends ConsumerWidget {
  final String queryId;
  final String type;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final int startPosition;

  const VideoPlayerScreen({
    super.key,
    required this.queryId,
    required this.type,
    this.season,
    this.episode,
    this.episodeTitle,
    this.startPosition = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Construct params
    final params = PlayerParams(
      queryId, 
      type, 
      season: season, 
      episode: episode, 
      episodeTitle: episodeTitle,
      startPosition: startPosition,
    );
    final playerState = ref.watch(playerControllerProvider(params));

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: playerState.when(
        data: (state) => Center(
          child: Video(
            controller: state.controller,
            filterQuality: FilterQuality.none,
            controls: (videoState) => CustomVideoControls(
              videoState: videoState,
              playerState: state,
              params: params,
              onSettingsPressed: () => PlayerSettingsBottomSheet.show(context, state, params),
              onNextEpisode: state.nextEpisode != null ? () {
                final next = state.nextEpisode!;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(
                      queryId: queryId,
                      type: type,
                      season: next.season,
                      episode: next.episode,
                      episodeTitle: next.title,
                    ),
                  ),
                );
              } : null,
            ),
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.playerErrorResolving(err.toString()),
                style: const TextStyle(color: AppTheme.textWhite),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(playerControllerProvider(params)),
                child: Text(AppLocalizations.of(context)!.commonRetry),
              )
            ],
          ),
        ),
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.playerResolving,
                style: const TextStyle(color: AppTheme.textMuted),
              )
            ],
          ),
        ),
      ),
    );
  }
}
