import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/carebit_backend_runtime.dart';
import 'package:frontend/app/fitbit_callback_session_store.dart';
import 'package:frontend/app/fitbit_oauth.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/features/connect_device/application/connect_device_controller.dart';
import 'package:mobile_client/core/result.dart';
import 'package:mobile_client/models/watch_data.dart';
import 'package:mobile_client/repositories/device_connection_repository.dart';

const String _deployedFunctionsBaseUri =
    'https://us-central1-carebit-e30d4.cloudfunctions.net';
const String _deployedFunctionsHost =
    'us-central1-carebit-e30d4.cloudfunctions.net';

void main() {
  setUp(() {
    rememberCarebitBackendHost('127.0.0.1');
  });

  tearDown(() {
    rememberCarebitBackendHost('');
  });

  test(
    'finalizeFitbitCallback refreshes the Firebase ID token and succeeds when a token becomes available',
    () async {
      final _FakeUser user = _FakeUser(<String?>['  ', 'token-123']);
      final _FakeDeviceConnectionRepository repository =
          _FakeDeviceConnectionRepository(
            finalizeResponses: <FitbitCallbackFinalizeResult>[
              FitbitCallbackFinalizeSuccess(_buildWatchData()),
            ],
          );
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: repository,
        fitbitCallbackSessionStore: _InMemoryFitbitCallbackSessionStore(),
        firebaseAuth: _FakeFirebaseAuth(currentUser: user),
        delay: (_) async {},
      );

      final FitbitCallbackCompletion result = await controller
          .finalizeFitbitCallback(code: 'fitbit-code', state: 'fitbit-state');

      expect(result.type, FitbitCallbackCompletionType.success);
      expect(repository.finalizeCallCount, 1);
      expect(repository.receivedCode, 'fitbit-code');
      expect(repository.receivedState, 'fitbit-state');
      expect(repository.receivedFirebaseIdToken, 'token-123');
      expect(user.getIdTokenCalls, <bool>[false, true]);
    },
  );

  test(
    'finalizeFitbitCallback fails when both Firebase ID token attempts are empty',
    () async {
      final _FakeUser user = _FakeUser(<String?>[null, '   ']);
      final _FakeDeviceConnectionRepository repository =
          _FakeDeviceConnectionRepository(
            finalizeResponses: <FitbitCallbackFinalizeResult>[
              FitbitCallbackFinalizeSuccess(_buildWatchData()),
            ],
          );
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: repository,
        fitbitCallbackSessionStore: _InMemoryFitbitCallbackSessionStore(),
        firebaseAuth: _FakeFirebaseAuth(currentUser: user),
        delay: (_) async {},
      );

      final FitbitCallbackCompletion result = await controller
          .finalizeFitbitCallback(code: 'fitbit-code', state: 'fitbit-state');

      expect(result.type, FitbitCallbackCompletionType.failed);
      expect(
        result.message,
        contains('Firebase ID token was unavailable after refresh.'),
      );
      expect(repository.finalizeCallCount, 0);
      expect(user.getIdTokenCalls, <bool>[false, true]);
    },
  );

  test(
    'finalizeFitbitCallback recovers from a timeout by polling callback status until success',
    () async {
      final _FakeDeviceConnectionRepository repository =
          _FakeDeviceConnectionRepository(
            finalizeResponses: <FitbitCallbackFinalizeResult>[
              const FitbitCallbackFinalizePending(
                reason: FitbitCallbackFinalizePendingReason.retryableNetwork,
              ),
            ],
            statusResponses: <FitbitCallbackStatusSnapshot>[
              const FitbitCallbackStatusSnapshot(
                kind: FitbitCallbackStatusKind.processing,
              ),
              FitbitCallbackStatusSnapshot(
                device: _buildWatchData(),
                kind: FitbitCallbackStatusKind.succeeded,
              ),
            ],
          );
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: repository,
        fitbitCallbackSessionStore: sessionStore,
        firebaseAuth: _FakeFirebaseAuth(
          currentUser: _FakeUser(<String?>['token-123']),
        ),
        callbackFinalizeRetryInterval: const Duration(days: 1),
        callbackRecoveryWindow: const Duration(seconds: 1),
        callbackStatusPollInterval: Duration.zero,
        delay: (_) async {},
      );

      final FitbitCallbackCompletion result = await controller
          .finalizeFitbitCallback(code: 'fitbit-code', state: 'fitbit-state');

      expect(result.type, FitbitCallbackCompletionType.success);
      expect(repository.finalizeCallCount, greaterThanOrEqualTo(1));
      expect(repository.statusCallCount, 2);
      expect(
        (await sessionStore.readPendingCallbackSession())?.code,
        'fitbit-code',
      );
    },
  );

  test(
    'resumePendingFitbitCallback returns failed when the saved session has no code',
    () async {
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      await sessionStore.savePendingState('fitbit-state');
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: _FakeDeviceConnectionRepository(
          finalizeResponses: <FitbitCallbackFinalizeResult>[
            FitbitCallbackFinalizeSuccess(_buildWatchData()),
          ],
        ),
        fitbitCallbackSessionStore: sessionStore,
        firebaseAuth: _FakeFirebaseAuth(
          currentUser: _FakeUser(<String?>['token-123']),
        ),
        delay: (_) async {},
      );

      final FitbitCallbackCompletion result = await controller
          .resumePendingFitbitCallback();

      expect(result.type, FitbitCallbackCompletionType.failed);
      expect(
        result.message,
        'Fitbit sign-in session could not be resumed. Start the connection again.',
      );
    },
  );

  test(
    'finalizeFitbitCallback returns terminal backend failures without leaving the flow pending',
    () async {
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: _FakeDeviceConnectionRepository(
          finalizeResponses: <FitbitCallbackFinalizeResult>[
            const FitbitCallbackFinalizeFailure(
              'Fitbit returned no connected device data.',
            ),
          ],
        ),
        fitbitCallbackSessionStore: _InMemoryFitbitCallbackSessionStore(),
        firebaseAuth: _FakeFirebaseAuth(
          currentUser: _FakeUser(<String?>['token-123']),
        ),
        delay: (_) async {},
      );

      final FitbitCallbackCompletion result = await controller
          .finalizeFitbitCallback(code: 'fitbit-code', state: 'fitbit-state');

      expect(result.type, FitbitCallbackCompletionType.failed);
      expect(result.message, 'Fitbit returned no connected device data.');
    },
  );

  test(
    'probeCarebitBackendHealth parses a successful backend health response',
    () async {
      final DeviceConnectionRepository repository = DeviceConnectionRepository(
        client: MockClient((http.Request request) async {
          expect(request.url.path, contains('/health'));
          return http.Response(
            jsonEncode(<String, Object>{
              'ok': true,
              'fitbitConfigured': false,
              'fitbitMissingConfig': <String>['FITBIT_CLIENT_ID'],
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final Result<CarebitBackendHealthSnapshot> result = await repository
          .probeCarebitBackendHealth(
            endpointUri: Uri.parse(
              'http://127.0.0.1:5002/carebit-e30d4/us-central1/health',
            ),
          );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.fitbitConfigured, isFalse);
      expect(result.dataOrNull?.missingFitbitConfig, <String>[
        'FITBIT_CLIENT_ID',
      ]);
    },
  );

  test(
    'fetchFitbitAuthorizationUrl returns an actionable error when the backend responds with HTML',
    () async {
      final DeviceConnectionRepository repository = DeviceConnectionRepository(
        client: MockClient((http.Request request) async {
          return http.Response(
            '<html><head><title>404</title></head><body>Not Found</body></html>',
            404,
            headers: const <String, String>{
              'content-type': 'text/html; charset=utf-8',
            },
          );
        }),
      );

      final Result<Uri> result = await repository.fetchFitbitAuthorizationUrl(
        endpointUri: fitbitAuthStartJsonUri(_deployedFunctionsBaseUri),
        state: 'fitbit-state',
      );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, contains('unexpected HTML response'));
      expect(result.errorOrNull, contains('fitbitAuthStart'));
      expect(result.errorOrNull, contains('HTTP 404'));
      expect(result.errorOrNull, isNot(contains('FormatException')));
    },
  );

  test(
    'finalizeFitbitConnection returns an actionable error when the callback endpoint responds with HTML',
    () async {
      final DeviceConnectionRepository repository = DeviceConnectionRepository(
        client: MockClient((http.Request request) async {
          return http.Response(
            '<html><head><title>404</title></head><body>Not Found</body></html>',
            404,
            headers: const <String, String>{
              'content-type': 'text/html; charset=utf-8',
            },
          );
        }),
      );

      final FitbitCallbackFinalizeResult result = await repository
          .finalizeFitbitConnection(
            endpointUri: fitbitAuthCallbackUri(_deployedFunctionsBaseUri),
            code: 'fitbit-code',
            firebaseIdToken: 'firebase-token',
            state: 'fitbit-state',
          );

      expect(result, isA<FitbitCallbackFinalizeFailure>());
      final FitbitCallbackFinalizeFailure failure =
          result as FitbitCallbackFinalizeFailure;
      expect(failure.message, contains('unexpected HTML response'));
      expect(failure.message, contains('fitbitAuthCallback'));
      expect(failure.message, contains('HTTP 404'));
      expect(failure.message, isNot(contains('FormatException')));
    },
  );

  test(
    'fetchFitbitCallbackStatus returns an actionable error when the status endpoint responds with HTML',
    () async {
      final DeviceConnectionRepository repository = DeviceConnectionRepository(
        client: MockClient((http.Request request) async {
          return http.Response(
            '<html><head><title>404</title></head><body>Not Found</body></html>',
            404,
            headers: const <String, String>{
              'content-type': 'text/html; charset=utf-8',
            },
          );
        }),
      );

      final Result<FitbitCallbackStatusSnapshot> result = await repository
          .fetchFitbitCallbackStatus(
            endpointUri: fitbitAuthCallbackStatusUri(_deployedFunctionsBaseUri),
            firebaseIdToken: 'firebase-token',
            state: 'fitbit-state',
          );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, contains('unexpected HTML response'));
      expect(result.errorOrNull, contains('fitbitAuthCallbackStatus'));
      expect(result.errorOrNull, contains('HTTP 404'));
      expect(result.errorOrNull, isNot(contains('FormatException')));
    },
  );

  test(
    'probeCarebitBackendHealth returns an actionable error when the health endpoint responds with HTML',
    () async {
      final DeviceConnectionRepository repository = DeviceConnectionRepository(
        client: MockClient((http.Request request) async {
          return http.Response(
            '<html><head><title>404</title></head><body>Not Found</body></html>',
            404,
            headers: const <String, String>{
              'content-type': 'text/html; charset=utf-8',
            },
          );
        }),
      );

      final Result<CarebitBackendHealthSnapshot> result = await repository
          .probeCarebitBackendHealth(
            endpointUri: carebitHealthUri(_deployedFunctionsBaseUri),
          );

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, contains('unexpected HTML response'));
      expect(result.errorOrNull, contains('health'));
      expect(result.errorOrNull, contains('HTTP 404'));
      expect(result.errorOrNull, isNot(contains('FormatException')));
    },
  );

  test(
    'startFitbitConnection falls through a dead host and uses a healthy emulator host',
    () async {
      rememberCarebitBackendHost('');
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      Uri? launchedUri;
      final _FakeDeviceConnectionRepository
      repository = _FakeDeviceConnectionRepository(
        finalizeResponses: const <FitbitCallbackFinalizeResult>[],
        authStartResultsByHost: <String, Result<Uri>>{
          '10.0.2.2': ResultSuccess<Uri>(
            Uri.parse('https://fitbit.example/oauth-start'),
          ),
        },
        healthResponsesByHost: <String, Result<CarebitBackendHealthSnapshot>>{
          'dead-host': const ResultFailure<CarebitBackendHealthSnapshot>(
            'Carebit backend health check timed out.',
          ),
          '10.0.2.2': const ResultSuccess<CarebitBackendHealthSnapshot>(
            CarebitBackendHealthSnapshot(fitbitConfigured: true),
          ),
        },
      );
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: repository,
        fitbitCallbackSessionStore: sessionStore,
        firebaseAuth: _FakeFirebaseAuth(
          currentUser: _FakeUser(<String?>['token-123']),
        ),
        backendHostsResolver: ({String? preferredHost}) => const <String>[
          'dead-host',
          '10.0.2.2',
        ],
        delay: (_) async {},
        launchExternalUri: (Uri uri) async {
          launchedUri = uri;
          return true;
        },
      );

      final Result<void> result = await controller.startFitbitConnection();

      expect(result.isSuccess, isTrue);
      expect(repository.healthProbeHosts, <String>['dead-host', '10.0.2.2']);
      expect(repository.authStartHosts, <String>['10.0.2.2']);
      expect(launchedUri, Uri.parse('https://fitbit.example/oauth-start'));
      expect(preferredCarebitBackendHost(), '10.0.2.2');
      expect(
        (await sessionStore.readPendingCallbackSession())?.backendHost,
        '10.0.2.2',
      );
    },
  );

  test(
    'finalizeFitbitCallback reuses the persisted backend host after the browser round-trip',
    () async {
      rememberCarebitBackendHost('');
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      await sessionStore.savePendingCallbackSession(
        const PendingFitbitCallbackSession(
          backendHost: '127.0.0.1',
          code: 'fitbit-code',
          state: 'fitbit-state',
        ),
      );
      final _FakeDeviceConnectionRepository repository =
          _FakeDeviceConnectionRepository(
            finalizeResponses: <FitbitCallbackFinalizeResult>[
              FitbitCallbackFinalizeSuccess(_buildWatchData()),
            ],
          );
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: repository,
        fitbitCallbackSessionStore: sessionStore,
        firebaseAuth: _FakeFirebaseAuth(
          currentUser: _FakeUser(<String?>['token-123']),
        ),
        backendHostsResolver: ({String? preferredHost}) =>
            <String>[?preferredHost, _deployedFunctionsBaseUri],
        delay: (_) async {},
      );

      final FitbitCallbackCompletion result = await controller
          .finalizeFitbitCallback(code: 'fitbit-code', state: 'fitbit-state');

      expect(result.type, FitbitCallbackCompletionType.success);
      expect(repository.receivedEndpointUri?.host, '127.0.0.1');
      expect(preferredCarebitBackendHost(), '127.0.0.1');
      expect(
        (await sessionStore.readPendingCallbackSession())?.backendHost,
        '127.0.0.1',
      );
    },
  );

  test(
    'startFitbitConnection uses the first resolver host so explicit hosts can win before fallbacks',
    () async {
      rememberCarebitBackendHost('');
      final _FakeDeviceConnectionRepository
      repository = _FakeDeviceConnectionRepository(
        finalizeResponses: const <FitbitCallbackFinalizeResult>[],
        authStartResultsByHost: <String, Result<Uri>>{
          'explicit-host': ResultSuccess<Uri>(
            Uri.parse('https://fitbit.example/explicit'),
          ),
        },
        healthResponsesByHost: <String, Result<CarebitBackendHealthSnapshot>>{
          'explicit-host': const ResultSuccess<CarebitBackendHealthSnapshot>(
            CarebitBackendHealthSnapshot(fitbitConfigured: true),
          ),
        },
      );
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: repository,
        fitbitCallbackSessionStore: _InMemoryFitbitCallbackSessionStore(),
        firebaseAuth: _FakeFirebaseAuth(
          currentUser: _FakeUser(<String?>['token-123']),
        ),
        backendHostsResolver: ({String? preferredHost}) => const <String>[
          'explicit-host',
          'fallback-host',
        ],
        delay: (_) async {},
        launchExternalUri: (_) async => true,
      );

      final Result<void> result = await controller.startFitbitConnection();

      expect(result.isSuccess, isTrue);
      expect(repository.healthProbeHosts, <String>['explicit-host']);
      expect(repository.authStartHosts, <String>['explicit-host']);
    },
  );

  test(
    'startFitbitConnection prefers the remembered host before fallback hosts',
    () async {
      rememberCarebitBackendHost('remembered-host');
      final _FakeDeviceConnectionRepository
      repository = _FakeDeviceConnectionRepository(
        finalizeResponses: const <FitbitCallbackFinalizeResult>[],
        authStartResultsByHost: <String, Result<Uri>>{
          'remembered-host': ResultSuccess<Uri>(
            Uri.parse('https://fitbit.example/remembered'),
          ),
        },
        healthResponsesByHost: <String, Result<CarebitBackendHealthSnapshot>>{
          'remembered-host': const ResultSuccess<CarebitBackendHealthSnapshot>(
            CarebitBackendHealthSnapshot(fitbitConfigured: true),
          ),
        },
      );
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: repository,
        fitbitCallbackSessionStore: _InMemoryFitbitCallbackSessionStore(),
        firebaseAuth: _FakeFirebaseAuth(
          currentUser: _FakeUser(<String?>['token-123']),
        ),
        backendHostsResolver: ({String? preferredHost}) =>
            <String>[?preferredHost, 'fallback-host'],
        delay: (_) async {},
        launchExternalUri: (_) async => true,
      );

      final Result<void> result = await controller.startFitbitConnection();

      expect(result.isSuccess, isTrue);
      expect(repository.healthProbeHosts, <String>['remembered-host']);
      expect(repository.authStartHosts, <String>['remembered-host']);
    },
  );

  test(
    'startFitbitConnection returns an actionable error when no backend host is reachable',
    () async {
      rememberCarebitBackendHost('');
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      final _FakeDeviceConnectionRepository
      repository = _FakeDeviceConnectionRepository(
        finalizeResponses: const <FitbitCallbackFinalizeResult>[],
        healthResponsesByHost: <String, Result<CarebitBackendHealthSnapshot>>{
          'dead-host': const ResultFailure<CarebitBackendHealthSnapshot>(
            'Carebit backend health check timed out.',
          ),
          'offline-host': const ResultFailure<CarebitBackendHealthSnapshot>(
            'Could not reach the Carebit backend health endpoint: ClientException',
          ),
        },
      );
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: repository,
        fitbitCallbackSessionStore: sessionStore,
        firebaseAuth: _FakeFirebaseAuth(
          currentUser: _FakeUser(<String?>['token-123']),
        ),
        backendHostsResolver: ({String? preferredHost}) => const <String>[
          'dead-host',
          'offline-host',
        ],
        delay: (_) async {},
        launchExternalUri: (_) async => true,
      );

      final Result<void> result = await controller.startFitbitConnection();

      expect(result.isFailure, isTrue);
      expect(
        result.errorOrNull,
        contains('Tried hosts: dead-host, offline-host'),
      );
      expect(result.errorOrNull, contains('CAREBIT_BACKEND_HOST'));
      expect(result.errorOrNull, contains('5002'));
      expect(repository.authStartHosts, isEmpty);
      expect(await sessionStore.readPendingState(), isNull);
    },
  );

  test(
    'startFitbitConnection uses the deployed Firebase Functions backend by default on physical Android',
    () async {
      rememberCarebitBackendHost('');
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      Uri? launchedUri;
      final _FakeDeviceConnectionRepository repository =
          _FakeDeviceConnectionRepository(
            finalizeResponses: const <FitbitCallbackFinalizeResult>[],
            authStartResultsByHost: <String, Result<Uri>>{
              _deployedFunctionsHost: ResultSuccess<Uri>(
                Uri.parse('https://fitbit.example/cloud'),
              ),
            },
            healthResponsesByHost: <String, Result<CarebitBackendHealthSnapshot>>{
              _deployedFunctionsHost:
                  const ResultSuccess<CarebitBackendHealthSnapshot>(
                CarebitBackendHealthSnapshot(fitbitConfigured: true),
              ),
            },
          );
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: repository,
        backendRuntime: const CarebitBackendRuntime(
          androidDeviceKind: CarebitAndroidDeviceKind.physical,
          isWeb: false,
          targetPlatform: TargetPlatform.android,
        ),
        fitbitCallbackSessionStore: sessionStore,
        firebaseAuth: _FakeFirebaseAuth(
          currentUser: _FakeUser(<String?>['token-123']),
        ),
        delay: (_) async {},
        launchExternalUri: (Uri uri) async {
          launchedUri = uri;
          return true;
        },
      );

      final Result<void> result = await controller.startFitbitConnection();

      expect(result.isSuccess, isTrue);
      expect(repository.healthProbeHosts, <String>[_deployedFunctionsHost]);
      expect(repository.authStartHosts, <String>[_deployedFunctionsHost]);
      expect(launchedUri, Uri.parse('https://fitbit.example/cloud'));
      expect(preferredCarebitBackendHost(), _deployedFunctionsBaseUri);
      expect(await sessionStore.readPendingState(), isNotNull);
    },
  );

  test(
    'startFitbitConnection falls back from the deployed backend to local loopback when needed',
    () async {
      rememberCarebitBackendHost('');
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      Uri? launchedUri;
      final _FakeDeviceConnectionRepository repository =
          _FakeDeviceConnectionRepository(
            finalizeResponses: const <FitbitCallbackFinalizeResult>[],
            authStartResultsByHost: <String, Result<Uri>>{
              '127.0.0.1': ResultSuccess<Uri>(
                Uri.parse('https://fitbit.example/loopback'),
              ),
            },
            healthResponsesByHost: <String, Result<CarebitBackendHealthSnapshot>>{
              _deployedFunctionsHost:
                  const ResultFailure<CarebitBackendHealthSnapshot>(
                'Carebit backend health check timed out.',
              ),
              '127.0.0.1': const ResultSuccess<CarebitBackendHealthSnapshot>(
                CarebitBackendHealthSnapshot(fitbitConfigured: true),
              ),
            },
          );
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: repository,
        backendRuntime: const CarebitBackendRuntime(
          androidDeviceKind: CarebitAndroidDeviceKind.physical,
          isWeb: false,
          targetPlatform: TargetPlatform.android,
        ),
        fitbitCallbackSessionStore: sessionStore,
        firebaseAuth: _FakeFirebaseAuth(
          currentUser: _FakeUser(<String?>['token-123']),
        ),
        delay: (_) async {},
        launchExternalUri: (Uri uri) async {
          launchedUri = uri;
          return true;
        },
      );

      final Result<void> result = await controller.startFitbitConnection();

      expect(result.isSuccess, isTrue);
      expect(repository.healthProbeHosts, <String>[
        _deployedFunctionsHost,
        '127.0.0.1',
      ]);
      expect(repository.authStartHosts, <String>['127.0.0.1']);
      expect(launchedUri, Uri.parse('https://fitbit.example/loopback'));
      expect(preferredCarebitBackendHost(), '127.0.0.1');
    },
  );

  test(
    'startFitbitConnection exhausts the deployed backend and physical Android loopback fallback before failing',
    () async {
      rememberCarebitBackendHost('');
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      final _FakeDeviceConnectionRepository repository =
          _FakeDeviceConnectionRepository(
            finalizeResponses: const <FitbitCallbackFinalizeResult>[],
            healthResponsesByHost: <String, Result<CarebitBackendHealthSnapshot>>{
              _deployedFunctionsHost:
                  const ResultFailure<CarebitBackendHealthSnapshot>(
                'Could not reach the Carebit backend health endpoint: ClientException',
              ),
              '127.0.0.1': const ResultFailure<CarebitBackendHealthSnapshot>(
                'Could not reach the Carebit backend health endpoint: ClientException',
              ),
            },
          );
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: repository,
        backendRuntime: const CarebitBackendRuntime(
          androidDeviceKind: CarebitAndroidDeviceKind.physical,
          isWeb: false,
          targetPlatform: TargetPlatform.android,
        ),
        fitbitCallbackSessionStore: sessionStore,
        firebaseAuth: _FakeFirebaseAuth(
          currentUser: _FakeUser(<String?>['token-123']),
        ),
        delay: (_) async {},
        launchExternalUri: (_) async => true,
      );

      final Result<void> result = await controller.startFitbitConnection();

      expect(result.isFailure, isTrue);
      expect(
        result.errorOrNull,
        contains('Tried hosts: $_deployedFunctionsBaseUri, 127.0.0.1'),
      );
      expect(
        result.errorOrNull,
        contains('deployed Firebase Functions backend by default'),
      );
      expect(result.errorOrNull, contains('CAREBIT_BACKEND_HOST'));
      expect(repository.healthProbeHosts, <String>[
        _deployedFunctionsHost,
        '127.0.0.1',
      ]);
      expect(repository.authStartHosts, isEmpty);
      expect(await sessionStore.readPendingState(), isNull);
    },
  );

  test(
    'startFitbitConnection skips a reachable but misconfigured backend host',
    () async {
      rememberCarebitBackendHost('');
      final _FakeDeviceConnectionRepository
      repository = _FakeDeviceConnectionRepository(
        finalizeResponses: const <FitbitCallbackFinalizeResult>[],
        authStartResultsByHost: <String, Result<Uri>>{
          'healthy-host': ResultSuccess<Uri>(
            Uri.parse('https://fitbit.example/healthy'),
          ),
        },
        healthResponsesByHost: <String, Result<CarebitBackendHealthSnapshot>>{
          'misconfigured-host':
              const ResultSuccess<CarebitBackendHealthSnapshot>(
                CarebitBackendHealthSnapshot(
                  fitbitConfigured: false,
                  missingFitbitConfig: <String>['FITBIT_CLIENT_ID'],
                ),
              ),
          'healthy-host': const ResultSuccess<CarebitBackendHealthSnapshot>(
            CarebitBackendHealthSnapshot(fitbitConfigured: true),
          ),
        },
      );
      final ConnectDeviceController controller = ConnectDeviceController(
        deviceConnectionRepository: repository,
        fitbitCallbackSessionStore: _InMemoryFitbitCallbackSessionStore(),
        firebaseAuth: _FakeFirebaseAuth(
          currentUser: _FakeUser(<String?>['token-123']),
        ),
        backendHostsResolver: ({String? preferredHost}) => const <String>[
          'misconfigured-host',
          'healthy-host',
        ],
        delay: (_) async {},
        launchExternalUri: (_) async => true,
      );

      final Result<void> result = await controller.startFitbitConnection();

      expect(result.isSuccess, isTrue);
      expect(repository.healthProbeHosts, <String>[
        'misconfigured-host',
        'healthy-host',
      ]);
      expect(repository.authStartHosts, <String>['healthy-host']);
    },
  );
}

WatchData _buildWatchData() {
  return WatchData(
    userId: 'user-123',
    deviceId: 'device-123',
    deviceName: 'Pixel Watch',
    manufacturer: 'Google',
    connectedAt: DateTime.utc(2026, 1, 1),
    source: 'fitbit',
  );
}

class _FakeDeviceConnectionRepository extends DeviceConnectionRepository {
  _FakeDeviceConnectionRepository({
    required List<FitbitCallbackFinalizeResult> finalizeResponses,
    Map<String, Result<Uri>>? authStartResultsByHost,
    Map<String, Result<CarebitBackendHealthSnapshot>>? healthResponsesByHost,
    List<FitbitCallbackStatusSnapshot>? statusResponses,
  }) : _finalizeResponses = List<FitbitCallbackFinalizeResult>.from(
         finalizeResponses,
       ),
       _authStartResultsByHost = Map<String, Result<Uri>>.from(
         authStartResultsByHost ?? const <String, Result<Uri>>{},
       ),
       _healthResponsesByHost =
           Map<String, Result<CarebitBackendHealthSnapshot>>.from(
             healthResponsesByHost ??
                 const <String, Result<CarebitBackendHealthSnapshot>>{},
           ),
       _statusResponses = List<FitbitCallbackStatusSnapshot>.from(
         statusResponses ?? const <FitbitCallbackStatusSnapshot>[],
       );

  final List<FitbitCallbackFinalizeResult> _finalizeResponses;
  final Map<String, Result<Uri>> _authStartResultsByHost;
  final Map<String, Result<CarebitBackendHealthSnapshot>>
  _healthResponsesByHost;
  final List<FitbitCallbackStatusSnapshot> _statusResponses;

  final List<String> authStartHosts = <String>[];
  int finalizeCallCount = 0;
  final List<String> healthProbeHosts = <String>[];
  Uri? receivedEndpointUri;
  String? receivedCode;
  String? receivedFirebaseIdToken;
  String? receivedState;
  int statusCallCount = 0;

  @override
  Future<Result<Uri>> fetchFitbitAuthorizationUrl({
    required Uri endpointUri,
    String? state,
  }) async {
    authStartHosts.add(endpointUri.host);

    return _authStartResultsByHost[endpointUri.host] ??
        const ResultFailure<Uri>('No auth-start response queued.');
  }

  @override
  Future<FitbitCallbackFinalizeResult> finalizeFitbitConnection({
    required Uri endpointUri,
    required String code,
    required String firebaseIdToken,
    required String state,
  }) async {
    finalizeCallCount += 1;
    receivedEndpointUri = endpointUri;
    receivedCode = code;
    receivedFirebaseIdToken = firebaseIdToken;
    receivedState = state;

    if (_finalizeResponses.isEmpty) {
      return const FitbitCallbackFinalizePending(
        reason: FitbitCallbackFinalizePendingReason.retryableNetwork,
      );
    }

    return _finalizeResponses.removeAt(0);
  }

  @override
  Future<Result<FitbitCallbackStatusSnapshot>> fetchFitbitCallbackStatus({
    required Uri endpointUri,
    required String firebaseIdToken,
    required String state,
  }) async {
    statusCallCount += 1;

    if (_statusResponses.isEmpty) {
      return const ResultSuccess<FitbitCallbackStatusSnapshot>(
        FitbitCallbackStatusSnapshot(kind: FitbitCallbackStatusKind.processing),
      );
    }

    return ResultSuccess<FitbitCallbackStatusSnapshot>(
      _statusResponses.removeAt(0),
    );
  }

  @override
  Future<Result<CarebitBackendHealthSnapshot>> probeCarebitBackendHealth({
    required Uri endpointUri,
    Duration? timeout,
  }) async {
    healthProbeHosts.add(endpointUri.host);

    return _healthResponsesByHost[endpointUri.host] ??
        const ResultFailure<CarebitBackendHealthSnapshot>(
          'No health response queued.',
        );
  }
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth({required this.currentUser});

  @override
  final User? currentUser;

  @override
  Future<UserCredential> signInAnonymously() {
    throw UnimplementedError(
      'signInAnonymously should not be called in tests.',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser(List<String?> tokens) : _tokens = List<String?>.from(tokens);

  final List<String?> _tokens;
  final List<bool> getIdTokenCalls = <bool>[];

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    getIdTokenCalls.add(forceRefresh);

    final int tokenIndex = getIdTokenCalls.length - 1;
    if (tokenIndex >= _tokens.length) {
      return _tokens.isEmpty ? null : _tokens.last;
    }

    return _tokens[tokenIndex];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryFitbitCallbackSessionStore
    implements FitbitCallbackSessionStore {
  String? pendingState;
  String? pendingCode;
  String? pendingBackendHost;

  @override
  Future<void> clearPendingState() async {
    pendingBackendHost = null;
    pendingCode = null;
    pendingState = null;
  }

  @override
  Future<void> clearPendingStateIfMatches(String expectedState) async {
    if (pendingState == expectedState) {
      await clearPendingState();
    }
  }

  @override
  Future<bool> hasProcessedFingerprint(String fingerprint) async {
    return false;
  }

  @override
  Future<void> markProcessedFingerprint(String fingerprint) async {}

  @override
  Future<PendingFitbitCallbackSession?> readPendingCallbackSession() async {
    if (pendingState == null) {
      return null;
    }

    return PendingFitbitCallbackSession(
      backendHost: pendingBackendHost,
      code: pendingCode,
      state: pendingState!,
    );
  }

  @override
  Future<String?> readPendingState() async {
    return pendingState;
  }

  @override
  Future<void> savePendingCallbackSession(
    PendingFitbitCallbackSession session,
  ) async {
    pendingBackendHost = session.backendHost;
    pendingCode = session.code;
    pendingState = session.state;
  }

  @override
  Future<void> savePendingState(String state) async {
    pendingBackendHost = null;
    pendingCode = null;
    pendingState = state;
  }
}
