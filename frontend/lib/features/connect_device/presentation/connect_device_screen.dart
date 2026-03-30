import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_client/constants/app_constants.dart';
import 'package:mobile_client/constants/route_paths.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/fitbit_oauth.dart';
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

  static const Duration _backendTimeout = Duration(seconds: 3);

  Future<void> _launchFitbitAuth(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    try {
      final Uri authUri = await _resolveFitbitAuthUri();
      final bool launched = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open Fitbit sign-in: $authUri')),
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Could not open Fitbit sign-in: $error')),
      );
    }
  }

  Future<Uri> _resolveFitbitAuthUri() async {
    Object? lastError;

    for (final String host in carebitBackendHosts()) {
      final HttpClient httpClient = HttpClient()
        ..connectionTimeout = _backendTimeout;

      try {
        final HttpClientRequest request = await httpClient
            .getUrl(fitbitAuthStartJsonUri(host))
            .timeout(_backendTimeout);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');

        final HttpClientResponse response = await request.close().timeout(
          _backendTimeout,
        );
        final String body = await response.transform(utf8.decoder).join();
        final Object? decoded = body.isEmpty ? null : jsonDecode(body);

        if (decoded is! Map<String, dynamic>) {
          throw Exception('Backend returned an invalid Fitbit auth response.');
        }

        final String? authUrl = decoded['authUrl'] as String?;

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final String? errorMessage = decoded['error'] as String?;
          throw Exception(
            errorMessage ?? 'Backend could not start the Fitbit OAuth flow.',
          );
        }

        if (authUrl == null || authUrl.isEmpty) {
          throw Exception('Backend did not return a Fitbit authorization URL.');
        }

        return Uri.parse(authUrl);
      } catch (error) {
        lastError = error;
      } finally {
        httpClient.close(force: true);
      }
    }

    throw Exception(
      'Could not reach the Fitbit backend on any development host. '
      'Start the Functions emulator and, on a physical Android phone, run '
      '`adb reverse tcp:5002 tcp:5002`. '
      'Last error: $lastError',
    );
  }

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
                  onPressed: () => _launchFitbitAuth(context),
                  child: const Text('Connect Device'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go(RoutePaths.healthMetrics),
                  child: const Text('Continue to Health Metrics'),
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
