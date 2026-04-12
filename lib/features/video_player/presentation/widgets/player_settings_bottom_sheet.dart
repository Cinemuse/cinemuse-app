import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

import 'settings/main_settings_view.dart';
import 'settings/quality_settings_view.dart';
import 'settings/track_settings_view.dart';
import 'settings/subtitle_appearance_view.dart';
import 'settings/live_tv_quality_view.dart';

/// The views available inside the settings sheet.
enum SettingsView { main, quality, audio, subtitles, appearance }

class PlayerSettingsBottomSheet extends ConsumerStatefulWidget {
  final CinemaPlayerState state;
  final PlayerParams params;
  final ValueChanged<SliderOverlayType> onOverlayRequested;
  final SettingsView initialView;

  const PlayerSettingsBottomSheet({
    super.key,
    required this.state,
    required this.params,
    required this.onOverlayRequested,
    this.initialView = SettingsView.main,
  });

  static Future<void> show(
    BuildContext context, 
    CinemaPlayerState state, 
    PlayerParams params, 
    ValueChanged<SliderOverlayType> onOverlayRequested, {
    SettingsView initialView = SettingsView.main,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (ctx) => PlayerSettingsBottomSheet(
        state: state, 
        params: params, 
        onOverlayRequested: onOverlayRequested,
        initialView: initialView,
      ),
    );
  }

  @override
  ConsumerState<PlayerSettingsBottomSheet> createState() => _PlayerSettingsBottomSheetState();
}

class _PlayerSettingsBottomSheetState extends ConsumerState<PlayerSettingsBottomSheet> {
  late SettingsView _currentView;

  @override
  void initState() {
    super.initState();
    _currentView = widget.initialView;
  }

  void _navigateTo(SettingsView view) {
    setState(() => _currentView = view);
  }

  void _navigateBack() {
    setState(() => _currentView = SettingsView.main);
  }

  @override
  Widget build(BuildContext context) {
    final currentState = ref.watch(playerControllerProvider(widget.params)).value ?? widget.state;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final maxSheetHeight = screenHeight * (isLandscape ? 0.9 : 0.6);
    final minSheetHeight = screenHeight * 0.15;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        constraints: BoxConstraints(
          minHeight: minSheetHeight,
          maxHeight: maxSheetHeight,
        ),
        decoration: BoxDecoration(
          color: AppTheme.glass.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Content area
            Flexible(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_currentView),
                    child: _buildView(_currentView, currentState),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildView(SettingsView view, CinemaPlayerState currentState) {
    switch (view) {
      case SettingsView.main:
        return MainSettingsView(
          state: currentState,
          onNavigate: (viewStr) {
            switch (viewStr) {
              case 'quality': _navigateTo(SettingsView.quality); break;
              case 'audio': _navigateTo(SettingsView.audio); break;
              case 'subtitles': _navigateTo(SettingsView.subtitles); break;
              case 'appearance': _navigateTo(SettingsView.appearance); break;
            }
          },
        );
      case SettingsView.quality:
        if (currentState.isLive) {
          return LiveTvQualityView(onBack: _navigateBack, state: currentState);
        }
        return QualitySettingsView(
          state: currentState,
          params: widget.params,
          onBack: _navigateBack,
        );
      case SettingsView.audio:
        return TrackSettingsView(
          state: currentState,
          params: widget.params,
          isSubtitle: false,
          onBack: _navigateBack,
        );
      case SettingsView.subtitles:
        return TrackSettingsView(
          state: currentState,
          params: widget.params,
          isSubtitle: true,
          onBack: _navigateBack,
        );
      case SettingsView.appearance:
        return SubtitleAppearanceView(
          state: currentState,
          params: widget.params,
          onBack: _navigateBack,
          onOverlayRequested: widget.onOverlayRequested,
        );
    }
  }
}
