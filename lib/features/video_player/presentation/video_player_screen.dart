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
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
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
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  bool _settingsOpen = false;

  void _openSettings(CinemaPlayerState state, PlayerParams params) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    if (isPortrait) {
      setState(() => _settingsOpen = true);
    }

    PlayerSettingsBottomSheet.show(context, state, params).whenComplete(() {
      if (mounted) {
        setState(() => _settingsOpen = false);
      }
    });
  }

  void _navigateToNextEpisode(NextEpisodeInfo next) {
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          queryId: widget.queryId,
          type: widget.type,
          season: next.season,
          episode: next.episode,
          episodeTitle: next.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final params = PlayerParams(
      widget.queryId,
      widget.type,
      season: widget.season,
      episode: widget.episode,
      episodeTitle: widget.episodeTitle,
      startPosition: widget.startPosition,
    );
    final playerState = ref.watch(playerControllerProvider(params));
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

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
                    widget.loadingMessage ?? AppLocalizations.of(context)!.playerResolving,
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
          
          final settings = ref.watch(settingsProvider);
          final subtitleStyle = state.customSubtitleStyle ??
              SubtitleStyle(
                fontSize: settings.subtitleFontSize,
                color: SubtitleStyle.hexToColor(settings.subtitleColor),
                backgroundColor: SubtitleStyle.hexToColor(settings.subtitleBackgroundColor),
                verticalPosition: settings.subtitleVerticalPosition,
              );

          return AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: (_settingsOpen && isPortrait) ? Alignment.topCenter : Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: (_settingsOpen && isPortrait)
                  ? MediaQuery.of(context).size.height * 0.4
                  : MediaQuery.of(context).size.height,
              child: Builder(
                builder: (context) {
                  final videoHeight = (_settingsOpen && isPortrait)
                      ? MediaQuery.of(context).size.height * 0.4
                      : MediaQuery.of(context).size.height;

                  // Base padding of 24, plus scaled height minus offset
                  final calculatedPadding = 24.0 + (videoHeight - 80.0) * subtitleStyle.verticalPosition;
                  
                  final subtitleConfig = SubtitleViewConfiguration(
                    style: TextStyle(
                      fontSize: subtitleStyle.fontSize,
                      color: subtitleStyle.color,
                      backgroundColor: subtitleStyle.backgroundColor,
                      shadows: [
                        if (subtitleStyle.backgroundColor == Colors.transparent)
                          const Shadow(blurRadius: 2.0, color: Colors.black, offset: Offset(0, 2)),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(24, 24, 24, calculatedPadding),
                  );

                  return Video(
                    // Removed ValueKey to prevent player state from resetting!
                    controller: state.controller,
                    filterQuality: FilterQuality.low,
                    subtitleViewConfiguration: const SubtitleViewConfiguration(
                      visible: false, // Turn off internal subtitles
                    ),
                    controls: (videoState) => Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: SubtitleView(
                              key: ValueKey('${subtitleStyle.verticalPosition}_${subtitleStyle.fontSize}_${subtitleStyle.color}'),
                              controller: state.controller,
                              configuration: subtitleConfig,
                            ),
                          ),
                        ),
                        CustomVideoControls(
                          videoState: videoState,
                          playerState: state,
                          params: params,
                          onSettingsPressed: () => _openSettings(state, params),
                          onBackPressed: () => Navigator.of(context).pop(),
                          onNextEpisode: state.nextEpisode != null ? () {
                            _navigateToNextEpisode(state.nextEpisode!);
                          } : null,
                        ),
                      ],
                    ),
                  );
                },
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
                widget.errorMessage ?? AppLocalizations.of(context)!.playerErrorResolving(err.toString()),
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
                widget.loadingMessage ?? AppLocalizations.of(context)!.playerResolving,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
