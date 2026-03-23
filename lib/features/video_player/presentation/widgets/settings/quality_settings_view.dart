import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
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
  ConsumerState<QualitySettingsView> createState() => _QualitySettingsViewState();
}

class _QualitySettingsViewState extends ConsumerState<QualitySettingsView> {
  bool _filesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final params = widget.params;
    final currentState = ref.watch(playerControllerProvider(params)).value ?? widget.state;
    final l10n = AppLocalizations.of(context)!;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // Sort files alphabetically by filename
    final sortedFiles = List<Map<String, dynamic>>.from(currentState.currentStream?.files ?? []);
    sortedFiles.sort((a, b) {
      final nameA = (a['path'] as String? ?? '').split('/').last.toLowerCase();
      final nameB = (b['path'] as String? ?? '').split('/').last.toLowerCase();
      return nameA.compareTo(nameB);
    });

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
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: isLandscape ? 4 : 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Files Section (Accordion)
                    if (currentState.currentStream?.files.isNotEmpty ?? false) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _filesExpanded = !_filesExpanded),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: isLandscape ? 8 : 12),
                            child: Row(
                              children: [
                                const Icon(Icons.folder_open_rounded, color: AppTheme.accent, size: 20),
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
                                        "${currentState.currentStream?.files.length} files available",
                                        style: TextStyle(color: AppTheme.textMuted.withAlpha(128), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _filesExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  color: AppTheme.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (_filesExpanded) ...[
                        const SizedBox(height: 8),
                        ...sortedFiles.map((file) {
                          final isSelected = file['id'] == currentState.currentStream?.activeFileId;
                          final fileName = (file['path'] as String).split('/').last;
                          final size = (file['bytes'] as int? ?? 0) / (1024 * 1024 * 1024); // GB

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  ref.read(playerControllerProvider(params).notifier).changeFile(file['id']);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.accent.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.accent.withOpacity(0.6) : Colors.white.withOpacity(0.08),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fileName,
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : AppTheme.textWhite.withOpacity(0.7),
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "${size.toStringAsFixed(2)} GB",
                                              style: TextStyle(color: AppTheme.textMuted.withOpacity(0.5), fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                      const Divider(color: Colors.white10, height: 32),
                    ],

                    // Sources Section
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 12),
                      child: Text(
                        l10n.playerQuality.toUpperCase(),
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                    ...List.generate(currentState.availableStreams.length, (index) {
                      final stream = currentState.availableStreams[index];
                      final isSelected = currentState.currentStream?.candidate.uniqueId == stream.uniqueId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              ref.read(playerControllerProvider(params).notifier).changeSource(stream);
                            },
                            child: Container(
                              padding: EdgeInsets.all(isLandscape ? 12 : 16),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.accent.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppTheme.accent.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: StreamMetadataOverview(stream: stream),
                                      ),
                                      if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 20),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    stream.title,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white.withOpacity(0.9) : AppTheme.textMuted.withOpacity(0.6),
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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

        // Loading Overlay
        if (currentState.isResolving)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.accent),
                    const SizedBox(height: 20),
                    Text(
                      "Resolving Stream...",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Checking debrid cache",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Error Banner
        if (currentState.error != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      currentState.error!,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                    onPressed: () => ref.read(playerControllerProvider(widget.params).notifier).clearError(),
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
