import 'package:flutter/material.dart';
import 'package:cast/cast.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class CastDeviceSelector extends StatefulWidget {
  const CastDeviceSelector({super.key});

  static Future<CastDevice?> show(BuildContext context) {
    return showDialog<CastDevice>(
      context: context,
      builder: (context) => const CastDeviceSelector(),
    );
  }

  @override
  State<CastDeviceSelector> createState() => _CastDeviceSelectorState();
}

class _CastDeviceSelectorState extends State<CastDeviceSelector> {
  late Future<List<CastDevice>> _discoveryFuture;

  @override
  void initState() {
    super.initState();
    _discoveryFuture = CastDiscoveryService().search();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(AppLocalizations.of(context)!.castConnectDevice, style: const TextStyle(color: AppTheme.textWhite)),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<CastDevice>>(
          future: _discoveryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.castSearching, style: const TextStyle(color: AppTheme.textMuted)),
                ],
              );
            }
            
            if (snapshot.hasError) {
              return Text(AppLocalizations.of(context)!.castError(snapshot.error.toString()), style: const TextStyle(color: Colors.red));
            }

            final devices = snapshot.data ?? [];
            if (devices.isEmpty) {
              return Text(AppLocalizations.of(context)!.castNoDevices, style: const TextStyle(color: AppTheme.textMuted));
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  leading: const Icon(Icons.cast, color: AppTheme.textWhite),
                  title: Text(device.name, style: const TextStyle(color: AppTheme.textWhite)),
                  onTap: () => Navigator.pop(context, device),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.commonCancel, style: const TextStyle(color: AppTheme.accent)),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _discoveryFuture = CastDiscoveryService().search();
            });
          },
          child: Text(AppLocalizations.of(context)!.castRefresh, style: const TextStyle(color: AppTheme.accent)),
        ),
      ],
    );
  }
}
