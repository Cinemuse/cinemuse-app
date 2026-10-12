import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/overlays/resolving_overlay.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/custom_video_controls.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/subtitle_slider_overlay.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_settings_bottom_sheet.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/cast_remote_view.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String queryId;
  final String type;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final int? startPosition;
  final String? loadingMessage;
  final String? errorMessage;
  final Channel? channel;

  const VideoPlayerScreen({
    super.key,
    required this.queryId,
    required this.type,
    this.season,
    this.episode,
    this.episodeTitle,
    this.startPosition,
    this.loadingMessage,
    this.errorMessage,
    this.channel,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  SliderOverlayType _activeOverlay = SliderOverlayType.none;
  bool _settingsOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'livetv') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (widget.channel != null) {
            ref.read(selectedChannelProvider.notifier).select(widget.channel);
          }
          ref.read(liveTvChannelOverlayProvider.notifier).state = false;
          ref.read(liveTvOverlayScrollOffsetProvider.notifier).state = null;
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _openSettings(
    CinemaPlayerState state,
    PlayerParams params, {
    SettingsView initialView = SettingsView.main,
  }) {
    if (_settingsOpen) return;
    setState(() => _settingsOpen = true);
    PlayerSettingsBottomSheet.show(
      context,
      state,
      params,
      (type) => setState(() => _activeOverlay = type),
      initialView: initialView,
    ).then((_) {
      if (mounted) setState(() => _settingsOpen = false);
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
    final effectiveTitle = widget.episodeTitle ?? widget.channel?.name;
    final params = PlayerParams(
      widget.queryId,
      widget.type,
      season: widget.season,
      episode: widget.episode,
      episodeTitle: effectiveTitle,
      startPosition: widget.startPosition,
    );
    final playerState = ref.watch(playerControllerProvider(params));
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    if (widget.type == 'livetv') {
      ref.listen<Channel?>(selectedChannelProvider, (previous, next) {
        if (next != null && next.uniqueId != previous?.uniqueId) {
          ref.read(recentChannelIdsProvider.notifier).push(next.uniqueId);
          ref
              .read(playerControllerProvider(params).notifier)
              .changeChannel(next);
        }
      });
    }

    ref.listen<AsyncValue<CinemaPlayerState>>(
      playerControllerProvider(params),
      (previous, next) {
        if (next is AsyncData<CinemaPlayerState>) {
          final err = next.value.error;
          final prevErr = previous?.valueOrNull?.error;
          if (err != null && err != prevErr) {
            AppSnackBar.show(
              context,
              message: err,
              backgroundColor: Theme.of(context).colorScheme.error,
              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            );
          }

          final notice = next.value.notification;
          final prevNotice = previous?.valueOrNull?.notification;
          if (notice != null && notice != prevNotice) {
            AppSnackBar.show(
              context,
              message: notice,
              backgroundColor: AppTheme.secondary,
              duration: const Duration(seconds: 3),
              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
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
            return ResolvingOverlay(
              state: state,
              loadingMessage: widget.loadingMessage,
              onSkipResolution: () {
                ref
                    .read(playerControllerProvider(params).notifier)
                    .skipResolution();
              },
            );
          }

          if (state.isCasting) {
            return CastRemoteView(
              playerState: state,
              params: params,
              onBackPressed: () => Navigator.of(context).pop(),
            );
          }

          final localSettings = ref.watch(localSettingsProvider);
          final subtitleStyle =
              state.customSubtitleStyle ?? localSettings.subtitleStyle;

          return AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: (_settingsOpen && isPortrait)
                ? Alignment.topCenter
                : Alignment.center,
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
                  final calculatedPadding =
                      24.0 +
                      (videoHeight - 80.0) * subtitleStyle.verticalPosition;

                  final subtitleConfig = SubtitleViewConfiguration(
                    style: TextStyle(
                      fontSize: subtitleStyle.fontSize,
                      color: subtitleStyle.color,
                      backgroundColor: subtitleStyle.backgroundColor,
                      shadows: [
                        if (subtitleStyle.backgroundColor.a == 0)
                          Shadow(
                            blurRadius: 2.0,
                            color: Theme.of(context).colorScheme.scrim,
                            offset: const Offset(0, 2),
                          ),
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
                              key: ValueKey(
                                '${subtitleStyle.verticalPosition}_${subtitleStyle.fontSize}_${subtitleStyle.color}',
                              ),
                              controller: state.controller,
                              configuration: subtitleConfig,
                            ),
                          ),
                        ),
                        CustomVideoControls(
                          videoState: videoState,
                          playerState: state,
                          params: params,
                          channel: widget.type == 'livetv'
                              ? (ref.watch(selectedChannelProvider) ??
                                    widget.channel)
                              : null,
                          isLive: widget.type == 'livetv',
                          isFullWindow: true,
                          onSettingsPressed: () => _openSettings(state, params),
                          onBackPressed: () => Navigator.of(context).pop(),
                          onOverlayRequested: (type) {
                            setState(() => _activeOverlay = type);
                          },
                          onNextEpisode: state.nextEpisode != null
                              ? () async {
                                  // Explicitly pause the player to prevent overlapping audio during transition
                                  await state.controller.player.pause();

                                  // Ensure the current episode is marked as completed if threshold is met
                                  // and cleanup any stale watching entries before navigating
                                  await ref
                                      .read(
                                        playerControllerProvider(
                                          params,
                                        ).notifier,
                                      )
                                      .historyManager
                                      .markCurrentEpisodeCompleted(
                                        position: state
                                            .controller
                                            .player
                                            .state
                                            .position
                                            .inSeconds,
                                        duration: state
                                            .controller
                                            .player
                                            .state
                                            .duration
                                            .inSeconds,
                                      );

                                  _navigateToNextEpisode(state.nextEpisode!);
                                }
                              : null,
                        ),
                        if (_activeOverlay != SliderOverlayType.none)
                          SubtitleSliderOverlay(
                            type: _activeOverlay,
                            params: params,
                            state: state,
                            onClose: (wasSaved) {
                              setState(
                                () => _activeOverlay = SliderOverlayType.none,
                              );
                              if (wasSaved) {
                                // Return to appearance settings menu
                                _openSettings(
                                  state,
                                  params,
                                  initialView: SettingsView.appearance,
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
        error: (err, stack) => PlayerErrorView(
          message: widget.errorMessage,
          youtubeVideoId: widget.type == 'youtube' ? widget.queryId : null,
          onRetry: () => ref.invalidate(playerControllerProvider(params)),
        ),
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                widget.loadingMessage ??
                    AppLocalizations.of(context)!.playerResolving,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
