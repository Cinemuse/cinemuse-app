import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_panel.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/live_player_section.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/epg_info_card.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/number_input_osd.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';

/// Main Live TV screen with side-list + player layout.
class LiveTvScreen extends ConsumerStatefulWidget {
  const LiveTvScreen({super.key});

  @override
  ConsumerState<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends ConsumerState<LiveTvScreen> {
  Player? _player;
  mkv.VideoController? _videoController;
  Timer? _numberInputTimer;

  String? _streamError;
  bool _playerInitialized = false;

  // Track subscriptions so they can be cancelled on dispose
  final List<StreamSubscription> _subscriptions = [];

  // Debounce rapid channel clicks — only the last one within 300ms fires
  Timer? _channelSwitchTimer;
  // Generation counter to cancel stale async operations
  int _playGeneration = 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  /// Initialize the player on demand (first visit to the tab).
  void _initPlayer() {
    if (_playerInitialized) return;
    _playerInitialized = true;

    _player = Player();
    (_player!.platform as dynamic).setProperty('demuxer-max-bytes', '2M');
    (_player!.platform as dynamic).setProperty('demuxer-readahead-secs', '3');
    (_player!.platform as dynamic).setProperty('cache', 'yes');
    (_player!.platform as dynamic).setProperty('cache-secs', '3');
    _videoController = mkv.VideoController(
      _player!,
      configuration: mkv.VideoControllerConfiguration(
        hwdec: io.Platform.isAndroid ? 'mediacodec' : 'auto',
        vo: io.Platform.isAndroid ? 'gpu' : null,
      ),
    );

    _subscriptions.add(_player!.stream.playing.listen((playing) {
    }));
    _subscriptions.add(_player!.stream.error.listen((error) {
      if (mounted && error.contains('Failed to open')) {
        setState(() => _streamError = error);
      }
    }));
    _subscriptions.add(_player!.stream.buffering.listen((buffering) {
    }));
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _numberInputTimer?.cancel();
    _channelSwitchTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _player?.dispose();
    super.dispose();
  }

  /// Debounced entry-point: coalesces rapid clicks into one switch.
  void _playChannel(Channel channel) {
    _channelSwitchTimer?.cancel();
    _channelSwitchTimer = Timer(const Duration(milliseconds: 300), () {
      _doPlayChannel(channel);
    });
  }

  /// Channel switch with generation guard.
  ///
  /// Skips stop() — open() replaces the current media atomically inside mpv.
  /// DASH streams are filtered out on Windows (see Channel.isPlayable) to
  /// avoid a libmpv crash (github.com/media-kit/media-kit/issues/973).
  Future<void> _doPlayChannel(Channel channel) async {
    if (!mounted || !_playerInitialized || _player == null) return;

    final gen = ++_playGeneration;

    setState(() => _streamError = null);

    try {
      await _player!.open(Media(channel.url));
    } catch (e) {
      // Silently handle open errors — the error stream listener
      // will set _streamError for 'Failed to open' cases.
    }
  }

  // -----------------------------------------------------------------------
  // Number Input (Remote-style navigation)
  // -----------------------------------------------------------------------
  void _handleNumberInput(String digit) {
    final buffer = ref.read(numberInputBufferProvider);
    final newBuffer = buffer + digit;

    // Max 3 digits (LCN up to 999)
    if (newBuffer.length > 3) return;

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

    // React to channel selection changes
    ref.listen(selectedChannelProvider, (prev, next) {
      if (next != null && next.lcn != prev?.lcn) {
        _playChannel(next);
      }
    });

    // Auto-select first channel when data loads
    ref.listen(channelsProvider, (prev, next) {
      next.whenData((channels) {
        if (channels.isNotEmpty && ref.read(selectedChannelProvider) == null) {
          ref.read(selectedChannelProvider.notifier).state = channels.first;
        }
      });
    });

    // Lazy init: create player only when Live TV tab is active
    final navIndex = ref.watch(navIndexProvider);
    if (navIndex == 2) {
      final wasJustCreated = !_playerInitialized;
      _initPlayer();
      // If player was just created and a channel is already selected, open it
      if (wasJustCreated && selectedChannel != null) {
        _playChannel(selectedChannel);
      } else if (!wasJustCreated && selectedChannel != null && _player?.state.playing == false) {
        _player?.play();
      }
    } else {
      _player?.pause();
    }

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: isMobile
          ? _buildMobileLayout(selectedChannel, numberBuffer)
          : _buildDesktopLayout(selectedChannel, numberBuffer),
    );
  }

  // -----------------------------------------------------------------------
  // Desktop Layout
  // -----------------------------------------------------------------------
  Widget _buildDesktopLayout(Channel? selectedChannel, String numberBuffer) {
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
            Expanded(child: const ChannelListPanel()),

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
                        child: LivePlayerSection(
                          channel: selectedChannel,
                          player: selectedChannel != null ? _player : null,
                          videoController:
                              selectedChannel != null ? _videoController : null,
                          streamError: _streamError,
                          onNumberInput: _handleNumberInput,
                          onConfirmNumber: _confirmNumberInput,
                          numberBuffer: numberBuffer,
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
  Widget _buildMobileLayout(Channel? selectedChannel, String numberBuffer) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: LivePlayerSection(
              channel: selectedChannel,
              player: selectedChannel != null ? _player : null,
              videoController:
                  selectedChannel != null ? _videoController : null,
              streamError: _streamError,
              onNumberInput: _handleNumberInput,
              onConfirmNumber: _confirmNumberInput,
              numberBuffer: numberBuffer,
            ),
          ),
        ),
        if (selectedChannel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _buildEpgCard(selectedChannel),
          ),
        const Expanded(child: ChannelListPanel()),
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
