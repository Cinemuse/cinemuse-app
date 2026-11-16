import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';

import 'settings/live_tv_quality_view.dart';
import 'settings/quality_settings_view.dart';
import 'settings/settings_headers.dart';
import 'settings/settings_tab_bar.dart';
import 'settings/subtitle_appearance_view.dart';
import 'settings/track_settings_view.dart';
export 'settings/settings_tab_bar.dart' show PlayerSettingsTab;

/// The player's two settings buttons: the sources and files (live TV: its
/// quality list), or the tracks and the subtitle look.
enum PlayerSettingsKind { source, tracks }

/// The player's settings: a sheet rising in the bottom-right corner, so the
/// video and its subtitles stay in sight; centred under the video on a
/// phone held upright. The source list has no tabs; the tracks have Audio,
/// Subtitles and Look.
class PlayerSettingsPanel extends ConsumerStatefulWidget {
  final CinemaPlayerState state;
  final PlayerParams params;
  final PlayerSettingsKind kind;
  final PlayerSettingsTab initialTab;

  /// The player opens the next panel on the last tab used.
  final ValueChanged<PlayerSettingsTab>? onTabChanged;

  const PlayerSettingsPanel({
    super.key,
    required this.state,
    required this.params,
    required this.kind,
    this.initialTab = PlayerSettingsTab.audio,
    this.onTabChanged,
  });

  static Future<void> show(
    BuildContext context,
    CinemaPlayerState state,
    PlayerParams params, {
    required PlayerSettingsKind kind,
    PlayerSettingsTab initialTab = PlayerSettingsTab.audio,
    ValueChanged<PlayerSettingsTab>? onTabChanged,
  }) {
    final isUpright = MediaQuery.orientationOf(context) == Orientation.portrait;
    return AppBottomSheet.show(
      context: context,
      // The subtitles change live beside the panel: the video stays bright.
      barrierColor: Colors.transparent,
      // Upright, the video player keeps the top 40% for the video.
      heightFactor: isUpright ? 0.6 : 1,
      cornerWidth: isUpright
          ? null
          : math.max(
              Breakpoints.sideSheetMin,
              MediaQuery.sizeOf(context).width / 3,
            ),
      child: AppBottomSheet(
        blurSigma: 12,
        backgroundColor: AppTheme.glass.withValues(alpha: 0.8),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: 0.1),
          width: 1.5,
        ),
        child: PlayerSettingsPanel(
          state: state,
          params: params,
          kind: kind,
          initialTab: initialTab,
          onTabChanged: onTabChanged,
        ),
      ),
    );
  }

  @override
  ConsumerState<PlayerSettingsPanel> createState() =>
      _PlayerSettingsPanelState();
}

class _PlayerSettingsPanelState extends ConsumerState<PlayerSettingsPanel> {
  late PlayerSettingsTab _tab = widget.initialTab;
  bool get _hasTabs => widget.kind == PlayerSettingsKind.tracks;
  final _tabNodes = [
    for (final tab in PlayerSettingsTab.values)
      FocusNode(debugLabel: 'PlayerSettingsTab.${tab.name}'),
  ];
  final _contentNode = FocusNode(debugLabel: 'PlayerSettingsContent');

  @override
  void initState() {
    super.initState();
    // After the lists' autofocus, which runs in a microtask.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scheduleMicrotask(_focusSomething),
    );
  }

  @override
  void dispose() {
    for (final node in _tabNodes) {
      node.dispose();
    }
    _contentNode.dispose();
    super.dispose();
  }

  /// A list with no option on (no sources yet) focuses nothing; the keys
  /// still need a target in the panel.
  void _focusSomething() {
    if (!mounted || _contentNode.hasFocus) return;
    if (_tabNodes.any((node) => node.hasFocus)) return;
    if (!_hasTabs) {
      _contentNode.traversalDescendants.firstOrNull?.requestFocus();
    } else {
      _tabNodes[_tab.index].requestFocus();
    }
  }

  void _select(PlayerSettingsTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    widget.onTabChanged?.call(tab);
  }

  KeyEventResult _onPanelKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onContentKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // Up from the first row goes to the selected tab, not the one above.
    if (key == LogicalKeyboardKey.arrowUp && _hasTabs && _isOnFirstRow()) {
      _tabNodes[_tab.index].requestFocus();
      return KeyEventResult.handled;
    }
    // Only the look controls have something at their side.
    final isSideways =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
    if (isSideways && !(_hasTabs && _tab == PlayerSettingsTab.look)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _isOnFirstRow() {
    final focused = FocusManager.instance.primaryFocus;
    final rows = _contentNode.traversalDescendants;
    if (focused == null || rows.isEmpty) return false;
    final top = rows.map((node) => node.rect.top).reduce(math.min);
    return focused.rect.top <= top + 1;
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(playerControllerProvider(widget.params)).value ??
        widget.state;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onPanelKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: !_hasTabs
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: SettingsPanelTitle(
                      AppLocalizations.of(context)!.playerSelectQuality,
                    ),
                  )
                : SettingsTabBar(
                    selected: _tab,
                    focusNodes: _tabNodes,
                    onSelect: _select,
                  ),
          ),
          Expanded(
            child: Focus(
              focusNode: _contentNode,
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _onContentKey,
              child: KeyedSubtree(
                key: ValueKey(_hasTabs ? _tab : null),
                child: _TabContent(
                  tab: _hasTabs ? _tab : null,
                  state: state,
                  params: widget.params,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The list of one tab; the source list (live TV: its quality list) when
/// [tab] is null.
class _TabContent extends StatelessWidget {
  final PlayerSettingsTab? tab;
  final CinemaPlayerState state;
  final PlayerParams params;

  const _TabContent({
    required this.tab,
    required this.state,
    required this.params,
  });

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      null when state.isLive => LiveTvQualityView(state: state, params: params),
      null => QualitySettingsView(state: state, params: params),
      PlayerSettingsTab.audio => TrackSettingsView(
        state: state,
        params: params,
        isSubtitle: false,
      ),
      PlayerSettingsTab.subtitles => TrackSettingsView(
        state: state,
        params: params,
        isSubtitle: true,
      ),
      PlayerSettingsTab.look => SubtitleAppearanceView(
        state: state,
        params: params,
      ),
    };
  }
}
