import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/services/streaming/models/provider_search_status.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/custom_video_controls.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_settings_bottom_sheet.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/cast_remote_view.dart';
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
  final String? loadingMessage;
  final String? errorMessage;

  const VideoPlayerScreen({
    super.key,
    required this.queryId,
    required this.type,
    this.season,
    this.episode,
    this.episodeTitle,
    this.startPosition = 0,
    this.loadingMessage,
    this.errorMessage,
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

    ref.listen<AsyncValue<CinemaPlayerState>>(
      playerControllerProvider(params),
      (previous, next) {
        if (next is AsyncData<CinemaPlayerState>) {
          final err = next.value.error;
          final prevErr = previous?.valueOrNull?.error;
          if (err != null && err != prevErr) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(err),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
              ),
            );
          }
        }
      },
    );

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: playerState.when(
        data: (state) {
          if (state.isResolving) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    loadingMessage ?? AppLocalizations.of(context)!.playerResolving,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 16),
                  ),
                  if (state.providerStatuses.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 300,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: state.providerStatuses.map((s) {
                          final isSearching = s.status == ProviderStatus.searching;
                          final isFailed = s.status == ProviderStatus.failed;
                          
                          Color iconColor = Colors.white54;
                          IconData iconData = Icons.search;
                          String trailingText = '${(s.timeElapsed.inMilliseconds / 1000).toStringAsFixed(1)}s';
                          
                          if (!isSearching) {
                            if (isFailed) {
                              iconData = Icons.error_outline;
                              iconColor = Colors.redAccent;
                              trailingText = 'Failed ($trailingText)';
                            } else {
                              iconData = Icons.check_circle_outline;
                              iconColor = Colors.greenAccent;
                              trailingText = '${s.resultsCount} results ($trailingText)';
                            }
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                if (isSearching)
                                  const SizedBox(
                                    width: 16, 
                                    height: 16, 
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)
                                  )
                                else
                                  Icon(iconData, size: 16, color: iconColor),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    s.providerName,
                                    style: TextStyle(
                                      color: isSearching ? Colors.white : Colors.white70,
                                      fontWeight: isSearching ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Text(
                                  trailingText,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          if (state.isCasting) {
            return CastRemoteView(
              playerState: state,
              params: params,
              onBackPressed: () => Navigator.of(context).pop(),
            );
          }
          
          return Center(
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
          );
        },
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                errorMessage ?? AppLocalizations.of(context)!.playerErrorResolving(err.toString()),
                style: const TextStyle(color: AppTheme.textWhite),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textWhite,
                      side: const BorderSide(color: Colors.white54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    ),
                    child: Text(AppLocalizations.of(context)!.commonGoBack),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(playerControllerProvider(params)),
                    child: Text(AppLocalizations.of(context)!.commonRetry),
                  ),
                ],
              ),
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
                loadingMessage ?? AppLocalizations.of(context)!.playerResolving,
                style: const TextStyle(color: AppTheme.textMuted),
              )
            ],
          ),
        ),
      ),
    );
  }
}
