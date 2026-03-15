import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppTheme.accent,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }
}

class SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final CrossAxisAlignment crossAxisAlignment;

  const SettingsCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(24),
    this.margin = const EdgeInsets.only(bottom: 24),
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16), // Increased from 12 for a smoother look
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final String label;
  final String? description;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const SettingsTile({
    super.key,
    required this.label,
    this.description,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          if (leading != null || icon != null) ...[
            Container(
              width: 40,
              height: 40,
              padding: leading != null ? EdgeInsets.zero : const EdgeInsets.all(8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: leading ?? (icon != null ? Icon(icon, size: 20, color: Colors.white70) : null),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 16),
            trailing!,
          ],
          if (onTap != null && trailing == null) ...[
            const SizedBox(width: 16),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
          ],
        ],
      ),
    );

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16), // Increased from 8 to match card
            child: content,
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withOpacity(0.05),
            indent: icon != null ? 52 : 0,
          ),
      ],
    );
  }
}


class SettingsLanguageButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SettingsLanguageButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16), // Standardized to 16
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class SettingsRegionSelector extends StatelessWidget {
  final String? selectedRegion;
  final ValueChanged<String?> onChanged;

  const SettingsRegionSelector({
    super.key,
    required this.selectedRegion,
    required this.onChanged,
  });

  static const regions = {
    'abruzzo': 'Abruzzo',
    'basilicata': 'Basilicata',
    'bolzano': 'Bolzano',
    'calabria': 'Calabria',
    'campania': 'Campania',
    'er': 'Emilia-Romagna',
    'fvg': 'Friuli-Venezia Giulia',
    'lazio': 'Lazio',
    'liguria': 'Liguria',
    'lombardia': 'Lombardia',
    'marche': 'Marche',
    'molise': 'Molise',
    'piemonte': 'Piemonte',
    'puglia': 'Puglia',
    'sardegna': 'Sardegna',
    'sicilia': 'Sicilia',
    'toscana': 'Toscana',
    'trento': 'Trento',
    'umbria': 'Umbria',
    'vda': 'Valle d\'Aosta',
    'veneto': 'Veneto',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SettingsLanguageButton(
          label: l10n.settingsNone,
          isSelected: selectedRegion == null || selectedRegion!.isEmpty,
          onTap: () => onChanged(null),
        ),
        ...regions.entries.map((e) => SettingsLanguageButton(
              label: e.value,
              isSelected: selectedRegion == e.key,
              onTap: () => onChanged(e.key),
            )),
      ],
    );
  }
}

class SettingsDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const SettingsDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              dropdownColor: AppTheme.secondary,
              borderRadius: BorderRadius.circular(16),
              isDense: true,
              alignment: Alignment.center,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textMuted),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
