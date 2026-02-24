import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_toggle.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_input.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _activeCategory = 'identity';
  bool _showMobileContent = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final userSettings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final categories = [
      {'id': 'identity', 'label': l10n.settingsIdentity, 'icon': Icons.security},
      {'id': 'customization', 'label': l10n.settingsCustomization, 'icon': Icons.smartphone},
      {'id': 'integrations', 'label': l10n.settingsIntegrations, 'icon': Icons.link},
      {'id': 'data', 'label': l10n.settingsData, 'icon': Icons.storage},
      {'id': 'import', 'label': l10n.settingsImport, 'icon': Icons.download},
    ];

    Widget buildSidebar() {
      return Container(
        width: isMobile ? double.infinity : 320,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: const Border(right: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.settingsTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isActive = _activeCategory == category['id'];
                  return Material(
                    color: isActive ? Colors.white.withOpacity(0.05) : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _activeCategory = category['id'] as String;
                          if (isMobile) _showMobileContent = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          border: isActive
                              ? const Border(right: BorderSide(color: AppTheme.accent, width: 2))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              category['icon'] as IconData,
                              size: 20,
                              color: isActive ? Colors.white : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              category['label'] as String,
                              style: TextStyle(
                                color: isActive ? Colors.white : AppTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isMobile) ...[
                              const Spacer(),
                              Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    Widget buildContent() {
      // Identity Category
      if (_activeCategory == 'identity') {
        return ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Text(l10n.settingsIdentity, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(l10n.settingsIdentityDesc, style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  SettingInput(
                    label: l10n.settingsDisplayName,
                    description: l10n.settingsDisplayNameDesc,
                    value: userSettings.displayName,
                    placeholder: l10n.settingsEnterName,
                    onSave: (val) => settingsNotifier.updateSettings({'displayName': val}),
                  ),
                ],
              ),
            ),
          ],
        );
      }
      
      // Integrations Category
      if (_activeCategory == 'integrations') {
        return ListView(
          padding: const EdgeInsets.all(32),
          children: [
             Text(l10n.settingsIntegrations, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(l10n.settingsIntegrationsDesc, style: TextStyle(color: AppTheme.textMuted)),
             const SizedBox(height: 32),
             Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("REAL-DEBRID", style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 16),
                  SettingToggle(
                    label: l10n.settingsEnableRealDebrid, 
                    description: l10n.settingsEnableRealDebridDesc,
                    value: userSettings.enableRealDebrid, 
                    onChanged: (val) => settingsNotifier.updateSettings({'enableRealDebrid': val}),
                  ),
                  SettingInput(
                    label: l10n.settingsRealDebridKey, 
                    value: userSettings.realDebridKey, 
                    onSave: (val) => settingsNotifier.updateSettings({'realDebridKey': val})
                  ),
                ],
              ),
             ),
          ],
        );
      }

      // Customization Category
       if (_activeCategory == 'customization') {
        return ListView(
          padding: const EdgeInsets.all(32),
          children: [
             Text(l10n.settingsCustomization, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(l10n.settingsCustomizationDesc, style: TextStyle(color: AppTheme.textMuted)),
             const SizedBox(height: 32),
             
             // Language
             Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(l10n.settingsLanguage.toUpperCase(), style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                   const SizedBox(height: 24),
                   
                   Text(l10n.settingsAppLanguage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16)),
                   const SizedBox(height: 4),
                   Text(l10n.settingsAppLanguageDesc, style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                   const SizedBox(height: 12),
                   // Mock Buttons for App Language
                   Row(
                     children: [
                       _LanguageButton(
                         label: l10n.settingsEnglish, 
                         isSelected: userSettings.appLanguage == 'en',
                         onTap: () => settingsNotifier.updateSettings({'appLanguage': 'en'}),
                       ),
                       const SizedBox(width: 8),
                         _LanguageButton(
                         label: l10n.settingsItalian, 
                         isSelected: userSettings.appLanguage == 'it', 
                         onTap: () => settingsNotifier.updateSettings({'appLanguage': 'it'}),
                       ),
                     ],
                   ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 24),

                   Text(l10n.settingsAudioLanguage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16)),
                   const SizedBox(height: 4),
                   Text(l10n.settingsAudioLanguageDesc, style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                   const SizedBox(height: 12),
                    Row(
                     children: [
                       _LanguageButton(
                         label: l10n.settingsEnglish, 
                         isSelected: userSettings.playerLanguage == 'en', 
                         onTap: () => settingsNotifier.updateSettings({'playerLanguage': 'en'}),
                       ),
                       const SizedBox(width: 8),
                         _LanguageButton(
                         label: l10n.settingsItalian, 
                         isSelected: userSettings.playerLanguage == 'it', 
                         onTap: () => settingsNotifier.updateSettings({'playerLanguage': 'it'}),
                       ),
                     ],
                   ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 24),

                   Text(l10n.settingsLiveTvRegion.toUpperCase(), style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                   const SizedBox(height: 4),
                   Text(l10n.settingsLiveTvRegionDesc, style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                   const SizedBox(height: 16),
                   
                   _RegionSelector(
                     selectedRegion: userSettings.liveTvRegion,
                     onChanged: (region) => settingsNotifier.updateSettings({'liveTvRegion': region}),
                   ),
                ],
              ),
             ),

            // Player Colors
             Container(
              padding: const EdgeInsets.all(24),
               margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(l10n.settingsPlayer.toUpperCase(), style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                   const SizedBox(height: 16),
                    SettingInput(
                    label: l10n.settingsPrimaryColor, 
                    value: userSettings.playerPrimaryColor, 
                    placeholder: "B20710",
                    onSave: (val) => settingsNotifier.updateSettings({'playerPrimaryColor': val})
                  ),
                   SettingInput(
                    label: l10n.settingsSecondaryColor, 
                    value: userSettings.playerSecondaryColor, 
                     placeholder: "170000",
                    onSave: (val) => settingsNotifier.updateSettings({'playerSecondaryColor': val})
                  ),
                 ],
              ),
             ),

              // Other
             Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(l10n.settingsOther.toUpperCase(), style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                   const SizedBox(height: 16),
                   SettingToggle(
                    label: l10n.settingsShowDebugPanel, 
                    description: l10n.settingsShowDebugPanelDesc,
                    value: userSettings.showDebugPanel, 
                    onChanged: (val) => settingsNotifier.updateSettings({'showDebugPanel': val}),
                  ),
                   SettingToggle(
                    label: l10n.settingsSmartSearch, 
                    description: l10n.settingsSmartSearchDesc,
                    value: userSettings.smartSearchFilter, 
                    onChanged: (val) => settingsNotifier.updateSettings({'smartSearchFilter': val}),
                  ),
                 ],
              ),
             ),
          ],
        );
      }

      // Data Category
      if (_activeCategory == 'data') {
        return ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Text(l10n.settingsData, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(l10n.settingsDataDesc, style: TextStyle(color: AppTheme.textMuted)),
             const SizedBox(height: 32),
             Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _DataRow(label: l10n.settingsTotalDocSize, value: "0 B", description: l10n.settingsTotalDocSizeDesc),
                  const Divider(color: Colors.white10, height: 32),
                   _DataRow(label: l10n.settingsUserProfile, value: "0 B"),
                   _DataRow(label: l10n.settingsWatchedMovies, value: "0 B"),
                   _DataRow(label: l10n.settingsWatchedSeries, value: "0 B"),
                ],
              ),
             ),
          ],
        );
      }

      // Import Category
      if (_activeCategory == 'import') {
        return ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Text(l10n.settingsImport, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(l10n.settingsImportDesc, style: TextStyle(color: AppTheme.textMuted)),
             const SizedBox(height: 32),
             Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 16),
                    const Text("No services available for import", style: TextStyle(color: AppTheme.textMuted)),
                  ],
                ),
              ),
             ),
          ],
        );
      }

      // Default fallback
      return Center(child: Text("Category $_activeCategory not implemented yet", style: const TextStyle(color: Colors.white)));
    }

    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: isMobile 
        ? AppBar(
            backgroundColor: AppTheme.surface,
            title: Text(l10n.settingsTitle),
            leading: _showMobileContent 
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _showMobileContent = false),
                )
              : const BackButton(), // Default back closes settings
          )
        : AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: Colors.white),
        ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0), // Full width on mobile
          child: isMobile 
            ? (_showMobileContent ? buildContent() : buildSidebar())
            : Container(
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    buildSidebar(),
                    Expanded(
                      child: Container(
                        color: AppTheme.surface.withOpacity(0.5),
                        child: buildContent(),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final String? description;

  const _DataRow({required this.label, required this.value, this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                if (description != null) Text(description!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Text(value, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageButton({
    required this.label, 
    required this.isSelected, 
    required this.onTap
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

class _RegionSelector extends StatelessWidget {
  final String? selectedRegion;
  final ValueChanged<String?> onChanged;

  const _RegionSelector({
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
        _LanguageButton(
          label: l10n.settingsNone,
          isSelected: selectedRegion == null || selectedRegion!.isEmpty,
          onTap: () => onChanged(null),
        ),
        ...regions.entries.map((e) => _LanguageButton(
          label: e.value,
          isSelected: selectedRegion == e.key,
          onTap: () => onChanged(e.key),
        )),
      ],
    );
  }
}
