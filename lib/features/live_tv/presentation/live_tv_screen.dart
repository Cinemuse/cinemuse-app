import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_panel.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/live_player_section.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/epg_info_card.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_settings_bottom_sheet.dart';

/// Main Live TV screen with side-list + player layout.
class LiveTvScreen extends ConsumerStatefulWidget {
  const LiveTvScreen({super.key});

  @override
  ConsumerState<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends ConsumerState<LiveTvScreen> {
  Timer? _numberInputTimer;
  Timer? _channelSwitchTimer;

  // We use a constant PlayerParams for Live TV to keep the provider alive.
  // The actual channel is swapped via `changeChannel`.
  static const _liveTvParams = PlayerParams('livetv_session', 'livetv');

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _numberInputTimer?.cancel();
    _channelSwitchTimer?.cancel();
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
    
    // Delegate to the unified PlayerController
    ref.read(playerControllerProvider(_liveTvParams).notifier).changeChannel(channel);
  }

  void _openSettings(CinemaPlayerState state) {
    PlayerSettingsBottomSheet.show(context, state, _liveTvParams);
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
    _numberInputTimer = Timer(const Duration(milliseconds: 1500), () {
      _confirmNumberInput();
    });
  }

  void _confirmNumberInput() {
    _numberInputTimer?.cancel();
    if (!mounted) return;
    final buffer = ref.read(numberInputBufferProvider);
    if (buffer.isEmpty) return;
    _tuneToLcn(int.tryParse(buffer) ?? 0);
    ref.read(numberInputBufferProvider.notifier).state = '';
  }

  void _tuneToLcn(int lcn) {
    if (!mounted) return;
    final channelsAsync = ref.read(channelsProvider);
    channelsAsync.whenData((channels) {
      if (!mounted) return;
      final match = channels.where((ch) => ch.lcn == lcn).firstOrNull;
      if (match != null) {
        ref.read(selectedChannelProvider.notifier).state = match;
        _playChannel(match);
      }
    });
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted) return false;
    // Only handle when Live TV tab is active
    if (ref.read(navIndexProvider) != 2) return false;
    if (event is! KeyDownEvent) return false;

    // Number keys (both main keyboard and numpad)
    final key = event.logicalKey;
    String? digit;

    if (key == LogicalKeyboardKey.digit0 ||
        key == LogicalKeyboardKey.numpad0) {
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
      return true;
    }

    // Enter confirms number input immediately
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _confirmNumberInput();
      return true;
    }

    // Escape cancels number input
    if (key == LogicalKeyboardKey.escape) {
      _numberInputTimer?.cancel();
      ref.read(numberInputBufferProvider.notifier).state = '';
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final selectedChannel = ref.watch(selectedChannelProvider);
    final numberBuffer = ref.watch(numberInputBufferProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Resolve the nav index FIRST so the listeners below can guard themselves.
    final navIndex = ref.watch(navIndexProvider);
    final isLiveTvTab = navIndex == 2;

    // React to channel selection changes — only when the Live TV tab is active
    // so we don't create the Player on other pages.
    ref.listen(selectedChannelProvider, (prev, next) {
      if (isLiveTvTab && next != null && next.uniqueId != prev?.uniqueId) {
        _playChannel(next);
      }
    });

    // Auto-select first channel when data loads.
    // Intentionally does NOT call _playChannel here; the player isn't
    // initialised yet. The build-time trigger below handles first-play.
    ref.listen(channelsProvider, (prev, next) {
      next.whenData((channels) {
        if (channels.isNotEmpty && ref.read(selectedChannelProvider) == null) {
          ref.read(selectedChannelProvider.notifier).state = channels.first;
        }
      });
    });

    AsyncValue<CinemaPlayerState>? playerState;
    if (isLiveTvTab) {
      final ps = ref.watch(playerControllerProvider(_liveTvParams));
      playerState = ps;

      // When the provider first becomes ready (no stream yet) and a channel is
      // already selected, kick off playback in a post-frame callback so we
      // don't call setState during build.
      final stateValue = ps.valueOrNull;
      if (selectedChannel != null && stateValue != null && stateValue.currentStream == null && !stateValue.isResolving) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _playChannel(selectedChannel);
        });
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: isMobile
          ? _buildMobileLayout(selectedChannel, numberBuffer, playerState)
          : _buildDesktopLayout(selectedChannel, numberBuffer, playerState),
    );
  }

  // -----------------------------------------------------------------------
  // Desktop Layout
  // -----------------------------------------------------------------------
  Widget _buildDesktopLayout(Channel? selectedChannel, String numberBuffer, AsyncValue<CinemaPlayerState>? playerState) {
    const double padding = 20;
    const double epgHeight = 200;
    const double gap = 16;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final playerHeight = availableHeight - (padding * 2) - epgHeight - gap;
        final playerWidth = playerHeight * (16 / 9);
        final rightPanelWidth = playerWidth + (padding * 2);

        return Row(
          children: [
            const Expanded(
              child: RepaintBoundary(
                child: ChannelListPanel(),
              ),
            ),

            SizedBox(
              width: rightPanelWidth.clamp(400, constraints.maxWidth * 0.7),
              child: Padding(
                padding: const EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Player — Flexible prevents overflow
                    Flexible(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: RepaintBoundary(
                          child: LivePlayerSection(
                            channel: selectedChannel,
                            playerState: playerState,
                            onNumberInput: _handleNumberInput,
                            onConfirmNumber: _confirmNumberInput,
                            numberBuffer: numberBuffer,
                            onSettingsPressed: playerState?.valueOrNull != null 
                              ? () => _openSettings(playerState!.valueOrNull!)
                              : null,
                          ),
                        ),
                      ),
                    ),

                    if (selectedChannel != null) ...[
                      const SizedBox(height: gap),
                      _buildEpgCard(selectedChannel),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Mobile Layout
  // -----------------------------------------------------------------------
  Widget _buildMobileLayout(Channel? selectedChannel, String numberBuffer, AsyncValue<CinemaPlayerState>? playerState) {
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
                onNumberInput: _handleNumberInput,
                onConfirmNumber: _confirmNumberInput,
                numberBuffer: numberBuffer,
                onSettingsPressed: playerState?.valueOrNull != null 
                  ? () => _openSettings(playerState!.valueOrNull!)
                  : null,
              ),
            ),
          ),
        ),
        // EPG card removed for mobile to maximize space
        const Expanded(
          child: RepaintBoundary(
            child: ChannelListPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildEpgCard(Channel channel) {
    final currentProgram = ref.watch(currentProgramProvider(channel));
    final nextProgram = ref.watch(nextProgramProvider(channel));

    return EpgInfoCard(
      currentProgram: currentProgram,
      nextProgram: nextProgram,
      channelName: channel.name,
    );
  }
}
