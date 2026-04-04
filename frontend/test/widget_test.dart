import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/fitbit_callback_session_store.dart';
import 'package:frontend/app/router.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/features/connect_device/application/connect_device_controller.dart';
import 'package:mobile_client/constants/app_constants.dart';
import 'package:mobile_client/constants/route_paths.dart';
import 'package:mobile_client/repositories/device_connection_repository.dart';

void main() {
  testWidgets('splash redirects to connect device screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          fitbitCallbackSessionStoreProvider.overrideWithValue(
            _NoopFitbitCallbackSessionStore(),
          ),
          connectDeviceControllerProvider.overrideWith(
            (ref) => _FakeConnectDeviceController(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: buildAppRouter(initialLocation: RoutePaths.splash),
        ),
      ),
    );

    expect(find.text('Carebit'), findsOneWidget);
    await tester.pump(AppConstants.splashRedirectDelay);
    await tester.pumpAndSettle();

    expect(find.text('Connect Device'), findsWidgets);
  });

  test('fitbitCallbackSessionStoreProvider resolves from startup override', () {
    final _NoopFitbitCallbackSessionStore store =
        _NoopFitbitCallbackSessionStore();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        fitbitCallbackSessionStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(fitbitCallbackSessionStoreProvider), same(store));
  });

  test('fitbitCallbackSessionStoreProvider throws without override', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(fitbitCallbackSessionStoreProvider),
      throwsA(
        isA<StateError>().having(
          (StateError e) => e.message,
          'message',
          contains('must be overridden at application startup'),
        ),
      ),
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeConnectDeviceController extends ConnectDeviceController {
  _FakeConnectDeviceController()
    : super(
        deviceConnectionRepository: DeviceConnectionRepository(),
        fitbitCallbackSessionStore: _NoopFitbitCallbackSessionStore(),
        firebaseAuth: _FakeFirebaseAuth(),
      );
}

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopFitbitCallbackSessionStore implements FitbitCallbackSessionStore {
  @override
  Future<void> clearPendingState() async {}

  @override
  Future<void> clearPendingStateIfMatches(String expectedState) async {}

  @override
  Future<bool> hasProcessedFingerprint(String fingerprint) async => false;

  @override
  Future<void> markProcessedFingerprint(String fingerprint) async {}

  @override
  Future<PendingFitbitCallbackSession?> readPendingCallbackSession() async =>
      null;

  @override
  Future<String?> readPendingState() async => null;

  @override
  Future<void> savePendingCallbackSession(
    PendingFitbitCallbackSession session,
  ) async {}

  @override
  Future<void> savePendingState(String state) async {}
}
