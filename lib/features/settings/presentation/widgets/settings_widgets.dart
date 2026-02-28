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
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ],
        const SizedBox(height: 32),
        ...children,
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      ),
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
          borderRadius: BorderRadius.circular(8),
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
