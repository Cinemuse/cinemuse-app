import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/shared/widgets/horizontal_media_list.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';

class MediaRow extends ConsumerWidget {
  final String title;
  final AsyncValue<List<Map<String, dynamic>>> asyncData;
  final bool skipFirst;

  const MediaRow({
    super.key, 
    required this.title, 
    required this.asyncData, 
    this.skipFirst = false
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.getResponsiveHorizontalPadding(context)
          ),
          child: Row(
            children: [
              Text(
                title, 
                style: GoogleFonts.outfit(
                  color: Colors.white, 
                  fontSize: 20, 
                  fontWeight: FontWeight.bold
                )
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 340, // Height for card + text
          child: asyncData.when(
            data: (data) {
              final list = skipFirst && data.isNotEmpty ? data.skip(1).toList() : data;
              
              if (list.isEmpty) {
                 return const Center(child: Text("No content available", style: TextStyle(color: Colors.white54)));
              }

              // Map to MediaItem for shared widget
              final mediaItems = list.map((item) {
                return MediaItem(
                  tmdbId: item['id'] as int,
                  mediaType: (item['media_type'] == 'tv' || item['first_air_date'] != null || item['name'] != null) 
                      ? MediaKind.tv 
                      : MediaKind.movie,
                  titleEn: item['title'] ?? item['name'] ?? 'Unknown',
                  posterPath: item['poster_path'],
                  backdropPath: item['backdrop_path'],
                  releaseDate: DateTime.tryParse(item['release_date'] ?? item['first_air_date'] ?? ''),
                  voteAverage: (item['vote_average'] as num?)?.toDouble(),
                  updatedAt: item['updated_at'] != null ? DateTime.parse(item['updated_at']) : DateTime(2000), // Stable dummy
                );
              }).toList();

              return HorizontalMediaList(
                items: mediaItems,
                height: 340,
                itemWidth: 200,
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.getResponsiveHorizontalPadding(context)
                ),
              );
            },
             loading: () => const Center(child: CircularProgressIndicator()),
             error: (e, s) {
               final mapped = ref.read(errorMapperProvider).map(e);
               return ErrorCard(
                 message: mapped.message,
                 hint: mapped.hint,
                 type: mapped.type,
               );
             },
          ),
        ),
      ],
    );
  }
}
