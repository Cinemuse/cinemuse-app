import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';

/// Shows the channel filter sheet as a bottom sheet (mobile) or dialog (desktop).
void showChannelFilterSheet(BuildContext context) {
  final isMobile = MediaQuery.of(context).size.width < 600;

  if (isMobile) {
    AppBottomSheet.show(
      context: context,
      child: const _FilterSheetContent(isMobile: true),
    );
  } else {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: const _FilterSheetContent(isMobile: false),
        ),
      ),
    );
  }
}

class _FilterSheetContent extends ConsumerStatefulWidget {
  final bool isMobile;
  const _FilterSheetContent({required this.isMobile});

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groupsAsync = ref.watch(groupsProvider);

    // Derive sub-providers for the current _selectedGroup locally
    final subProviders = _deriveSubProviders(ref);

    return AppBottomSheet(
      blurSigma: 16,
      backgroundColor: AppTheme.surface.withValues(alpha: 0.85),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      borderRadius: widget.isMobile
          ? const BorderRadius.vertical(top: Radius.circular(24))
          : BorderRadius.circular(20),
      showHandle: widget.isMobile,
      padding: const EdgeInsets.all(24).copyWith(top: widget.isMobile ? 0 : 24),
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
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGroupChips(l10n, groupsAsync),
                    if (subProviders.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSubProviderChips(l10n, subProviders),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildActions(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      children: [
        Text(
          l10n.liveTvFilterChannels,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white60, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildGroupModeToggle(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.liveTvGroupBy,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.all(3),
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
        ),
      ],
    );
  }

  Widget _buildGroupChips(
    AppLocalizations l10n,
    AsyncValue<List<String>> groupsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _groupMode == LiveTvGroupMode.category
              ? l10n.liveTvCategories
              : l10n.liveTvProviders,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        groupsAsync.when(
          data: (groups) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: l10n.liveTvAllChannels,
                isSelected: _selectedGroup == null,
                onTap: () => setState(() {
                  _selectedGroup = null;
                  _selectedSubProvider = null;
                }),
              ),
              ...groups.map(
                (g) => _FilterChip(
                  label: g,
                  isSelected: _selectedGroup == g,
                  onTap: () => setState(() {
                    _selectedGroup = g;
                    _selectedSubProvider = null;
                  }),
                ),
              ),
            ],
          ),
          loading: () => const SizedBox(
            height: 32,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSubProviderChips(
    AppLocalizations l10n,
    List<String> subProviders,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.liveTvSubProvider,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: l10n.liveTvAllChannels,
              isSelected: _selectedSubProvider == null,
              onTap: () => setState(() => _selectedSubProvider = null),
            ),
            ...subProviders.map(
              (s) => _FilterChip(
                label: s,
                isSelected: _selectedSubProvider == s,
                onTap: () => setState(() => _selectedSubProvider = s),
              ),
            ),
          ],
        ),
      ],
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
            ),
            child: Text(l10n.liveTvApplyFilters),
          ),
        ),
      ],
    );
  }

  /// Derive sub-providers for the currently selected group in the local sheet state.
  List<String> _deriveSubProviders(WidgetRef ref) {
    if (_selectedGroup == null) return [];

    final channelsAsync = ref.watch(channelsProvider);
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
                ? AppTheme.accent.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accent.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textMuted,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
