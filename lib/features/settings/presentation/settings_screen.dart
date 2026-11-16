import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_category.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsCategory _activeCategory = SettingsCategory.identity;
  bool _showMobileContent = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // The width Settings really gets, not the window's (REV-20): below
    // `medium` the 320 px sidebar leaves no room for the content.
    builder: (context, constraints) => _buildLayout(
      context,
      isMobile: constraints.maxWidth < Breakpoints.medium,
    ),
  );

  Widget _buildLayout(BuildContext context, {required bool isMobile}) {
    final l10n = AppLocalizations.of(context)!;
    final hasUpdate = ref.watch(hasUpdateProvider);

    Widget buildSidebar() {
      return Container(
        width: isMobile ? double.infinity : 320,
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.8),
          border: const Border(right: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: isMobile ? 16.0 : 24.0,
                bottom: 16.0,
              ),
              child: Row(
                children: [
                  AppBackButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 16),
                  Text(
                    l10n.settingsTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final category in SettingsCategory.values)
                    _CategoryRow(
                      category: category,
                      isHighlighted: _activeCategory == category && !isMobile,
                      isMobile: isMobile,
                      showsDot:
                          hasUpdate && category == SettingsCategory.infoUpdates,
                      onTap: () => setState(() {
                        _activeCategory = category;
                        if (isMobile) _showMobileContent = true;
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final contentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          Padding(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 16.0,
              bottom: 16.0,
            ),
            child: Row(
              children: [
                AppBackButton(
                  onTap: () => setState(() => _showMobileContent = false),
                ),
                const SizedBox(width: 16),
                // "Personalizzazione" is a few pixels too wide for a
                // narrow phone: it shrinks a little instead.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _activeCategory.label(l10n),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            // A scroll of its own for each page: a page opens at its top,
            // not as far down as the one left.
            key: ValueKey(_activeCategory),
            padding: EdgeInsets.only(
              left: isMobile ? 16 : 32,
              right: isMobile ? 16 : 32,
              bottom: isMobile ? 16 : 32,
              top: isMobile ? 0 : 32,
            ),
            children: [_activeCategory.content],
          ),
        ),
      ],
    );

    final isShowingMobileContent = isMobile && _showMobileContent;

    // Narrow layout: Back first returns to the category list (REV-86).
    return PopScope(
      canPop: !isShowingMobileContent,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _showMobileContent = false);
      },
      child: Scaffold(
        backgroundColor: AppTheme.primary,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: isMobile
                ? (_showMobileContent
                      ? Container(
                          color: AppTheme.surface.withValues(alpha: 0.8),
                          child: contentWidget,
                        )
                      : buildSidebar())
                : Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.01),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        buildSidebar(),
                        Expanded(
                          child: Container(
                            color: AppTheme.surface.withValues(alpha: 0.5),
                            child: contentWidget,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final SettingsCategory category;
  final bool isHighlighted;
  final bool isMobile;

  /// A new version is out (on Info & updates).
  final bool showsDot;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.category,
    required this.isHighlighted,
    required this.isMobile,
    required this.showsDot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isHighlighted ? Colors.white : AppTheme.textMuted;
    // Rows sit edge to edge: the ring goes on the row's edge.
    return FocusRingFollower(
      borderRadius: BorderRadius.zero,
      isInside: true,
      child: Material(
        color: isHighlighted ? AppTheme.accentSelectedBg : Colors.transparent,
        child: InkWell(
          mouseCursor: AppTheme.clickCursor,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: isHighlighted
                  ? const Border(
                      right: BorderSide(color: AppTheme.accent, width: 2),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Badge(
                  isLabelVisible: showsDot,
                  backgroundColor: AppTheme.accent,
                  smallSize: 8,
                  child: Icon(category.icon, size: 20, color: color),
                ),
                const SizedBox(width: 16),
                Text(
                  category.label(AppLocalizations.of(context)!),
                  style: TextStyle(
                    color: color,
                    fontWeight: isHighlighted
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
                if (isMobile) ...[
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
