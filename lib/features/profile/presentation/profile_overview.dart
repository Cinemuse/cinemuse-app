import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/stats_display.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/agenda_widget.dart';
import 'package:cinemuse_app/shared/widgets/horizontal_media_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ProfileOverview extends ConsumerWidget {
  const ProfileOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(watchHistoryStreamProvider);
    final history = historyAsync.valueOrNull ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppTheme.getResponsiveHorizontalPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats
          const StatsDisplay(),
          const SizedBox(height: 32),

          // Recent Movies Container
          _RecentMediaContainer(
            title: 'RECENT MOVIES',
            icon: LucideIcons.film,
            items: history
                    .where((h) => h.mediaType == MediaKind.movie)
                    .take(10)
                    .toList(),
          ),

          const SizedBox(height: 24),

          // Recent Series Container
          _RecentMediaContainer(
            title: 'RECENT SERIES',
            icon: LucideIcons.tv,
            items: history
                    .where((h) => h.mediaType == MediaKind.tv)
                    .take(10)
                    .toList(),
          ),
          
          const SizedBox(height: 32),

          // Agenda
          const AgendaWidget(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _RecentMediaContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<WatchHistory> items;

  const _RecentMediaContainer({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 16),
          
          // Content
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Text(
                'No recently watched items',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            // We use HorizontalMediaList with Home-screen dimensions (Height 340, Width 200)
            HorizontalMediaList(
              items: items.map((h) => h.media!).where((m) => m != null).cast<MediaItem>().toList(),
              height: 340,
              itemWidth: 200,
              padding: EdgeInsets.zero, // Container handles padding
            ),
        ],
      ),
    );
  }
}

