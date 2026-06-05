import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';

/// Shows the channel filter sheet using the generic bottom sheet.
void showChannelFilterSheet(BuildContext context) {
  AppBottomSheet.show(
    context: context,
    constraints: const BoxConstraints(maxWidth: 400),
    child: const _FilterSheetContent(),
  );
}

class _FilterSheetContent extends ConsumerStatefulWidget {
  const _FilterSheetContent();

  @override
  ConsumerState<_FilterSheetContent> createState() =>
      _FilterSheetContentState();
}

class _FilterSheetContentState extends ConsumerState<_FilterSheetContent> {
  late LiveTvGroupMode _groupMode;
  String? _selectedGroup;
  String? _selectedSubProvider;

  @override
  void initState() {
    super.initState();
    final current = ref.read(channelFilterProvider);
    _groupMode = current.groupMode;
    _selectedGroup = current.selectedGroup;
    _selectedSubProvider = current.selectedSubProvider;
  }

  void _apply() {
    ref.read(channelFilterProvider.notifier).state = ChannelFilter(
      groupMode: _groupMode,
      selectedGroup: _selectedGroup,
      selectedSubProvider: _selectedSubProvider,
    );
    Navigator.of(context).pop();
  }

  void _clear() {
    ref.read(channelFilterProvider.notifier).state = const ChannelFilter();
    Navigator.of(context).pop();
  }

  List<String> _deriveGroups(AsyncValue<List<Channel>> channelsAsync) {
    return channelsAsync.whenOrNull(
      data: (channels) {
        final groups = channels
            .map((ch) => _groupMode == LiveTvGroupMode.category ? ch.group : ch.provider)
            .where((g) => g != null && g.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();
        groups.sort();

        if (_groupMode == LiveTvGroupMode.category && groups.contains('DTT')) {
          groups.remove('DTT');
          groups.insert(0, 'DTT');
        }
        return groups;
      },
    ) ?? [];
  }

  List<String> _deriveSubProviders(AsyncValue<List<Channel>> channelsAsync) {
    if (_selectedGroup == null) return [];

    return channelsAsync.whenOrNull(
          data: (channels) {
            final inGroup = channels.where((ch) {
              final chGroup = _groupMode == LiveTvGroupMode.category
                  ? ch.group
                  : ch.provider;
              return chGroup == _selectedGroup;
            });

            final subs = inGroup
                .map((ch) => ch.subProvider)
                .where((s) => s != null && s.isNotEmpty)
                .cast<String>()
                .toSet()
                .toList();
            subs.sort();
            return subs;
          },
        ) ??
        [];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final channelsAsync = ref.watch(channelsProvider);

    final groups = _deriveGroups(channelsAsync);
    final subProviders = _deriveSubProviders(channelsAsync);

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
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(l10n),
              const SizedBox(height: 24),
              _buildGroupModeToggle(l10n),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildGroupList(l10n, groups, subProviders, channelsAsync),
                ),
              ),
              _buildActions(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Text(
      l10n.liveTvFilterChannels,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildGroupModeToggle(AppLocalizations l10n) {
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
            isSelected: _groupMode == LiveTvGroupMode.category,
            onTap: () => setState(() {
              _groupMode = LiveTvGroupMode.category;
              _selectedGroup = null;
              _selectedSubProvider = null;
            }),
          ),
          _ModeToggleButton(
            label: l10n.liveTvProviders,
            isSelected: _groupMode == LiveTvGroupMode.provider,
            onTap: () => setState(() {
              _groupMode = LiveTvGroupMode.provider;
              _selectedGroup = null;
              _selectedSubProvider = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList(
    AppLocalizations l10n,
    List<String> groups,
    List<String> subProviders,
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
              isSelected: _selectedGroup == null,
              onTap: () => setState(() {
                _selectedGroup = null;
                _selectedSubProvider = null;
              }),
            );
          }

          final g = groups[index - 1];
          final isSelected = _selectedGroup == g;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterListItem(
                label: g,
                isSelected: isSelected,
                onTap: () => setState(() {
                  _selectedGroup = g;
                  _selectedSubProvider = null;
                }),
              ),
              if (isSelected && subProviders.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 16),
                  child: Column(
                    children: [
                      _FilterListItem(
                        label: l10n.liveTvAllChannels,
                        isSelected: _selectedSubProvider == null,
                        isSubItem: true,
                        onTap: () => setState(() {
                          _selectedSubProvider = null;
                        }),
                      ),
                      const SizedBox(height: 6),
                      ...subProviders.map((s) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _FilterListItem(
                            label: s,
                            isSelected: _selectedSubProvider == s,
                            isSubItem: true,
                            onTap: () => setState(() {
                              _selectedSubProvider = s;
                            }),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildActions(AppLocalizations l10n) {
    final hasFilter = _selectedGroup != null;

    return Row(
      children: [
        if (hasFilter)
          Expanded(
            child: OutlinedButton(
              onPressed: _clear,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textMuted,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(l10n.liveTvClearFilters),
            ),
          ),
        if (hasFilter) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _apply,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            child: Text(
              l10n.liveTvApplyFilters,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
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
  final bool isSubItem;

  const _FilterListItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isSubItem = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isSubItem ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.accent
                      : (isSubItem ? Colors.white70 : Colors.white),
                  fontSize: isSubItem ? 14 : 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
