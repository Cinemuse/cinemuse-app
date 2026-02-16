import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CreativeVisionBox extends StatelessWidget {
  final Map<String, dynamic>? details;
  final bool isSeries;

  const CreativeVisionBox({super.key, this.details, this.isSeries = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    final crew = (details?['credits']?['crew'] as List?) ?? [];
    final directors = crew.where((c) => c['job'] == 'Director').toList();
    final writers = crew.where((c) => c['department'] == 'Writing').take(3).toList();
    final creators = (details?['created_by'] as List?) ?? [];

    final allDirectors = [...creators, ...directors];
    // Simple deduplication by name
    final uniqueDirectors = <String, dynamic>{};
    for (var d in allDirectors) {
      uniqueDirectors[d['name']] = d;
    }
    final finalDirectors = uniqueDirectors.values.toList();

    if (finalDirectors.isEmpty && writers.isEmpty) return const SizedBox.shrink();

    return BentoBox(
      title: l10n.detailsCreativeVision,
      icon: Icons.people_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (finalDirectors.isNotEmpty) ...[
            _Label(isSeries ? 'Creators & Directors' : 'Director'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: finalDirectors.map((d) => _PersonLink(name: d['name'])).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (writers.isNotEmpty) ...[
            const _Label('Writers'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: writers.map((w) => _PersonLink(name: w['name'], isMuted: true)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class VerdictBox extends StatelessWidget {
  final Map<String, dynamic>? userReview;
  final List<dynamic> reviews;
  final VoidCallback onShowUserReviewModal;
  final VoidCallback onShowReviewsModal;

  const VerdictBox({
    super.key,
    this.userReview,
    required this.reviews,
    required this.onShowUserReviewModal,
    required this.onShowReviewsModal,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final featuredReview = reviews.isNotEmpty ? reviews[0] : null;

    return BentoBox(
      title: l10n.detailsVerdict,
      icon: Icons.star_outline,
      action: userReview == null
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onShowUserReviewModal,
                child: HoverScale(
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_outline, size: 14, color: AppTheme.accent),
                      SizedBox(width: 4),
                      Text(
                        'RATE',
                        style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (userReview != null)
             const Text('Your review goes here (placeholder)', style: TextStyle(color: AppTheme.textWhite))
          else if (featuredReview != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.accent,
                  child: Text(featuredReview['author']?[0]?.toUpperCase() ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(featuredReview['author'] ?? 'Anonymous', style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13)),
                    const Text('Featured Critic', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '"${featuredReview['content']}"',
              style: GoogleFonts.outfit(color: AppTheme.textWhite.withOpacity(0.8), fontSize: 13, fontStyle: FontStyle.italic),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No transmissions found.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontStyle: FontStyle.italic)),
              ),
            ),
          
          if (reviews.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onShowReviewsModal,
                  child: HoverScale(
                    child: TextButton(
                      onPressed: onShowReviewsModal,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero, // Remove default min size
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Shrink tap target
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppTheme.textWhite.withOpacity(0.1)),
                        ),
                      ),
                      child: Text(l10n.detailsReviewsAll.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FinancesBox extends StatelessWidget {
  final int budget;
  final int revenue;

  const FinancesBox({super.key, required this.budget, required this.revenue});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (budget <= 0 && revenue <= 0) return const SizedBox.shrink();

    final revenuePercentage = budget > 0 ? (revenue / budget) * 0.5 : 0.0;

    return BentoBox(
      title: l10n.detailsFinances,
      icon: Icons.attach_money,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FinanceItem(
            label: l10n.detailsBudget.toUpperCase(),
            value: budget > 0 ? '\$${(budget / 1000000).toStringAsFixed(1)}M' : 'Unknown',
            progress: 0.5,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          _FinanceItem(
            label: l10n.detailsRevenue.toUpperCase(),
            value: revenue > 0 ? '\$${(revenue / 1000000).toStringAsFixed(1)}M' : 'Unknown',
            progress: revenuePercentage.clamp(0.0, 1.0),
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}

class ProductionDNA extends StatelessWidget {
  final List<dynamic> productionCompanies;
  final Function(Map<String, dynamic>) onCompanyClick;

  const ProductionDNA({
    super.key,
    required this.productionCompanies,
    required this.onCompanyClick,
  });

  @override
  Widget build(BuildContext context) {
    if (productionCompanies.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    return BentoBox(
      title: l10n.detailsProductionDNA,
      icon: LucideIcons.dna,
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: productionCompanies.map((pc) {
          final logoPath = pc['logo_path'];
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onCompanyClick({'type': 'company', 'id': pc['id'], 'name': pc['name']}),
              child: logoPath != null
                  ? Image.network(
                      'https://image.tmdb.org/t/p/w200$logoPath',
                      height: 24,
                      color: Colors.white.withOpacity(0.5),
                      colorBlendMode: BlendMode.srcIn,
                    )
                  : Text(
                      pc['name'],
                      style: DesktopTypography.bodySecondary.copyWith(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
    );
  }
}

class _PersonLink extends StatelessWidget {
  final String name;
  final bool isMuted;

  const _PersonLink({required this.name, this.isMuted = false});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Deep search or navigate to person details
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isMuted ? Colors.transparent : AppTheme.textWhite.withOpacity(0.2))),
          ),
          child: Text(
            name,
            style: DesktopTypography.bodySecondary.copyWith(
              color: isMuted ? AppTheme.textMuted : AppTheme.textWhite,
              decoration: isMuted ? TextDecoration.none : TextDecoration.underline,
              decorationColor: AppTheme.textWhite.withOpacity(0.2),
            ),
          ),
        ),
      ),
    );
  }
}

class _FinanceItem extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color color;

  const _FinanceItem({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DesktopTypography.captionMeta.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.firaCode(color: AppTheme.textWhite, fontSize: 20)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.textWhite.withOpacity(0.05),
            valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.8)),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
