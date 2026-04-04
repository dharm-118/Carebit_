import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'carebit_backend_runtime.dart';

const String _configuredBackendHost = String.fromEnvironment(
  'CAREBIT_BACKEND_HOST',
);
const String _projectId = 'carebit-e30d4';
const String _region = 'us-central1';
const String _deployedFunctionsBaseUri =
    'https://$_region-$_projectId.cloudfunctions.net';
const String _androidEmulatorHost = '10.0.2.2';
const String _androidLoopbackHost = '127.0.0.1';
const String _webLocalHost = '127.0.0.1';
const String _cloudFunctionsDomainSuffix = '.cloudfunctions.net';
const String _cloudRunDomainSuffix = '.run.app';
const String _functionsPort = '5002';

String? _lastResolvedBackendHost;

List<String> carebitBackendHosts({
  String? preferredHost,
  CarebitBackendRuntime? runtime,
}) {
  final LinkedHashSet<String> hosts = LinkedHashSet<String>();
  final CarebitBackendRuntime resolvedRuntime =
      runtime ?? CarebitBackendRuntime.currentPlatform();

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
  addHost(_deployedFunctionsBaseUri);

  if (resolvedRuntime.isWeb) {
    addHost(_webLocalHost);
    return hosts.toList(growable: false);
  }

  switch (resolvedRuntime.targetPlatform) {
    case TargetPlatform.android:
      if (resolvedRuntime.isAndroidEmulator) {
        addHost(_androidEmulatorHost);
        addHost(_androidLoopbackHost);
      } else if (resolvedRuntime.isKnownPhysicalAndroidDevice) {
        addHost(_androidLoopbackHost);
      } else {
        addHost(_androidLoopbackHost);
        addHost(_androidEmulatorHost);
      }
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
  return _functionEndpointUri(host, 'fitbitAuthStart');
}

Uri carebitHealthUri(String host) {
  return _functionEndpointUri(host, 'health');
}

Uri fitbitAuthStartJsonUri(String host) {
  return fitbitAuthStartUri(
    host,
  ).replace(queryParameters: const <String, String>{'mode': 'json'});
}

Uri fitbitAuthCallbackUri(String host) {
  return _functionEndpointUri(host, 'fitbitAuthCallback');
}

Uri fitbitAuthCallbackStatusUri(String host) {
  return _functionEndpointUri(host, 'fitbitAuthCallbackStatus');
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

  return fitbitAuthCallbackUri(host).replace(queryParameters: queryParameters);
}

Uri _functionsBaseUri(String host) {
  final Uri? configuredUri = Uri.tryParse(host);

  if (configuredUri != null &&
      configuredUri.hasScheme &&
      configuredUri.host.isNotEmpty) {
    if (configuredUri.hasPort) {
      return Uri(
        scheme: configuredUri.scheme,
        host: configuredUri.host,
        port: configuredUri.port,
        path: configuredUri.path,
      );
    }

    if (_usesDirectFunctionPath(configuredUri)) {
      return Uri(
        scheme: configuredUri.scheme,
        host: configuredUri.host,
        path: configuredUri.path,
      );
    }

    return Uri(
      scheme: configuredUri.scheme,
      host: configuredUri.host,
      port: int.parse(_functionsPort),
      path: configuredUri.path,
    );
  }

  return Uri(scheme: 'http', host: host, port: int.parse(_functionsPort));
}

Uri _functionEndpointUri(String host, String functionName) {
  final Uri baseUri = _functionsBaseUri(host);

  return baseUri.replace(path: _functionEndpointPath(baseUri, functionName));
}

String _functionEndpointPath(Uri baseUri, String functionName) {
  if (_usesDirectFunctionPath(baseUri)) {
    return _appendPathSegment(baseUri.path, functionName);
  }

  return '/$_projectId/$_region/$functionName';
}

bool _usesDirectFunctionPath(Uri baseUri) {
  if (baseUri.path.trim().isNotEmpty && baseUri.path.trim() != '/') {
    return true;
  }

  return baseUri.host.endsWith(_cloudFunctionsDomainSuffix) ||
      baseUri.host.endsWith(_cloudRunDomainSuffix);
}

String _appendPathSegment(String basePath, String pathSegment) {
  if (basePath.isEmpty || basePath == '/') {
    return '/$pathSegment';
  }

  final String normalizedBasePath = basePath.endsWith('/')
      ? basePath.substring(0, basePath.length - 1)
      : basePath;
  return '$normalizedBasePath/$pathSegment';
}

String fitbitBackendConnectionErrorMessage({required bool duringCallback}) {
  final StringBuffer message = StringBuffer(
    duringCallback
        ? 'Could not finish Fitbit sign-in.'
        : 'Could not start Fitbit sign-in.',
  );

  message.write(' ${_fitbitBackendConnectivityGuidance()}');
  return message.toString();
}

String fitbitAuthStartHostResolutionErrorMessage({
  required List<String> attemptedHosts,
  String? lastError,
}) {
  final StringBuffer message = StringBuffer(
    'Could not reach a Carebit backend that can start Fitbit sign-in.',
  );

  if (attemptedHosts.isNotEmpty) {
    message.write(' Tried hosts: ${attemptedHosts.join(', ')}.');
  }

  final String normalizedLastError = lastError?.trim() ?? '';
  if (normalizedLastError.isNotEmpty) {
    message.write(' Last error: $normalizedLastError');
    if (!normalizedLastError.endsWith('.')) {
      message.write('.');
    }
  }

  message.write(' ${_fitbitBackendConnectivityGuidance()}');
  return message.toString();
}

String fitbitNoBackendHostConfiguredMessage({
  required CarebitBackendRuntime runtime,
}) {
  if (runtime.isKnownPhysicalAndroidDevice || runtime.isUnknownAndroidDevice) {
    return 'No Carebit backend host candidate is available for this Android device. The app normally uses the deployed Firebase Functions backend automatically. To target a local Functions emulator instead, optionally run the app with `--dart-define=CAREBIT_BACKEND_HOST=<YOUR_PC_LAN_IP>` and ensure the emulator is reachable on port $_functionsPort.';
  }

  return fitbitBackendConnectionErrorMessage(duringCallback: false);
}

String fitbitBackendConfigurationErrorMessage({
  required String host,
  List<String> missing = const <String>[],
}) {
  final StringBuffer message = StringBuffer(
    'Carebit backend host `$host` is reachable, but Fitbit backend configuration is incomplete.',
  );

  if (missing.isNotEmpty) {
    message.write(' Missing: ${missing.join(', ')}.');
  }

  return message.toString();
}

String _fitbitBackendConnectivityGuidance() {
  if (kIsWeb) {
    return 'Start the Functions emulator on port 5002.';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return _configuredBackendHost.trim().isEmpty
          ? 'The app uses the deployed Firebase Functions backend by default, so plain `flutter run` works without extra flags. To target a local Functions emulator instead, the Android emulator can use `$_androidEmulatorHost`, and a physical Android phone can use `--dart-define=CAREBIT_BACKEND_HOST=<YOUR_PC_LAN_IP>`. Ensure any local emulator is reachable on port $_functionsPort.'
          : 'Verify that `CAREBIT_BACKEND_HOST` points to a reachable Functions emulator on port $_functionsPort or to a full HTTPS Functions base URL.';
    default:
      return _configuredBackendHost.trim().isEmpty
          ? 'The app uses the deployed Firebase Functions backend by default. To target a local Functions emulator instead, point `CAREBIT_BACKEND_HOST` at it and ensure it is reachable on port $_functionsPort.'
          : 'Verify that `CAREBIT_BACKEND_HOST` points to a reachable Functions emulator on port $_functionsPort or to a full HTTPS Functions base URL.';
  }
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
