import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/explore/application/explore_providers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/premium_hover_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'filter_section_label.dart';

/// "Watch providers": the main streaming services in the region, as logos.
class WatchProviderFilterSection extends ConsumerWidget {
  const WatchProviderFilterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final picked = ref.watch(
      exploreFiltersProvider.select((f) => f.watchProviders),
    );
    final providersAsync = ref.watch(watchProvidersListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionLabel(l10n.searchWatchProviders),
        const SizedBox(height: 12),
        providersAsync.when(
          data: (providers) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in providers)
                _ProviderLogo(
                  name: p['provider_name'] ?? '',
                  logoUrl: TmdbImageHelper.logoUrl(p['logo_path']) ?? '',
                  isSelected: picked.contains(p['provider_id']),
                  onTap: () => ref
                      .read(exploreFiltersProvider.notifier)
                      .toggleWatchProvider(p['provider_id'] as int),
                ),
            ],
          ),
          loading: () => const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  final String name;
  final String logoUrl;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProviderLogo({
    required this.name,
    required this.logoUrl,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onTap: onTap,
      scale: 1.15,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isSelected
                  ? AppTheme.textWhite.withValues(alpha: 0.05)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? AppTheme.accent
                    : AppTheme.textWhite.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 6),
          PremiumHoverText(
            text: name,
            width: 60,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
