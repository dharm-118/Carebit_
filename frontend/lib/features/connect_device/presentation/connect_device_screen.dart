import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_client/constants/app_constants.dart';

import '../application/connect_device_controller.dart';

/// Connect Device screen.
///
/// In Step 7, this screen now:
/// - starts OAuth in browser
/// - leaves deep-link callback completion to the app shell
/// - keeps the action button disabled while callback finalization is running
class ConnectDeviceScreen extends ConsumerStatefulWidget {
  const ConnectDeviceScreen({super.key});

  @override
  ConsumerState<ConnectDeviceScreen> createState() =>
      _ConnectDeviceScreenState();
}

class _ConnectDeviceScreenState extends ConsumerState<ConnectDeviceScreen> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ConnectDeviceState state = ref.watch(connectDeviceControllerProvider);

    final bool isBusy = state.isConnecting || state.isHandlingCallback;

    return Scaffold(
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF2F5BFF), Color(0xFF6F2CFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.health_and_safety_rounded,
                  size: 42,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Connect Device',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Use one secure flow to connect your Fitbit-supported wearable and prepare real-time health sync.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Text(
                  'Supported Devices',
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _DeviceChip(label: 'Fitbit', icon: Icons.watch_rounded),
                    _DeviceChip(
                      label: 'Pixel Watch',
                      icon: Icons.watch_outlined,
                    ),
                    _DeviceChip(
                      label: 'Apple Watch',
                      icon: Icons.apple_rounded,
                    ),
                    _DeviceChip(label: 'Garmin', icon: Icons.sensors_rounded),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('How it works', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Text(
                          '• Tap Connect Device\n'
                          '• Request OAuth URL from backend\n'
                          '• Open Fitbit login in external browser\n'
                          '• Return to app through carebit://fitbit-callback\n'
                          '• Save devices into ${AppConstants.watchDataCollection}\n'
                          '• Show success snackbar and open Health Metrics',
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: Color(0xFF5E5A78),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: isBusy ? null : _startFitbitOAuth,
                  child: isBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Connect Device'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Fitbit is the primary working provider in this phase. Pixel Watch, Apple Watch, and Garmin are shown as future-ready UI support.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF7E7B97),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Starts Fitbit OAuth — delegates host resolution, auth URL fetch, and
  /// browser launch to the controller.
  Future<void> _startFitbitOAuth() async {
    final controller = ref.read(connectDeviceControllerProvider.notifier);
    controller.setConnecting(isConnecting: true);

    try {
      final result = await controller.startFitbitConnection();

      if (!mounted) return;

      if (result.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorOrNull ?? 'Failed to start Fitbit OAuth.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OAuth start failed: $error')));
    } finally {
      controller.setConnecting(isConnecting: false);
    }
  }
}

/// Reusable chip widget used to visually show supported device brands.
class _DeviceChip extends StatelessWidget {
  const _DeviceChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: const Color(0xFF5B3DF5)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF221B5C),
            ),
          ),
        ],
      ),
    );
  }
}
