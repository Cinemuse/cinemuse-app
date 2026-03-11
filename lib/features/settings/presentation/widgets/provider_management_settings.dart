import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/streaming/models/streaming_provider_config.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class ProviderManagementSettings extends ConsumerWidget {
  const ProviderManagementSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final providers = settings.streamingProviders;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.settingsProvidersDesc,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(
            canvasColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final provider = providers[index];
              return Padding(
                key: ValueKey(provider.id),
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      provider.name,
                      style: DesktopTypography.bodySecondary.copyWith(
                        color: provider.enabled ? Colors.white : AppTheme.textMuted,
                      ),
                    ),
                    subtitle: provider.id == 'mediafusion' && settings.mediafusionUrl.isEmpty
                        ? Text(
                            'URL not configured',
                            style: TextStyle(color: Colors.red.withOpacity(0.7), fontSize: 12),
                          )
                        : null,
                    trailing: Switch(
                      value: provider.enabled,
                      onChanged: (value) {
                        final updatedItems = providers.map((p) {
                          if (p.id == provider.id) {
                            return p.copyWith(enabled: value);
                          }
                          return p;
                        }).toList();
                        
                        ref.read(settingsProvider.notifier).updateSettings({
                          'streamingProviders': updatedItems,
                        });
                      },
                      activeColor: AppTheme.accent,
                      activeTrackColor: AppTheme.accent.withOpacity(0.3),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
