import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_categories.dart';

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

    final categories = [
      {'id': 'identity', 'label': l10n.settingsIdentity, 'icon': Icons.security},
      {'id': 'customization', 'label': l10n.settingsCustomization, 'icon': Icons.smartphone},
      {'id': 'livetv', 'label': l10n.settingsLiveTv, 'icon': Icons.live_tv},
      {'id': 'integrations', 'label': l10n.settingsIntegrations, 'icon': Icons.link},
      {'id': 'import', 'label': l10n.settingsImport, 'icon': Icons.download},
    ];

    Widget buildSidebar() {
      return Container(
        width: isMobile ? double.infinity : 320,
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.8),
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
                              const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
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
      switch (_activeCategory) {
        case 'identity':
          return const IdentitySettings();
        case 'customization':
          return const CustomizationSettings();
        case 'livetv':
          return const LiveTvSettings();
        case 'integrations':
          return const IntegrationsSettings();
        case 'import':
          return const ImportSettings();
        default:
          return Center(
            child: Text(
              "Category $_activeCategory not implemented yet",
              style: const TextStyle(color: Colors.white),
            ),
          );
      }
    }

    final contentWidget = ListView(
      padding: const EdgeInsets.all(32),
      children: [buildContent()],
    );

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
                  : const BackButton(),
            )
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: const BackButton(color: Colors.white),
            ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isMobile
              ? (_showMobileContent ? contentWidget : buildSidebar())
              : Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.01),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      buildSidebar(),
                      Expanded(
                        child: Container(
                          color: AppTheme.surface.withOpacity(0.5),
                          child: contentWidget,
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
