import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_guide.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_source.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_sources_notifier.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_refresh_notifier.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/add_remote_playlist_dialog.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/live_tv_source_tile.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/save_live_tv_change.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';

// ---------------------------------------------------------------------------
// Playlist and guide lists, shown in Settings and in the Live TV options sheet
// ---------------------------------------------------------------------------

class PlaylistListSection extends ConsumerWidget {
  const PlaylistListSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ListHeader(
          icon: LucideIcons.listVideo,
          title: l10n.liveTvPlaylistsTitle,
        ),
        const SizedBox(height: 12),
        _SourceList<LiveTvPlaylist>(
          sources: ref.watch(playlistsProvider),
          failures: ref.watch(playlistFailuresProvider),
          notifier: () => ref.read(playlistsProvider.notifier),
          builtInSubtitle: l10n.liveTvCinemuseChannels,
          badgeLabel: (playlist) => _playlistBadge(playlist, l10n),
          fileExtensions: const ['m3u', 'm3u8', 'json'],
          isGuide: false,
          fromLink: (name, url, type) => LiveTvPlaylist(
            name: name,
            urlOrPath: url,
            isLocal: false,
            type: type,
          ),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: Colors.white10),
        const SizedBox(height: 20),
        _ListHeader(icon: LucideIcons.calendar, title: l10n.liveTvEpgSection),
        const SizedBox(height: 12),
        _SourceList<LiveTvGuide>(
          sources: ref.watch(guidesProvider),
          failures: ref.watch(guideFailuresProvider),
          notifier: () => ref.read(guidesProvider.notifier),
          builtInSubtitle: l10n.liveTvCinemuseGuide,
          badgeLabel: (guide) => _guideBadge(guide, l10n),
          fileExtensions: const ['xml', 'gz', 'json'],
          isGuide: true,
          fromLink: (name, url, _) =>
              LiveTvGuide(name: name, urlOrPath: url, isLocal: false),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: Colors.white10),
        const SizedBox(height: 20),
        const _RefreshButton(),
      ],
    );
  }

  static String _playlistBadge(LiveTvPlaylist playlist, AppLocalizations l10n) {
    if (playlist.isBuiltIn) return l10n.liveTvTypeBuiltIn;
    final isJson = playlist.type == PlaylistType.json;
    if (playlist.isLocal) {
      return isJson ? l10n.liveTvTypeJsonFile : l10n.liveTvTypeM3uFile;
    }
    return isJson ? l10n.liveTvTypeJsonUrl : l10n.liveTvTypeM3uUrl;
  }

  static String _guideBadge(LiveTvGuide guide, AppLocalizations l10n) {
    if (guide.isBuiltIn) return l10n.liveTvTypeBuiltIn;
    final isJson = guide.looksLikeJson;
    if (guide.isLocal) {
      return isJson ? l10n.liveTvTypeJsonFile : l10n.liveTvTypeXmltvFile;
    }
    return isJson ? l10n.liveTvTypeJsonUrl : l10n.liveTvTypeXmltvUrl;
  }
}

// ---------------------------------------------------------------------------
// One list (playlists or guides): its rows, then "Add URL" and "Add File"
// ---------------------------------------------------------------------------

class _SourceList<T extends LiveTvSource> extends ConsumerWidget {
  final List<T> sources;

  /// The sources that failed on their last load, by id.
  final Map<String, LiveTvSourceFailure> failures;
  final LiveTvSourcesNotifier<T> Function() notifier;

  /// Shown under the Cinemuse entry's name.
  final String builtInSubtitle;
  final String Function(T source) badgeLabel;
  final List<String> fileExtensions;
  final bool isGuide;
  final T Function(String name, String url, PlaylistType type) fromLink;

  const _SourceList({
    required this.sources,
    required this.failures,
    required this.notifier,
    required this.builtInSubtitle,
    required this.badgeLabel,
    required this.fileExtensions,
    required this.isGuide,
    required this.fromLink,
  });

  /// Runs [change] and shows "Error saving" if it fails.
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(LiveTvSourcesNotifier<T> sources) change,
  ) => saveLiveTvChange(context, ref, () => change(notifier()));

  /// Removes [source] at once, with Undo; its files go once Undo is gone.
  Future<void> _remove(BuildContext context, WidgetRef ref, T source) {
    final undone = AppSnackBar.showUndo(
      context,
      message: AppLocalizations.of(context)!.liveTvSourceRemoved(source.name),
    );
    return _save(context, ref, (s) => s.remove(source.id, undone: undone));
  }

  /// What the row says about [failure].
  String _problemText(
    LiveTvSourceFailure failure,
    AppLocalizations l10n,
    GlobalErrorMapper errorMapper,
  ) {
    final reason = switch (failure.failure) {
      NotFoundFailure() => l10n.liveTvFileNotFound,
      ValidationFailure() =>
        isGuide ? l10n.liveTvNoProgrammesInIt : l10n.liveTvNoChannelsInIt,
      ServerFailure(:final statusCode?) => l10n.errorServerStatus(
        '$statusCode',
      ),
      final other => errorMapper.map(other).message,
    };
    if (!failure.usesSavedCopy) return l10n.liveTvCouldNotLoad(reason);
    return isGuide
        ? l10n.liveTvSavedGuideShown(reason)
        : l10n.liveTvSavedChannelsShown(reason);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final errorMapper = ref.watch(errorMapperProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Never empty once loaded: the Cinemuse entry is always there.
        for (final source in sources)
          LiveTvSourceTile(
            source: source,
            subtitle: source.isBuiltIn
                ? builtInSubtitle
                : LiveTvSource.displaySourceOf(source),
            badgeLabel: badgeLabel(source),
            problem: switch (failures[source.id]) {
              final failure? => _problemText(failure, l10n, errorMapper),
              null => null,
            },
            isProblemWarning: failures[source.id]?.usesSavedCopy ?? false,
            onToggle: () =>
                _save(context, ref, (s) => s.toggleEnabled(source.id)),
            onRemove: () => _remove(context, ref, source),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _showAddLinkDialog(context, ref),
                icon: const Icon(LucideIcons.link, size: 16),
                label: Text(l10n.liveTvAddUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _pickAndAddLocalFile(context, ref),
                icon: const Icon(LucideIcons.folderInput, size: 16),
                label: Text(l10n.liveTvAddFile),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddLinkDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AddRemotePlaylistDialog(
        isGuide: isGuide,
        onAdd: (name, url, type) => saveLiveTvChangeError(
          context,
          ref,
          () => notifier().add(fromLink(name, url, type)),
        ),
      ),
    );
  }

  Future<void> _pickAndAddLocalFile(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: fileExtensions,
    );

    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;
    await _save(context, ref, (s) => s.addLocalFile(File(path)));
  }
}

// ---------------------------------------------------------------------------
// A list's title, and "Refresh" for both lists
// ---------------------------------------------------------------------------

class _ListHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ListHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RefreshButton extends ConsumerWidget {
  const _RefreshButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isRefreshing = ref.watch(liveTvRefreshProvider);
    return FilledButton.tonalIcon(
      onPressed: isRefreshing ? null : () => _refresh(context, ref, l10n),
      icon: const Icon(LucideIcons.refreshCw, size: 16),
      label: Text(l10n.liveTvRefreshAll),
    );
  }

  Future<void> _refresh(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final failed = await ref.read(liveTvRefreshProvider.notifier).refresh();
    if (!context.mounted) return;
    final failedMessage = liveTvFailedSourcesMessage(failed, l10n);
    if (failedMessage != null) {
      AppSnackBar.show(context, message: failedMessage, isError: true);
    } else {
      AppSnackBar.show(
        context,
        message: l10n.liveTvRefreshed,
        duration: const Duration(seconds: 2),
      );
    }
  }
}

/// "Couldn't load: My IPTV (playlist), Cinemuse IPTV (EPG)", or `null` when
/// nothing failed. Shown on opening Live TV and after Refresh.
String? liveTvFailedSourcesMessage(
  FailedLiveTvSources failed,
  AppLocalizations l10n,
) {
  final names = [
    for (final name in failed.playlists) l10n.liveTvFailedPlaylist(name),
    for (final name in failed.guides) l10n.liveTvFailedGuide(name),
  ];
  return names.isEmpty ? null : l10n.liveTvCouldNotLoad(names.join(', '));
}
