import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

import 'package:cinemuse_app/features/live_tv/presentation/widgets/playlist_management_sheet.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/save_live_tv_change.dart';

// The switch and the rows show what is selected the same way.
final _selectedFill = AppTheme.accent.withValues(alpha: 0.12);
final _selectedBorder = AppTheme.accent.withValues(alpha: 0.5);

/// Available tabs in the Live TV options bottom sheet.
enum LiveTvSheetTab { categories, playlists }

/// Shows the channel filter and playlist management sheet using the generic bottom sheet.
void showChannelFilterSheet(
  BuildContext context, {
  LiveTvSheetTab initialTab = LiveTvSheetTab.categories,
}) {
  AppBottomSheet.show(
    context: context,
    // No wider than the phone layout, full width below it.
    constraints: const BoxConstraints(maxWidth: Breakpoints.compact),
    child: _FilterSheetContent(initialTab: initialTab),
  );
}

class _FilterSheetContent extends ConsumerStatefulWidget {
  final LiveTvSheetTab initialTab;

  const _FilterSheetContent({this.initialTab = LiveTvSheetTab.categories});

  @override
  ConsumerState<_FilterSheetContent> createState() =>
      _FilterSheetContentState();
}

class _FilterSheetContentState extends ConsumerState<_FilterSheetContent> {
  late LiveTvSheetTab _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categoriesAsync = ref.watch(channelCategoriesProvider);
    final filter = ref.watch(channelFilterProvider);

    return AppBottomSheet(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(l10n),
              const SizedBox(height: 20),
              _buildTabToggle(l10n),
              const SizedBox(height: 16),
              Expanded(
                child: _activeTab == LiveTvSheetTab.categories
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildGroupList(
                          l10n,
                          filter.selectedCategories,
                          categoriesAsync,
                        ),
                      )
                    : const SingleChildScrollView(
                        padding: EdgeInsets.only(bottom: 16),
                        child: PlaylistListSection(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final title = _activeTab == LiveTvSheetTab.categories
        ? l10n.liveTvFilterChannels
        : l10n.liveTvPlaylists;

    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textWhite,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTabToggle(AppLocalizations l10n) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.textWhite.withValues(alpha: 0.05),
        borderRadius: AppTheme.radius12,
        border: Border.all(color: AppTheme.textWhite.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _ModeToggleButton(
            label: l10n.liveTvCategories,
            isSelected: _activeTab == LiveTvSheetTab.categories,
            onTap: () => setState(() {
              _activeTab = LiveTvSheetTab.categories;
            }),
          ),
          const SizedBox(width: 4),
          _ModeToggleButton(
            label: l10n.liveTvPlaylists,
            isSelected: _activeTab == LiveTvSheetTab.playlists,
            onTap: () => setState(() {
              _activeTab = LiveTvSheetTab.playlists;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList(
    AppLocalizations l10n,
    Set<String> selectedCategories,
    AsyncValue<List<String>> categoriesAsync,
  ) {
    return categoriesAsync.when(
      data: (groups) => ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: groups.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FilterListItem(
              label: l10n.liveTvAllChannels,
              isSelected: selectedCategories.isEmpty,
              onTap: () => saveLiveTvChange(
                context,
                ref,
                ref.read(channelFilterProvider.notifier).clear,
              ),
            );
          }

          final g = groups[index - 1];
          final isSelected = selectedCategories.contains(g);

          return _FilterListItem(
            label: g,
            isSelected: isSelected,
            onTap: () => saveLiveTvChange(
              context,
              ref,
              () => ref.read(channelFilterProvider.notifier).toggleCategory(g),
            ),
          );
        },
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // DpadFocusable, not a GestureDetector: a remote must reach the
    // Playlists side (REV-134).
    return Expanded(
      child: DpadFocusable(
        onTap: onTap,
        borderRadius: AppTheme.radiusMd,
        // The gap between the sides is narrower than an outer ring, which
        // would cover the other one.
        isFocusRingInside: true,
        builder: (context, isFocused, isHovered, _) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          // Selected like the category rows below, so it never looks like
          // the hover or the focus.
          decoration: BoxDecoration(
            color: isSelected
                ? _selectedFill
                : isFocused || isHovered
                ? AppTheme.accentHoverBg
                : Colors.transparent,
            borderRadius: AppTheme.radiusMd,
            border: Border.all(
              color: isSelected ? _selectedBorder : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected || isFocused || isHovered
                  ? AppTheme.textWhite
                  : AppTheme.textMuted,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        child: const SizedBox.shrink(),
      ),
    );
  }
}

class _FilterListItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterListItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Its own fill, not an InkWell: the sheet's opaque background would cover
    // the ink.
    return DpadFocusable(
      onTap: onTap,
      borderRadius: AppTheme.radius12,
      // The list clips its sides, which would cut an outer ring.
      isFocusRingInside: true,
      // The arrows already scroll to the row. Its own scrolling would try to
      // show the whole list, which sits in the sheet's scroll, and jump away.
      autoScroll: false,
      builder: (context, isFocused, isHovered, child) {
        final isHighlighted = isFocused || isHovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? isHighlighted
                      ? Color.alphaBlend(_selectedFill, AppTheme.accentHoverBg)
                      : _selectedFill
                : isHighlighted
                ? AppTheme.accentHoverBg
                : AppTheme.textWhite.withValues(alpha: 0.03),
            borderRadius: AppTheme.radius12,
            border: Border.all(
              color: isSelected ? _selectedBorder : Colors.transparent,
            ),
          ),
          child: child,
        );
      },
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.textWhite,
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }
}
