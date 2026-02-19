import 'package:flutter/material.dart';
import 'package:cast/cast.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

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
      title: const Text('Connect to device', style: TextStyle(color: AppTheme.textWhite)),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<CastDevice>>(
          future: _discoveryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Searching for devices...', style: TextStyle(color: AppTheme.textMuted)),
                ],
              );
            }
            
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
            }

            final devices = snapshot.data ?? [];
            if (devices.isEmpty) {
              return const Text('No devices found', style: TextStyle(color: AppTheme.textMuted));
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
          child: const Text('Cancel', style: TextStyle(color: AppTheme.accent)),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _discoveryFuture = CastDiscoveryService().search();
            });
          },
          child: const Text('Refresh', style: TextStyle(color: AppTheme.accent)),
        ),
      ],
    );
  }
}
