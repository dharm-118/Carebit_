import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/carebit_backend_runtime.dart';
import 'package:frontend/app/fitbit_oauth.dart';

const String _deployedFunctionsBaseUri =
    'https://us-central1-carebit-e30d4.cloudfunctions.net';

void main() {
  tearDown(() {
    rememberCarebitBackendHost('');
  });

  test(
    'physical Android devices use the deployed backend before the loopback fallback',
    () {
      final List<String> hosts = carebitBackendHosts(
        runtime: const CarebitBackendRuntime(
          androidDeviceKind: CarebitAndroidDeviceKind.physical,
          isWeb: false,
          targetPlatform: TargetPlatform.android,
        ),
      );

      expect(hosts, <String>[_deployedFunctionsBaseUri, '127.0.0.1']);
    },
  );

  test(
    'Android emulators use the deployed backend before emulator and loopback fallbacks',
    () {
      final List<String> hosts = carebitBackendHosts(
        runtime: const CarebitBackendRuntime(
          androidDeviceKind: CarebitAndroidDeviceKind.emulator,
          isWeb: false,
          targetPlatform: TargetPlatform.android,
        ),
      );

      expect(hosts, <String>[
        _deployedFunctionsBaseUri,
        '10.0.2.2',
        '127.0.0.1',
      ]);
    },
  );

  test('remembered hosts win before default backend fallbacks', () {
    rememberCarebitBackendHost('remembered-host');

    final List<String> hosts = carebitBackendHosts(
      preferredHost: 'preferred-host',
      runtime: const CarebitBackendRuntime(
        androidDeviceKind: CarebitAndroidDeviceKind.emulator,
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      ),
    );

    expect(hosts, <String>[
      'preferred-host',
      'remembered-host',
      _deployedFunctionsBaseUri,
      '10.0.2.2',
      '127.0.0.1',
    ]);
  });

  test(
    'cloud Functions targets use direct function paths instead of emulator paths',
    () {
      final Uri healthUri = carebitHealthUri(_deployedFunctionsBaseUri);
      final Uri authStartUri = fitbitAuthStartJsonUri(_deployedFunctionsBaseUri);
      final Uri callbackUri = fitbitAuthCallbackUri(_deployedFunctionsBaseUri);
      final Uri callbackStatusUri = fitbitAuthCallbackStatusUri(
        _deployedFunctionsBaseUri,
      );

      expect(healthUri.toString(), '$_deployedFunctionsBaseUri/health');
      expect(
        authStartUri.toString(),
        '$_deployedFunctionsBaseUri/fitbitAuthStart?mode=json',
      );
      expect(
        callbackUri.toString(),
        '$_deployedFunctionsBaseUri/fitbitAuthCallback',
      );
      expect(
        callbackStatusUri.toString(),
        '$_deployedFunctionsBaseUri/fitbitAuthCallbackStatus',
      );
    },
  );

  test('local emulator hosts use emulator function paths', () {
    final Uri healthUri = carebitHealthUri('127.0.0.1');
    final Uri callbackUri = fitbitAuthCallbackUri('127.0.0.1');
    final Uri callbackStatusUri = fitbitAuthCallbackStatusUri('127.0.0.1');

    expect(
      healthUri.toString(),
      'http://127.0.0.1:5002/carebit-e30d4/us-central1/health',
    );
    expect(
      callbackUri.toString(),
      'http://127.0.0.1:5002/carebit-e30d4/us-central1/fitbitAuthCallback',
    );
    expect(
      callbackStatusUri.toString(),
      'http://127.0.0.1:5002/carebit-e30d4/us-central1/fitbitAuthCallbackStatus',
    );
    },
  );
}
