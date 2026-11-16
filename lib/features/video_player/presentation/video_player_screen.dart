import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/services/system/phone_orientation.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/helpers/player_channel_input_coordinator.dart';
import 'package:cinemuse_app/features/video_player/presentation/helpers/player_snack_messages.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/overlays/resolving_overlay.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/custom_video_controls.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_settings_panel.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/cast_remote_view.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/number_input_osd.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/features/media/domain/series_domain_service.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String queryId;
  final String type;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final int? startPosition;
  final String? loadingMessage;
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
    this.channel,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  bool _settingsOpen = false;

  /// The tracks panel opens again on the last tab used.
  PlayerSettingsTab _tracksTab = PlayerSettingsTab.audio;

  final _channelInput = PlayerChannelInputCoordinator();

  @override
  void initState() {
    super.initState();
    // Not awaited: the screen can't wait in initState, and a turn needs
    // nothing after it.
    unawaited(PhoneOrientation.playerOpened());
    if (widget.type == 'livetv') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (widget.channel != null) {
            ref.read(selectedChannelProvider.notifier).select(widget.channel);
          }
          ref.read(liveTvChannelOverlayProvider.notifier).set(false);
          ref.read(liveTvOverlayScrollOffsetProvider.notifier).set(null);
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(PhoneOrientation.playerClosed());
    super.dispose();
  }

  /// Live TV's channel keys on the loading screen, as in the controls: a
  /// channel that is slow to open never stops the zapping.
  KeyEventResult _handleLoadingChannelKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final numberEntry = ref.read(channelNumberEntryProvider.notifier);
    final digit = channelDigitFor(key);
    if (digit != null) {
      numberEntry.type(
        digit,
        onFound: ref.read(selectedChannelProvider.notifier).select,
      );
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        ref.read(channelNumberEntryProvider).isNotEmpty) {
      numberEntry.confirm();
      return KeyEventResult.handled;
    }
    final current = ref.read(selectedChannelProvider) ?? widget.channel;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.pageUp) {
      _channelInput.zapPreviousChannel(ref: ref, currentChannel: current);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelDown ||
        key == LogicalKeyboardKey.pageDown) {
      _channelInput.zapNextChannel(ref: ref, currentChannel: current);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _openSettings(
    CinemaPlayerState state,
    PlayerParams params,
    PlayerSettingsKind kind,
  ) async {
    if (_settingsOpen) return;
    setState(() => _settingsOpen = true);
    await PlayerSettingsPanel.show(
      context,
      state,
      params,
      kind: kind,
      initialTab: _tracksTab,
      onTabChanged: (tab) => _tracksTab = tab,
    );
    if (mounted) setState(() => _settingsOpen = false);
  }

  Future<void> _playNextEpisode(
    CinemaPlayerState state,
    PlayerParams params,
  ) async {
    final player = state.controller.player;
    // No overlapping audio during the switch.
    await player.pause();
    // Ticks the episode when past the threshold, before leaving.
    final notSaved = await ref
        .read(playerControllerProvider(params).notifier)
        .historyManager
        ?.markCurrentEpisodeCompleted(
          position: player.state.position.inSeconds,
          duration: player.state.duration.inSeconds,
        );
    // Closed during the save (REV-165).
    if (!mounted) return;
    // The app's messenger keeps it on screen in the next player (REV-310).
    if (notSaved != null) {
      AppSnackBar.show(context, message: notSaved, isError: true);
    }
    _navigateToNextEpisode(state.nextEpisode!);
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
          PlayerMessageState? messagesOf(CinemaPlayerState? s) =>
              s == null ? null : (error: s.error, notice: s.notification);
          showPlayerSnackMessages(
            context,
            previous: messagesOf(previous?.value),
            next: messagesOf(next.value)!,
          );
        }
      },
    );

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: playerState.when(
        data: (state) {
          if (state.isResolving) {
            final isLive = widget.type == 'livetv';
            return _LeavableLoadingView(
              onKeyEvent: isLive ? _handleLoadingChannelKey : null,
              overlay: isLive
                  ? NumberInputOsd(
                      buffer: ref.watch(channelNumberEntryProvider),
                    )
                  : null,
              child: ResolvingOverlay(
                state: state,
                loadingMessage: widget.loadingMessage,
                onSkipResolution: () {
                  ref
                      .read(playerControllerProvider(params).notifier)
                      .skipResolution();
                },
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

          final subtitleStyle = ref.watch(
            localSettingsProvider.select((s) => s.subtitleStyle),
          );

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
                    onExitFullscreen: PhoneOrientation.exitFullscreen,
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
                          onSettingsPressed: (kind) =>
                              _openSettings(state, params, kind),
                          onBackPressed: () => Navigator.of(context).pop(),
                          onNextEpisode: state.nextEpisode != null
                              ? () => _playNextEpisode(state, params)
                              : null,
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
          // StreamingFailure = every source failed: the view's own text.
          message: err is StreamingFailure
              ? null
              : ref.read(errorMapperProvider).map(err).message,
          youtubeVideoId: widget.type == 'youtube' ? widget.queryId : null,
          onRetry: () => ref.invalidate(playerControllerProvider(params)),
        ),
        loading: () => _LeavableLoadingView(
          child: Center(
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
      ),
    );
  }
}

/// Loading / source search with a back button and Esc: on PC the player
/// route sits above the shell's Esc handler, so nothing else can leave
/// (REV-159). Leaving disposes the player, which stops the search.
class _LeavableLoadingView extends StatelessWidget {
  final Widget child;

  /// Live TV's channel keys, which keep working while a channel opens.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// Shown over the loading: the channel number being typed.
  final Widget? overlay;

  const _LeavableLoadingView({
    required this.child,
    this.onKeyEvent,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    void leave() => Navigator.of(context).maybePop();
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): leave},
      child: Focus(
        autofocus: true,
        onKeyEvent: onKeyEvent,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(child: AppBackButton(onTap: leave)),
            ),
            ?overlay,
          ],
        ),
      ),
    );
  }
}
