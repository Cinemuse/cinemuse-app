import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:intl/intl.dart';

class WatchLogsSheet extends ConsumerWidget {
  final int tmdbId;
  final String title;
  final int? season;
  final int? episode;

  const WatchLogsSheet({
    super.key,
    required this.tmdbId,
    required this.title,
    this.season,
    this.episode,
  });

  static Future<void> show(BuildContext context, int tmdbId, String title, {int? season, int? episode}) {
    return AppBottomSheet.show(
      context: context,
      constraints: const BoxConstraints(maxWidth: 400),
      child: WatchLogsSheet(tmdbId: tmdbId, title: title, season: season, episode: episode),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine which stream to watch
    final AsyncValue<List<Map<String, dynamic>>> logsAsync;
    if (season != null && episode != null) {
      logsAsync = ref.watch(seriesWatchLogsProvider(tmdbId));
    } else {
      logsAsync = ref.watch(movieWatchLogsProvider(tmdbId));
    }

    return AppBottomSheet(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppTheme.accent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Watch History Logs',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          logsAsync.when(
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
            ),
            error: (err, _) => const SizedBox(
              height: 100,
              child: Center(child: Text('Error loading history', style: TextStyle(color: AppTheme.textMuted))),
            ),
            data: (logs) {
              // Filter logs for episode if needed
              var filteredLogs = logs;
              if (season != null && episode != null) {
                filteredLogs = logs.where((l) => l['season'] == season && l['episode'] == episode).toList();
              }

              if (filteredLogs.isEmpty) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No watch history found.', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ),
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    final loggedAtStr = log['logged_at'] as String?;
                    final date = loggedAtStr != null ? DateTime.tryParse(loggedAtStr) : null;
                    final formattedDate = date != null
                        ? DateFormat.yMMMd(Localizations.localeOf(context).languageCode).add_jm().format(date)
                        : 'Unknown date';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.circle, size: 8, color: AppTheme.accent),
                        ],
                      ),
                      title: Text(formattedDate, style: const TextStyle(color: Colors.white)),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
