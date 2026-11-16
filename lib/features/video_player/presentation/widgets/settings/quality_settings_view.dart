import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'selectable_option_tile.dart';
import 'settings_headers.dart';
import 'stream_metadata_overview.dart';

class QualitySettingsView extends ConsumerStatefulWidget {
  final CinemaPlayerState state;
  final PlayerParams params;

  const QualitySettingsView({
    super.key,
    required this.state,
    required this.params,
  });

  @override
  ConsumerState<QualitySettingsView> createState() =>
      _QualitySettingsViewState();
}

class _QualitySettingsViewState extends ConsumerState<QualitySettingsView> {
  bool _filesExpanded = false;
  final _startKey = UniqueKey();
  int? _start;

  PlayerController get _controller =>
      ref.read(playerControllerProvider(widget.params).notifier);

  /// The row the list opens on: the top, unless the playing source is
  /// further down; then the row above it. The list builds only the rows in
  /// sight, so a title with hundreds of sources opens at once.
  static int _startOf(List<StreamCandidate> sources, String? currentId) {
    final index = sources.indexWhere((s) => s.uniqueId == currentId);
    return index < 3 ? 0 : index - 1;
  }

  /// Picking a source or a file closes the panel, so the keys go back to the
  /// player (REV-283). The player shows a failed switch itself.
  void _pickAndClose(Future<void> Function(PlayerController) pick) {
    unawaited(pick(_controller));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentState =
        ref.watch(playerControllerProvider(widget.params)).value ??
        widget.state;
    final l10n = AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final currentStream = currentState.currentStream;
    final error = currentState.error;
    final vertical = isLandscape ? 4.0 : 8.0;

    final sources = currentState.availableStreams;
    final currentId = currentStream?.candidate.uniqueId;
    final hasSelectedInList = sources.any((s) => s.uniqueId == currentId);
    final start = math.min(
      _start ??= _startOf(sources, currentId),
      sources.length,
    );

    // Focus starts on the playing source, or the first one.
    Widget sourceTile(int index) {
      final stream = sources[index];
      return _SourceTile(
        stream: stream,
        isSelected: stream.uniqueId == currentId,
        autofocus:
            stream.uniqueId == currentId || (index == 0 && !hasSelectedInList),
        compact: isLandscape,
        onPick: (stream) => _pickAndClose((c) => c.changeSource(stream)),
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          center: start > 0 ? _startKey : null,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, vertical, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (currentStream != null &&
                        currentStream.files.isNotEmpty) ...[
                      _FileList(
                        stream: currentStream,
                        isExpanded: _filesExpanded,
                        compact: isLandscape,
                        onToggle: () =>
                            setState(() => _filesExpanded = !_filesExpanded),
                        onPick: (id) => _pickAndClose((c) => c.changeFile(id)),
                      ),
                      const Divider(color: AppTheme.borderSubtle, height: 32),
                    ],
                    SettingsSectionTitle(l10n.playerQuality),
                  ],
                ),
              ),
            ),
            // The rows above the start, built upwards from it.
            if (start > 0)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: start,
                  itemBuilder: (_, i) => sourceTile(start - 1 - i),
                ),
              ),
            SliverPadding(
              key: _startKey,
              padding: EdgeInsets.fromLTRB(16, 0, 16, vertical + 40),
              sliver: SliverList.builder(
                itemCount: sources.length - start,
                itemBuilder: (_, i) => sourceTile(start + i),
              ),
            ),
          ],
        ),
        if (currentState.isResolving)
          const Positioned.fill(child: _ResolvingOverlay()),
        if (error != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _ErrorBanner(
              message: error,
              onClose: () => _controller.clearError(),
            ),
          ),
      ],
    );
  }
}

/// The files of a pack, in a folder that opens and closes.
class _FileList extends StatelessWidget {
  final ResolvedStream stream;
  final bool isExpanded;
  final bool compact;
  final VoidCallback onToggle;
  final ValueChanged<int> onPick;

  const _FileList({
    required this.stream,
    required this.isExpanded,
    required this.compact,
    required this.onToggle,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final files = StreamFileInfo.byName(stream.files);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsAccordionHeader(
          title: l10n.playerFiles,
          subtitle: l10n.playerFilesCount(stream.files.length),
          isExpanded: isExpanded,
          onTap: onToggle,
          compact: compact,
        ),
        if (isExpanded) ...[
          const SizedBox(height: 8),
          for (final file in files)
            _FileTile(
              file: file,
              isSelected: file.id == stream.activeFileId,
              onPick: onPick,
            ),
        ],
      ],
    );
  }
}

class _FileTile extends StatelessWidget {
  final StreamFileInfo file;
  final bool isSelected;
  final ValueChanged<int> onPick;

  const _FileTile({
    required this.file,
    required this.isSelected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableOptionTile(
      isSelected: isSelected,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () {
        // Would restart at 0:00 (REV-172).
        if (isSelected) return;
        onPick(file.id);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.filename,
            style: TextStyle(
              color: isSelected
                  ? AppTheme.textWhite
                  : AppTheme.textWhite.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            "${file.sizeInGB.toStringAsFixed(2)} GB",
            style: TextStyle(
              color: AppTheme.textMuted.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final StreamCandidate stream;
  final bool isSelected;
  final bool autofocus;
  final bool compact;
  final ValueChanged<StreamCandidate> onPick;

  const _SourceTile({
    required this.stream,
    required this.isSelected,
    required this.autofocus,
    required this.compact,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableOptionTile(
      isSelected: isSelected,
      autofocus: autofocus,
      padding: EdgeInsets.all(compact ? 12 : 16),
      onTap: () {
        if (isSelected) return;
        onPick(stream);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamMetadataOverview(stream: stream),
          const SizedBox(height: 10),
          Text(
            stream.title,
            style: TextStyle(
              color: isSelected
                  ? AppTheme.textWhite.withValues(alpha: 0.9)
                  : AppTheme.textMuted.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Covers the panel while a picked source is being resolved.
class _ResolvingOverlay extends StatelessWidget {
  const _ResolvingOverlay();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.accent),
            const SizedBox(height: 20),
            Text(
              l10n.playerResolvingStream,
              style: TextStyle(
                color: AppTheme.textWhite.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.playerCheckingDebridCache,
              style: TextStyle(
                color: AppTheme.textWhite.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _ErrorBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.9),
        borderRadius: AppTheme.radius12,
        boxShadow: [
          BoxShadow(
            color: colors.scrim.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.textWhite,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.commonClose,
            icon: const Icon(
              Icons.close_rounded,
              color: AppTheme.textSecondary,
              size: 18,
            ),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}
