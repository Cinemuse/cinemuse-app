import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'settings_widgets.dart';

class QualitySettingsView extends ConsumerStatefulWidget {
  final CinemaPlayerState state;
  final PlayerParams params;
  final VoidCallback onBack;

  const QualitySettingsView({
    super.key,
    required this.state,
    required this.params,
    required this.onBack,
  });

  @override
  ConsumerState<QualitySettingsView> createState() =>
      _QualitySettingsViewState();
}

class _QualitySettingsViewState extends ConsumerState<QualitySettingsView> {
  bool _filesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final params = widget.params;
    final currentState =
        ref.watch(playerControllerProvider(params)).value ?? widget.state;
    final l10n = AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final sortedFiles =
        (currentState.currentStream?.files ?? [])
            .map(StreamFileInfo.fromMap)
            .toList()
          ..sort(
            (a, b) =>
                a.filename.toLowerCase().compareTo(b.filename.toLowerCase()),
          );

    return Stack(
      children: [
        Column(
          children: [
            SubViewHeader(
              title: l10n.playerSelectQuality,
              onBack: widget.onBack,
              compact: isLandscape,
            ),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isLandscape ? 4 : 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (currentState.currentStream?.files.isNotEmpty ??
                        false) ...[
                      DpadFocusable(
                        showFocusRing: true,
                        onTap: () =>
                            setState(() => _filesExpanded = !_filesExpanded),
                        borderRadius: AppTheme.radius12,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: isLandscape ? 8 : 12,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.folder_open_rounded,
                                color: AppTheme.accent,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.playerFiles.toUpperCase(),
                                      style: const TextStyle(
                                        color: AppTheme.textWhite,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Text(
                                      l10n.playerFilesCount(
                                        currentState
                                                .currentStream
                                                ?.files
                                                .length ??
                                            0,
                                      ),
                                      style: TextStyle(
                                        color: AppTheme.textMuted.withAlpha(
                                          128,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _filesExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppTheme.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_filesExpanded) ...[
                        const SizedBox(height: 8),
                        ...sortedFiles.map((file) {
                          final isSelected =
                              file.id ==
                              currentState.currentStream?.activeFileId;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: DpadFocusable(
                              showFocusRing: true,
                              borderRadius: AppTheme.radius12,
                              onTap: () {
                                // Would restart at 0:00 (REV-172).
                                if (isSelected) return;
                                ref
                                    .read(
                                      playerControllerProvider(params).notifier,
                                    )
                                    .changeFile(file.id);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.accent.withValues(alpha: 0.12)
                                      : AppTheme.textWhite.withValues(
                                          alpha: 0.04,
                                        ),
                                  borderRadius: AppTheme.radius12,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.accent.withValues(alpha: 0.6)
                                        : AppTheme.textWhite.withValues(
                                            alpha: 0.08,
                                          ),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            file.filename,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? AppTheme.textWhite
                                                  : AppTheme.textWhite
                                                        .withValues(alpha: 0.7),
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${file.sizeInGB.toStringAsFixed(2)} GB",
                                            style: TextStyle(
                                              color: AppTheme.textMuted
                                                  .withValues(alpha: 0.5),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppTheme.accent,
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                      const Divider(color: AppTheme.borderSubtle, height: 32),
                    ],

                    Padding(
                      padding: const EdgeInsets.only(
                        left: 8,
                        bottom: 8,
                        top: 12,
                      ),
                      child: Text(
                        l10n.playerQuality.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    ...List.generate(currentState.availableStreams.length, (
                      index,
                    ) {
                      final stream = currentState.availableStreams[index];
                      final isSelected =
                          currentState.currentStream?.candidate.uniqueId ==
                          stream.uniqueId;
                      final hasSelectedInList = currentState.availableStreams
                          .any(
                            (s) =>
                                currentState
                                    .currentStream
                                    ?.candidate
                                    .uniqueId ==
                                s.uniqueId,
                          );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: DpadFocusable(
                          autofocus:
                              isSelected || (index == 0 && !hasSelectedInList),
                          scale: 1.02,
                          borderRadius: AppTheme.radiusLg,
                          onTap: () {
                            if (isSelected) return;
                            ref
                                .read(playerControllerProvider(params).notifier)
                                .changeSource(stream);
                          },
                          builder: (context, isFocused, isHovered, child) {
                            final isHighlighted = isFocused || isHovered;
                            return Container(
                              padding: EdgeInsets.all(isLandscape ? 12 : 16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.accent.withValues(alpha: 0.1)
                                    : (isHighlighted
                                          ? AppTheme.textWhite.withValues(
                                              alpha: 0.08,
                                            )
                                          : AppTheme.textWhite.withValues(
                                              alpha: 0.03,
                                            )),
                                borderRadius: AppTheme.radiusLg,
                                border: Border.all(
                                  color: isFocused
                                      ? AppTheme.textWhite
                                      : (isSelected
                                            ? AppTheme.accent.withValues(
                                                alpha: 0.5,
                                              )
                                            : (isHovered
                                                  ? AppTheme.textWhite
                                                        .withValues(alpha: 0.2)
                                                  : AppTheme.textWhite
                                                        .withValues(
                                                          alpha: 0.05,
                                                        ))),
                                  width: isFocused ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: StreamMetadataOverview(
                                          stream: stream,
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppTheme.accent,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    stream.title,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppTheme.textWhite.withValues(
                                              alpha: 0.9,
                                            )
                                          : AppTheme.textMuted.withValues(
                                              alpha: 0.6,
                                            ),
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w500
                                          : FontWeight.w400,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const SizedBox.shrink(),
                        ),
                      );
                    }),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),

        if (currentState.isResolving)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.scrim.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
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
            ),
          ),

        if (currentState.error != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.9),
                borderRadius: AppTheme.radius12,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.scrim.withValues(alpha: 0.3),
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
                      currentState.error!,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                    onPressed: () => ref
                        .read(playerControllerProvider(widget.params).notifier)
                        .clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
