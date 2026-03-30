import 'package:flutter/foundation.dart';

const String _configuredBackendHost = String.fromEnvironment(
  'CAREBIT_BACKEND_HOST',
);
const String _androidEmulatorHost = '10.0.2.2';
const String _localHost = '127.0.0.1';
const String _functionsPort = '5002';
const String _projectId = 'carebit-e30d4';
const String _region = 'us-central1';

List<String> carebitBackendHosts() {
  if (_configuredBackendHost.trim().isNotEmpty) {
    return <String>[_configuredBackendHost.trim()];
  }

  if (kIsWeb) {
    return <String>[_localHost];
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => <String>[_androidEmulatorHost, _localHost],
    _ => <String>[_localHost],
  };
}

Uri fitbitAuthStartUri(String host) {
  return Uri.parse(
    'http://$host:$_functionsPort/$_projectId/$_region/fitbitAuthStart',
  );
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

  return Uri(
    scheme: 'http',
    host: host,
    port: int.parse(_functionsPort),
    path: '$_projectId/$_region/fitbitAuthCallback',
    queryParameters: queryParameters,
  );
}

bool isFitbitCallbackUri(Uri uri) {
  return uri.scheme == 'carebit' && uri.host == 'fitbit-callback';
}
