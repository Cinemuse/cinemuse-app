import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_filter_sheet.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_panel.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/live_tv_guide_screen.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/live_player_section.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/number_input_osd.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/playlist_management_sheet.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_settings_panel.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/offline_placeholder.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Main Live TV screen with side-list + player layout.
class LiveTvScreen extends ConsumerStatefulWidget {
  const LiveTvScreen({super.key});

  @override
  ConsumerState<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends ConsumerState<LiveTvScreen> {
  Timer? _channelSwitchTimer;
  final FocusNode _playerFocusNode = FocusNode();
  final FocusNode _guideFocusNode = FocusNode(debugLabel: 'LiveTvGuide');
  bool _isBigPlayerOpen = false;

  /// Whether this visit to the Live TV tab already said which playlists and
  /// guides failed to load. The screen stays built on the other tabs.
  bool _isFailureMessageShown = false;

  // We use a constant PlayerParams for Live TV to keep the provider alive.
  // The actual channel is swapped via `changeChannel`.
  static const _liveTvParams = PlayerParams('livetv_session', 'livetv');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(livePlayerFocusActionProvider.notifier)
            .set(_playerFocusNode.requestFocus);
        ref
            .read(pageContentFocusActionsProvider.notifier)
            .update(
              (map) => {
                ...map,
                NavTab.liveTv: () {
                  final isMobile = Breakpoints.isCompact(context);
                  if (isMobile) {
                    _playerFocusNode.requestFocus();
                  } else {
                    _guideFocusNode.requestFocus();
                  }
                },
              },
            );
      }
    });
  }

  @override
  void dispose() {
    _channelSwitchTimer?.cancel();
    _playerFocusNode.dispose();
    _guideFocusNode.dispose();
    super.dispose();
  }

  /// Debounced entry-point: coalesces rapid clicks into one switch.
  void _playChannel(Channel channel) {
    _channelSwitchTimer?.cancel();
    _channelSwitchTimer = Timer(const Duration(milliseconds: 300), () {
      _doPlayChannel(channel);
    });
  }

  Future<void> _doPlayChannel(Channel channel) async {
    if (!mounted) return;

    // Push to recents so the Recents tab stays populated
    // Recents are a convenience: playback does not wait for the save.
    unawaited(
      ref.read(recentChannelIdsProvider.notifier).push(channel.uniqueId),
    );

    // Delegate to the unified PlayerController
    // The player shows its own loading and error state.
    unawaited(
      ref
          .read(playerControllerProvider(_liveTvParams).notifier)
          .changeChannel(channel),
    );
  }

  Future<void> _openSettings(
    CinemaPlayerState state,
    PlayerSettingsKind kind,
  ) => PlayerSettingsPanel.show(context, state, _liveTvParams, kind: kind);

  void _typeChannelDigit(String digit) => ref
      .read(channelNumberEntryProvider.notifier)
      .type(digit, onFound: _tuneTo);

  Future<void> _openPlayer(Channel channel) async {
    _channelSwitchTimer?.cancel();
    ref.read(selectedChannelProvider.notifier).select(channel);
    // The mini-player stops while the big player is open, or both would
    // play (REV-156); it restarts on the last channel when the user is back.
    setState(() => _isBigPlayerOpen = true);
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoPlayerScreen(
          queryId: channel.uniqueId,
          type: 'livetv',
          channel: channel,
        ),
      ),
    );
    if (mounted) setState(() => _isBigPlayerOpen = false);
  }

  void _tuneTo(Channel channel) {
    if (!mounted) return;
    ref.read(selectedChannelProvider.notifier).select(channel);
    if (Breakpoints.isCompact(context)) {
      _playChannel(channel);
    } else {
      unawaited(_openPlayer(channel));
    }
  }

  /// Once per visit, when both lists have loaded: which ones failed, with a
  /// button to the playlists.
  void _showLoadFailuresOnce(AsyncValue<FailedLiveTvSources> failed) {
    final value = failed.value;
    if (_isFailureMessageShown || failed.isLoading || value == null) return;
    _isFailureMessageShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final message = liveTvFailedSourcesMessage(value, l10n);
      if (message == null) return;
      AppSnackBar.show(
        context,
        message: message,
        isError: true,
        actionLabel: l10n.commonShow,
        onAction: () => showChannelFilterSheet(
          context,
          initialTab: LiveTvSheetTab.playlists,
        ),
        duration: const Duration(seconds: 6),
      );
    });
  }

  bool _isTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus.context == null || !focus.context!.mounted) {
      return false;
    }
    final context = focus.context!;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (!mounted) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Do not intercept keystrokes if the user is typing into a text field (e.g. search, dialog)
    if (_isTextInputFocused()) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final digit = channelDigitFor(key);
    if (digit != null) {
      _typeChannelDigit(digit);
      return KeyEventResult.handled;
    }

    // Enter tunes at once while a number is being typed.
    final numberEntry = ref.read(channelNumberEntryProvider.notifier);
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (ref.read(channelNumberEntryProvider).isEmpty) {
        return KeyEventResult.ignored;
      }
      numberEntry.confirm();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) numberEntry.clear();

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.value == ConnectivityResult.none;

    if (isOffline) {
      return OfflinePlaceholder(
        onRetry: () => ref.invalidate(connectivityProvider),
      );
    }

    final selectedChannel = ref.watch(selectedChannelProvider);
    final isMobile = Breakpoints.isCompact(context);

    // Resolve the nav index FIRST so the listeners below can guard themselves.
    final navIndex = ref.watch(navIndexProvider);
    final isLiveTvTab = navIndex == NavTab.liveTv;
    final isMiniPlayerOn = isMobile && isLiveTvTab && !_isBigPlayerOpen;

    if (isLiveTvTab) {
      _showLoadFailuresOnce(ref.watch(failedLiveTvSourcesProvider));
    } else {
      _isFailureMessageShown = false;
    }

    // React to channel selection changes — only on mobile mini-player
    ref.listen(selectedChannelProvider, (prev, next) {
      if (isMiniPlayerOn && next != null && next.uniqueId != prev?.uniqueId) {
        _playChannel(next);
      }
    });

    // Auto-select first channel when data loads on mobile
    ref.listen(channelsProvider, (prev, next) {
      next.whenData((channels) {
        if (channels.isNotEmpty && ref.read(selectedChannelProvider) == null) {
          ref.read(selectedChannelProvider.notifier).select(channels.first);
        }
      });
    });

    AsyncValue<CinemaPlayerState>? playerState;
    // No channel (e.g. every playlist removed): not watching the player
    // disposes it, which stops playback (REV-271).
    if (isMiniPlayerOn && selectedChannel != null) {
      final ps = ref.watch(playerControllerProvider(_liveTvParams));
      playerState = ps;

      // When the provider first becomes ready (no stream yet) and a channel is
      // already selected, kick off playback in a post-frame callback so we
      // don't call setState during build. Not after the player gave up on
      // the channel (no stream, with an error): that restarted it forever.
      final stateValue = ps.value;
      if (stateValue != null &&
          stateValue.currentStream == null &&
          !stateValue.isResolving &&
          stateValue.error == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _playChannel(selectedChannel);
        });
      }
    }

    return Focus(
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: Scaffold(
        backgroundColor: AppTheme.primary,
        body: isMobile
            ? _buildMobileLayout(selectedChannel, playerState)
            : _buildChannelGuideBrowser(),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Desktop & TV Layout (Classic Cinemuse EPG TV Guide)
  // -----------------------------------------------------------------------
  Widget _buildChannelGuideBrowser() {
    return Stack(
      children: [
        RepaintBoundary(
          child: LiveTvGuideScreen(
            focusNode: _guideFocusNode,
            onChannelSelected: _openPlayer,
          ),
        ),
        // The number being typed, as the player shows it.
        Consumer(
          builder: (context, ref, _) =>
              NumberInputOsd(buffer: ref.watch(channelNumberEntryProvider)),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Mobile Layout
  // -----------------------------------------------------------------------
  Widget _buildMobileLayout(
    Channel? selectedChannel,
    AsyncValue<CinemaPlayerState>? playerState,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: RepaintBoundary(
              child: LivePlayerSection(
                channel: selectedChannel,
                playerState: playerState,
                focusNode: _playerFocusNode,
                onChannelNumberFound: _tuneTo,
                onExpand: () {
                  if (selectedChannel != null) {
                    unawaited(_openPlayer(selectedChannel));
                  }
                },
                onSettingsPressed: playerState?.value != null
                    ? (kind) => _openSettings(playerState!.value!, kind)
                    : null,
              ),
            ),
          ),
        ),
        // EPG card removed for mobile to maximize space
        Expanded(
          child: RepaintBoundary(
            child: ChannelListPanel(onOpenPlayer: _openPlayer),
          ),
        ),
      ],
    );
  }
}
