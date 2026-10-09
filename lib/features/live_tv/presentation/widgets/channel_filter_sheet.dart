import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';

import 'package:cinemuse_app/features/live_tv/presentation/widgets/playlist_management_sheet.dart';

/// Available tabs in the Live TV options bottom sheet.
enum LiveTvSheetTab { categories, playlists }

/// Shows the channel filter and playlist management sheet using the generic bottom sheet.
void showChannelFilterSheet(
  BuildContext context, {
  LiveTvSheetTab initialTab = LiveTvSheetTab.categories,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final effectiveMaxWidth = width < 640 ? width : 620.0;

  AppBottomSheet.show(
    context: context,
    constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
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

  List<String> _deriveGroups(AsyncValue<List<Channel>> channelsAsync) {
    return channelsAsync.whenOrNull(
          data: (channels) {
            final groups = channels
                .map((ch) => ch.group)
                .where((g) => g != null && g.isNotEmpty)
                .cast<String>()
                .toSet()
                .toList();
            groups.sort();

            if (groups.contains('DTT')) {
              groups.remove('DTT');
              groups.insert(0, 'DTT');
            }
            return groups;
          },
        ) ??
        [];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final channelsAsync = ref.watch(channelsProvider);
    final filter = ref.watch(channelFilterProvider);
    final groups = _deriveGroups(channelsAsync);

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
                          groups,
                          filter.effectiveCategories,
                          channelsAsync,
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
        : l10n.liveTvCustomPlaylists;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20, color: Colors.white54),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildTabToggle(AppLocalizations l10n) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
    List<String> groups,
    Set<String> selectedCategories,
    AsyncValue<List<Channel>> channelsAsync,
  ) {
    return channelsAsync.when(
      data: (_) => ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: groups.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FilterListItem(
              label: l10n.liveTvAllChannels,
              isSelected: selectedCategories.isEmpty,
              onTap: () => ref.read(channelFilterProvider.notifier).selectAll(),
            );
          }

          final g = groups[index - 1];
          final isSelected = selectedCategories.contains(g);

          return _FilterListItem(
            label: g,
            isSelected: isSelected,
            onTap: () =>
                ref.read(channelFilterProvider.notifier).toggleCategory(g),
          );
        },
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.accent : Colors.white,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
