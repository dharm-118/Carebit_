import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/fitbit_callback_coordinator.dart';
import 'package:frontend/app/fitbit_callback_session_store.dart';
import 'package:frontend/features/connect_device/application/connect_device_controller.dart';
import 'package:mobile_client/models/watch_data.dart';
import 'package:mobile_client/repositories/device_connection_repository.dart';

void main() {
  test(
    'duplicate startup and stream callbacks only finalize the Fitbit connection once',
    () async {
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      await sessionStore.savePendingState('state-1');

      final Completer<FitbitCallbackCompletion> finalizeCompleter =
          Completer<FitbitCallbackCompletion>();
      final _TestConnectDeviceController controller =
          _TestConnectDeviceController(
            finalizeResponses: <Future<FitbitCallbackCompletion>>[
              finalizeCompleter.future,
            ],
          );
      final FitbitCallbackCoordinator coordinator = FitbitCallbackCoordinator(
        connectDeviceController: controller,
        sessionStore: sessionStore,
        delay: (_) async {},
      );
      addTearDown(coordinator.dispose);
      final Uri callbackUri = Uri.parse(
        'carebit://fitbit-callback?code=oauth-code&state=state-1',
      );

      final Future<FitbitCallbackOutcome> firstOutcomeFuture = coordinator
          .process(callbackUri);
      await Future<void>.delayed(Duration.zero);
      final FitbitCallbackOutcome duplicateOutcome = await coordinator.process(
        callbackUri,
      );

      expect(duplicateOutcome.type, FitbitCallbackOutcomeType.duplicate);
      expect(coordinator.isFinalizing, isTrue);
      expect(controller.finalizeCallCount, 1);

      finalizeCompleter.complete(
        FitbitCallbackCompletion.success(_buildWatchData()),
      );
      final FitbitCallbackOutcome firstOutcome = await firstOutcomeFuture;

      expect(firstOutcome.type, FitbitCallbackOutcomeType.success);
      expect(coordinator.isFinalizing, isFalse);
      expect(controller.finalizeCallCount, 1);
    },
  );

  test(
    'mismatched and replayed Fitbit callback states are rejected without finalizing',
    () async {
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      final String replayedFingerprint = buildFitbitCallbackFingerprint(
        code: 'oauth-code',
        state: 'state-1',
      );
      await sessionStore.savePendingState('state-1');
      await sessionStore.markProcessedFingerprint(replayedFingerprint);

      final _TestConnectDeviceController controller =
          _TestConnectDeviceController(
            finalizeResponses: <Future<FitbitCallbackCompletion>>[],
          );
      final FitbitCallbackCoordinator coordinator = FitbitCallbackCoordinator(
        connectDeviceController: controller,
        sessionStore: sessionStore,
        delay: (_) async {},
      );
      addTearDown(coordinator.dispose);

      final FitbitCallbackOutcome mismatchedOutcome = await coordinator.process(
        Uri.parse(
          'carebit://fitbit-callback?code=oauth-code&state=other-state',
        ),
      );
      final FitbitCallbackOutcome replayedOutcome = await coordinator.process(
        Uri.parse('carebit://fitbit-callback?code=oauth-code&state=state-1'),
      );

      expect(mismatchedOutcome.type, FitbitCallbackOutcomeType.rejected);
      expect(replayedOutcome.type, FitbitCallbackOutcomeType.duplicate);
      expect(controller.finalizeCallCount, 0);
      expect(coordinator.isFinalizing, isFalse);
    },
  );

  test(
    'pending callback reconciliation delivers success later without clearing the session early',
    () async {
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      await sessionStore.savePendingState('state-1');

      final _TestConnectDeviceController controller =
          _TestConnectDeviceController(
            finalizeResponses: <Future<FitbitCallbackCompletion>>[
              Future<FitbitCallbackCompletion>.value(
                FitbitCallbackCompletion.pending(),
              ),
              Future<FitbitCallbackCompletion>.value(
                FitbitCallbackCompletion.success(_buildWatchData()),
              ),
            ],
          );
      final FitbitCallbackCoordinator coordinator = FitbitCallbackCoordinator(
        connectDeviceController: controller,
        sessionStore: sessionStore,
        delay: (_) async {},
        pendingRecoveryRetryDelay: Duration.zero,
      );
      addTearDown(coordinator.dispose);

      final FitbitCallbackOutcome initialOutcome = await coordinator.process(
        Uri.parse('carebit://fitbit-callback?code=oauth-code&state=state-1'),
      );

      expect(initialOutcome.type, FitbitCallbackOutcomeType.pending);
      expect(
        (await sessionStore.readPendingCallbackSession())?.code,
        'oauth-code',
      );

      await Future<void>.delayed(Duration.zero);

      final FitbitCallbackOutcome? deliveredOutcome = coordinator
          .takeDeliveredOutcome();
      expect(deliveredOutcome?.type, FitbitCallbackOutcomeType.success);
      expect(await sessionStore.readPendingCallbackSession(), isNull);
      expect(controller.finalizeCallCount, 2);
    },
  );
}

WatchData _buildWatchData() {
  return WatchData(
    userId: 'user-123',
    deviceId: 'device-123',
    deviceName: 'Fitbit Sense 2',
    manufacturer: 'Fitbit',
    connectedAt: DateTime.utc(2026, 4, 1),
    source: 'fitbit',
  );
}

class _TestConnectDeviceController extends ConnectDeviceController {
  _TestConnectDeviceController({
    required List<Future<FitbitCallbackCompletion>> finalizeResponses,
  }) : _finalizeResponses = List<Future<FitbitCallbackCompletion>>.from(
         finalizeResponses,
       ),
       super(
         deviceConnectionRepository: DeviceConnectionRepository(),
         fitbitCallbackSessionStore: _NoopFitbitCallbackSessionStore(),
         firebaseAuth: _FakeFirebaseAuth(currentUser: null),
       );

  final List<Future<FitbitCallbackCompletion>> _finalizeResponses;

  int finalizeCallCount = 0;

  @override
  Future<FitbitCallbackCompletion> finalizeFitbitCallback({
    required String code,
    required String state,
  }) {
    finalizeCallCount += 1;

    if (_finalizeResponses.isEmpty) {
      return Future<FitbitCallbackCompletion>.value(
        FitbitCallbackCompletion.failed('No queued Fitbit completion result.'),
      );
    }

    return _finalizeResponses.removeAt(0);
  }

  @override
  Future<bool> hasPendingFitbitCallback() async {
    return true;
  }

  @override
  Future<bool> hasResumablePendingFitbitCallback() async {
    return true;
  }
}

class _NoopFitbitCallbackSessionStore implements FitbitCallbackSessionStore {
  @override
  Future<void> clearPendingState() async {}

  @override
  Future<void> clearPendingStateIfMatches(String expectedState) async {}

  @override
  Future<bool> hasProcessedFingerprint(String fingerprint) async {
    return false;
  }

  @override
  Future<void> markProcessedFingerprint(String fingerprint) async {}

  @override
  Future<PendingFitbitCallbackSession?> readPendingCallbackSession() async {
    return null;
  }

  @override
  Future<String?> readPendingState() async {
    return null;
  }

  @override
  Future<void> savePendingCallbackSession(
    PendingFitbitCallbackSession session,
  ) async {}

  @override
  Future<void> savePendingState(String state) async {}
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth({required this.currentUser});

  @override
  final User? currentUser;

  @override
  Future<UserCredential> signInAnonymously() {
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryFitbitCallbackSessionStore
    implements FitbitCallbackSessionStore {
  String? pendingState;
  String? pendingCode;
  String? pendingBackendHost;
  final Set<String> processedFingerprints = <String>{};

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
    return processedFingerprints.contains(fingerprint);
  }

  @override
  Future<void> markProcessedFingerprint(String fingerprint) async {
    processedFingerprints.add(fingerprint);
  }

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
