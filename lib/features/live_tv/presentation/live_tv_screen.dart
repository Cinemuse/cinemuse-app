import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_panel.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/live_tv_guide_screen.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/live_player_section.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_settings_bottom_sheet.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/shared/widgets/offline_placeholder.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Main Live TV screen with side-list + player layout.
class LiveTvScreen extends ConsumerStatefulWidget {
  const LiveTvScreen({super.key});

  @override
  ConsumerState<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends ConsumerState<LiveTvScreen> {
  Timer? _numberInputTimer;
  Timer? _channelSwitchTimer;
  final FocusNode _playerFocusNode = FocusNode();
  final FocusNode _guideFocusNode = FocusNode(debugLabel: 'LiveTvGuide');

  // We use a constant PlayerParams for Live TV to keep the provider alive.
  // The actual channel is swapped via `changeChannel`.
  static const _liveTvParams = PlayerParams('livetv_session', 'livetv');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(livePlayerFocusActionProvider.notifier).state =
            _playerFocusNode.requestFocus;
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
    _numberInputTimer?.cancel();
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

  void _openSettings(CinemaPlayerState state) {
    PlayerSettingsBottomSheet.show(
      context,
      state,
      _liveTvParams,
      (_) {}, // No-op overlay callback for Live TV for now
    );
  }

  // -----------------------------------------------------------------------
  // Number Input (Remote-style navigation)
  // -----------------------------------------------------------------------
  void _handleNumberInput(String digit) {
    final buffer = ref.read(numberInputBufferProvider);
    final newBuffer = buffer + digit;

    // Max 4 digits (LCN up to 9999)
    if (newBuffer.length > 4) return;

    ref.read(numberInputBufferProvider.notifier).state = newBuffer;

    // Reset timer — auto-tune after 1.5s of no input
    _numberInputTimer?.cancel();
    _numberInputTimer = Timer(
      const Duration(milliseconds: 1500),
      _confirmNumberInput,
    );
  }

  void _confirmNumberInput() {
    _numberInputTimer?.cancel();
    if (!mounted) return;
    final buffer = ref.read(numberInputBufferProvider);
    if (buffer.isEmpty) return;
    _tuneToLcn(int.tryParse(buffer) ?? 0);
    ref.read(numberInputBufferProvider.notifier).state = '';
  }

  void _openPlayer(Channel channel) {
    ref.read(selectedChannelProvider.notifier).select(channel);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          queryId: channel.uniqueId,
          type: 'livetv',
          channel: channel,
        ),
      ),
    );
  }

  void _tuneToLcn(int lcn) {
    if (!mounted) return;
    final channelsAsync = ref.read(channelsProvider);
    channelsAsync.whenData((channels) {
      if (!mounted) return;
      final match = channels.where((ch) => ch.lcn == lcn).firstOrNull;
      if (match != null) {
        ref.read(selectedChannelProvider.notifier).select(match);
        final isMobile = Breakpoints.isCompact(context);
        if (isMobile) {
          _playChannel(match);
        } else {
          _openPlayer(match);
        }
      }
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

    // Number keys (both main keyboard and numpad)
    final key = event.logicalKey;
    String? digit;

    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      digit = '0';
    } else if (key == LogicalKeyboardKey.digit1 ||
        key == LogicalKeyboardKey.numpad1) {
      digit = '1';
    } else if (key == LogicalKeyboardKey.digit2 ||
        key == LogicalKeyboardKey.numpad2) {
      digit = '2';
    } else if (key == LogicalKeyboardKey.digit3 ||
        key == LogicalKeyboardKey.numpad3) {
      digit = '3';
    } else if (key == LogicalKeyboardKey.digit4 ||
        key == LogicalKeyboardKey.numpad4) {
      digit = '4';
    } else if (key == LogicalKeyboardKey.digit5 ||
        key == LogicalKeyboardKey.numpad5) {
      digit = '5';
    } else if (key == LogicalKeyboardKey.digit6 ||
        key == LogicalKeyboardKey.numpad6) {
      digit = '6';
    } else if (key == LogicalKeyboardKey.digit7 ||
        key == LogicalKeyboardKey.numpad7) {
      digit = '7';
    } else if (key == LogicalKeyboardKey.digit8 ||
        key == LogicalKeyboardKey.numpad8) {
      digit = '8';
    } else if (key == LogicalKeyboardKey.digit9 ||
        key == LogicalKeyboardKey.numpad9) {
      digit = '9';
    }

    if (digit != null) {
      _handleNumberInput(digit);
      return KeyEventResult.handled;
    }

    // Enter confirms number input immediately if a number is being entered
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final buffer = ref.read(numberInputBufferProvider);
      if (buffer.isNotEmpty) {
        _confirmNumberInput();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Escape handling
    if (key == LogicalKeyboardKey.escape) {
      _numberInputTimer?.cancel();
      ref.read(numberInputBufferProvider.notifier).state = '';
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.valueOrNull == ConnectivityResult.none;

    if (isOffline) {
      return OfflinePlaceholder(
        onRetry: () => ref.invalidate(connectivityProvider),
      );
    }

    final selectedChannel = ref.watch(selectedChannelProvider);
    final numberBuffer = ref.watch(numberInputBufferProvider);
    final isMobile = Breakpoints.isCompact(context);

    // Resolve the nav index FIRST so the listeners below can guard themselves.
    final navIndex = ref.watch(navIndexProvider);
    final isLiveTvTab = navIndex == NavTab.liveTv;

    // React to channel selection changes — only on mobile mini-player
    ref.listen(selectedChannelProvider, (prev, next) {
      if (isMobile &&
          isLiveTvTab &&
          next != null &&
          next.uniqueId != prev?.uniqueId) {
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
    if (isMobile && isLiveTvTab && selectedChannel != null) {
      final ps = ref.watch(playerControllerProvider(_liveTvParams));
      playerState = ps;

      // When the provider first becomes ready (no stream yet) and a channel is
      // already selected, kick off playback in a post-frame callback so we
      // don't call setState during build.
      final stateValue = ps.valueOrNull;
      if (stateValue != null &&
          stateValue.currentStream == null &&
          !stateValue.isResolving) {
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
            ? _buildMobileLayout(selectedChannel, numberBuffer, playerState)
            : _buildChannelGuideBrowser(),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Desktop & TV Layout (Classic Cinemuse EPG TV Guide)
  // -----------------------------------------------------------------------
  Widget _buildChannelGuideBrowser() {
    return RepaintBoundary(
      child: LiveTvGuideScreen(
        focusNode: _guideFocusNode,
        onChannelSelected: _openPlayer,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Mobile Layout
  // -----------------------------------------------------------------------
  Widget _buildMobileLayout(
    Channel? selectedChannel,
    String numberBuffer,
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
                onNumberInput: _handleNumberInput,
                onConfirmNumber: _confirmNumberInput,
                numberBuffer: numberBuffer,
                onExpand: () {
                  if (selectedChannel != null) {
                    _openPlayer(selectedChannel);
                  }
                },
                onSettingsPressed: playerState?.valueOrNull != null
                    ? () => _openSettings(playerState!.valueOrNull!)
                    : null,
              ),
            ),
          ),
        ),
        // EPG card removed for mobile to maximize space
        const Expanded(child: RepaintBoundary(child: ChannelListPanel())),
      ],
    );
  }
}
