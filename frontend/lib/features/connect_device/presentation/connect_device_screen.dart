import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_client/constants/app_constants.dart';
import 'package:mobile_client/constants/route_paths.dart';

import '../../../app/theme/app_theme.dart';

/// Connect Device screen.
///
/// This is the starter UI for the connection flow.
/// Right now it shows:
/// - themed header
/// - supported device chips
/// - one single Connect Device button
///
/// In a later step, this button will launch the actual Fitbit OAuth flow.
class ConnectDeviceScreen extends StatelessWidget {
  const ConnectDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CarebitColors colors = context.carebitColors;
    final Color onPrimary = theme.colorScheme.onPrimary;

    return Scaffold(
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(36),
              ),
              gradient: LinearGradient(
                colors: <Color>[colors.gradientStart, colors.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.health_and_safety_rounded,
                  size: 42,
                  color: onPrimary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Connect Device',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: onPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Use one secure flow to connect your Fitbit-supported wearable and prepare real-time health sync.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: onPrimary.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Text('Supported Devices', style: theme.textTheme.headlineSmall),
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
                          '- Tap Connect Device\n'
                          '- Start Fitbit OAuth\n'
                          '- Authenticate securely through backend\n'
                          '- Detect linked wearable information\n'
                          '- Store watch data in Firestore collection: ${AppConstants.watchDataCollection}\n'
                          '- Redirect to Health Metrics automatically',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: colors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => context.go(RoutePaths.healthMetrics),
                  child: const Text('Connect Device'),
                ),
                const SizedBox(height: 14),
                Text(
                  'Fitbit is the primary working provider in this phase. Pixel Watch, Apple Watch, and Garmin are shown as future-ready UI support.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.mutedText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable chip widget used to visually show supported device brands.
class _DeviceChip extends StatelessWidget {
  const _DeviceChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CarebitColors colors = context.carebitColors;
    final Color surface = theme.colorScheme.surface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: colors.gradientStart),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.brandText,
            ),
          ),
        ],
      ),
    );
  }
}
