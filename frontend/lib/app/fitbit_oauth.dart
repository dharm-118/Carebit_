import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

const String _configuredBackendHost = String.fromEnvironment(
  'CAREBIT_BACKEND_HOST',
);
const String _defaultAndroidLanHost = '10.0.0.223';
const String _androidEmulatorHost = '10.0.2.2';
const String _webLocalHost = '127.0.0.1';
const String _functionsPort = '5002';
const String _projectId = 'carebit-e30d4';
const String _region = 'us-central1';

String? _lastResolvedBackendHost;

List<String> carebitBackendHosts({String? preferredHost}) {
  final LinkedHashSet<String> hosts = LinkedHashSet<String>();

  void addHost(String? host) {
    final String normalizedHost = host?.trim() ?? '';
    if (normalizedHost.isNotEmpty) {
      hosts.add(normalizedHost);
    }
  }

  if (_configuredBackendHost.trim().isNotEmpty) {
    addHost(_configuredBackendHost);
    return hosts.toList(growable: false);
  }

  addHost(preferredHost);
  addHost(_lastResolvedBackendHost);

  if (kIsWeb) {
    addHost(_webLocalHost);
    return hosts.toList(growable: false);
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      addHost(_defaultAndroidLanHost);
      addHost(_androidEmulatorHost);
      break;
    default:
      addHost(_webLocalHost);
      break;
  }

  return hosts.toList(growable: false);
}

void rememberCarebitBackendHost(String host) {
  final String normalizedHost = host.trim();
  _lastResolvedBackendHost = normalizedHost.isEmpty ? null : normalizedHost;
}

String? preferredCarebitBackendHost() {
  final String? host = _lastResolvedBackendHost;
  if (host == null || host.trim().isEmpty) {
    return null;
  }

  return host;
}

Uri fitbitAuthStartUri(String host) {
  return _functionsBaseUri(
    host,
  ).replace(path: '$_projectId/$_region/fitbitAuthStart');
}

Uri fitbitAuthStartJsonUri(String host) {
  return fitbitAuthStartUri(
    host,
  ).replace(queryParameters: const <String, String>{'mode': 'json'});
}

Uri fitbitTokenExchangeUri({
  required String host,
  required String code,
  String? state,
}) {
  final Map<String, String> queryParameters = <String, String>{'code': code};

  if (state != null && state.isNotEmpty) {
    queryParameters['state'] = state;
  }

  return _functionsBaseUri(host).replace(
    path: '$_projectId/$_region/fitbitAuthCallback',
    queryParameters: queryParameters,
  );
}

Uri _functionsBaseUri(String host) {
  final Uri? configuredUri = Uri.tryParse(host);

  if (configuredUri != null &&
      configuredUri.hasScheme &&
      configuredUri.host.isNotEmpty) {
    return Uri(
      scheme: configuredUri.scheme,
      host: configuredUri.host,
      port: configuredUri.hasPort
          ? configuredUri.port
          : int.parse(_functionsPort),
    );
  }

  return Uri(scheme: 'http', host: host, port: int.parse(_functionsPort));
}

String fitbitBackendConnectionErrorMessage({required bool duringCallback}) {
  final StringBuffer message = StringBuffer(
    duringCallback
        ? 'Could not finish Fitbit sign-in.'
        : 'Could not start Fitbit sign-in.',
  );

  if (kIsWeb) {
    message.write(' Start the Functions emulator on port 5002.');
    return message.toString();
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      message.write(
        _configuredBackendHost.trim().isEmpty
            ? ' On a physical Android phone, the app uses the default LAN backend host `$_defaultAndroidLanHost`. If your Wi-Fi IP changes, update that host or run with `--dart-define=CAREBIT_BACKEND_HOST=<YOUR_PC_LAN_IP>`. The Android emulator continues to use `10.0.2.2` automatically.'
            : ' Verify that `CAREBIT_BACKEND_HOST` points to a LAN-reachable machine running the Functions emulator on port 5002.',
      );
      break;
    default:
      message.write(' Start the Functions emulator on port 5002.');
      break;
  }

  return message.toString();
}

String extractFitbitBackendErrorMessage(
  String body, {
  required String fallbackMessage,
}) {
  try {
    final Object? decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      final String? error = decoded['error'] as String?;
      final String? errorDescription = decoded['errorDescription'] as String?;
      final List<String> missing = _extractMissingConfig(decoded['missing']);

      if (error != null && error.isNotEmpty) {
        final StringBuffer message = StringBuffer(error);

        if (errorDescription != null && errorDescription.isNotEmpty) {
          message.write(' ($errorDescription)');
        }

        if (missing.isNotEmpty) {
          message.write(' Missing: ${missing.join(', ')}.');
        }

        return message.toString();
      }
    }
  } catch (_) {
    // Fall back to a generic message when the backend response is not JSON.
  }

  return fallbackMessage;
}

String fitbitUserVisibleError(Object error) {
  final String message = error.toString().trim();
  const String exceptionPrefix = 'Exception: ';

  if (message.startsWith(exceptionPrefix)) {
    return message.substring(exceptionPrefix.length).trim();
  }

  return message;
}

List<String> _extractMissingConfig(Object? rawMissing) {
  if (rawMissing is! List<Object?>) {
    return const <String>[];
  }

  return rawMissing
      .whereType<String>()
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
}

bool isFitbitCallbackUri(Uri uri) {
  return uri.scheme == 'carebit' && uri.host == 'fitbit-callback';
}
