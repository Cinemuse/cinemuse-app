import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

class VideoCard extends StatelessWidget {
  final String youtubeKey;
  final String name;
  final VoidCallback onTap;

  const VideoCard({
    super.key,
    required this.youtubeKey,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onTap: onTap,
      scale: 1.04,
      borderRadius: BorderRadius.circular(16),
      builder: (context, isFocused, isHovered, child) {
        return SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isFocused ? Colors.white : Colors.transparent,
                      width: 2.0,
                    ),
                    boxShadow:
                        isFocused ? AppTheme.shadowCard : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CachedNetworkImage(
                          imageUrl:
                              'https://img.youtube.com/vi/$youtubeKey/mqdefault.jpg',
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: Colors.white10),
                          errorWidget: (context, url, error) =>
                              Container(color: Colors.white10),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFocused ? Colors.white24 : Colors.black45,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isFocused ? Colors.white : Colors.white30,
                            ),
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: isFocused ? 28 : 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  name,
                  maxLines: 2,
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  style: DesktopTypography.bodySecondary.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isFocused ? Colors.white : AppTheme.textWhite,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
