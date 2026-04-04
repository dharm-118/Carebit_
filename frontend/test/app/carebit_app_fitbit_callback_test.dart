import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/app.dart';
import 'package:frontend/app/fitbit_callback_coordinator.dart';
import 'package:frontend/app/fitbit_callback_session_store.dart';
import 'package:frontend/app/fitbit_link_coordinator.dart';
import 'package:frontend/features/connect_device/application/connect_device_controller.dart';
import 'package:frontend/features/health_metrics/application/connected_device_provider.dart';
import 'package:mobile_client/models/watch_data.dart';
import 'package:mobile_client/repositories/device_connection_repository.dart';

void main() {
  testWidgets(
    'recoverable callback timeout does not show a false snackbar and later resolves to success',
    (WidgetTester tester) async {
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      await sessionStore.savePendingState('state-1');

      final _TestFitbitLinkSource linkSource = _TestFitbitLinkSource();
      addTearDown(linkSource.dispose);
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
            hasPendingCallback: true,
            hasResumablePendingCallback: true,
          );
      final FitbitCallbackCoordinator coordinator = FitbitCallbackCoordinator(
        connectDeviceController: controller,
        sessionStore: sessionStore,
        delay: (_) async {},
        pendingRecoveryRetryDelay: Duration.zero,
      );
      addTearDown(coordinator.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            connectDeviceControllerProvider.overrideWith((ref) => controller),
            connectedFitbitDeviceProvider.overrideWith(
              (Ref ref) => Stream<WatchData?>.value(_buildWatchData()),
            ),
            fitbitCallbackCoordinatorProvider.overrideWithValue(coordinator),
            fitbitCallbackSessionStoreProvider.overrideWithValue(sessionStore),
          ],
          child: CarebitApp(linkCoordinator: linkSource),
        ),
      );
      await tester.pump();

      linkSource.emit(
        Uri.parse('carebit://fitbit-callback?code=oauth-code&state=state-1'),
      );
      await tester.pump();

      await tester.pump();
      await tester.pump();

      expect(find.text('Finishing Fitbit connection...'), findsNothing);
      expect(
        find.text(
          'Fitbit callback verification timed out. Start the connection again.',
        ),
        findsNothing,
      );
      expect(find.text('Health Report'), findsOneWidget);
      expect(find.text('Connected Fitbit Sense 2.'), findsOneWidget);
    },
  );

  testWidgets(
    'app startup resumes a saved pending callback session without a new deep link',
    (WidgetTester tester) async {
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      await sessionStore.savePendingCallbackSession(
        const PendingFitbitCallbackSession(
          code: 'oauth-code',
          state: 'state-1',
        ),
      );

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
            hasPendingCallback: true,
            hasResumablePendingCallback: true,
          );
      final FitbitCallbackCoordinator coordinator = FitbitCallbackCoordinator(
        connectDeviceController: controller,
        sessionStore: sessionStore,
        delay: (_) async {},
        pendingRecoveryRetryDelay: Duration.zero,
      );
      addTearDown(coordinator.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            connectDeviceControllerProvider.overrideWith((ref) => controller),
            connectedFitbitDeviceProvider.overrideWith(
              (Ref ref) => Stream<WatchData?>.value(_buildWatchData()),
            ),
            fitbitCallbackCoordinatorProvider.overrideWithValue(coordinator),
            fitbitCallbackSessionStoreProvider.overrideWithValue(sessionStore),
          ],
          child: CarebitApp(linkCoordinator: _TestFitbitLinkSource()),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Health Report'), findsOneWidget);
      expect(find.text('Connected Fitbit Sense 2.'), findsOneWidget);
      expect(await sessionStore.readPendingCallbackSession(), isNull);
      expect(controller.finalizeCallCount, 2);
    },
  );

  testWidgets(
    'duplicate startup and stream callbacks only finalize once at app level',
    (WidgetTester tester) async {
      final _InMemoryFitbitCallbackSessionStore sessionStore =
          _InMemoryFitbitCallbackSessionStore();
      await sessionStore.savePendingState('state-1');

      final Uri callbackUri = Uri.parse(
        'carebit://fitbit-callback?code=oauth-code&state=state-1',
      );
      final Completer<FitbitCallbackCompletion> finalizeCompleter =
          Completer<FitbitCallbackCompletion>();
      final _TestFitbitLinkSource linkSource = _TestFitbitLinkSource(
        startupUri: callbackUri,
      );
      addTearDown(linkSource.dispose);
      final _TestConnectDeviceController controller =
          _TestConnectDeviceController(
            finalizeResponses: <Future<FitbitCallbackCompletion>>[
              finalizeCompleter.future,
            ],
            hasPendingCallback: true,
            hasResumablePendingCallback: true,
          );
      final FitbitCallbackCoordinator coordinator = FitbitCallbackCoordinator(
        connectDeviceController: controller,
        sessionStore: sessionStore,
        delay: (_) async {},
        pendingRecoveryRetryDelay: Duration.zero,
      );
      addTearDown(coordinator.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            connectDeviceControllerProvider.overrideWith((ref) => controller),
            connectedFitbitDeviceProvider.overrideWith(
              (Ref ref) => Stream<WatchData?>.value(_buildWatchData()),
            ),
            fitbitCallbackCoordinatorProvider.overrideWithValue(coordinator),
            fitbitCallbackSessionStoreProvider.overrideWithValue(sessionStore),
          ],
          child: CarebitApp(linkCoordinator: linkSource),
        ),
      );
      await tester.pump();

      linkSource.emit(callbackUri);
      await tester.pump();
      expect(controller.finalizeCallCount, 1);

      finalizeCompleter.complete(
        FitbitCallbackCompletion.success(_buildWatchData()),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Health Report'), findsOneWidget);
      expect(find.text('Connected Fitbit Sense 2.'), findsOneWidget);
      expect(controller.finalizeCallCount, 1);
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

class _TestFitbitLinkSource implements FitbitLinkSource {
  _TestFitbitLinkSource({Uri? startupUri}) : _startupUri = startupUri;

  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();
  Uri? _startupUri;

  @override
  Object? get startupError => null;

  @override
  Stream<Uri> get uriStream => _controller.stream;

  void emit(Uri uri) {
    _controller.add(uri);
  }

  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Uri? takeStartupUri() {
    final Uri? startupUri = _startupUri;
    _startupUri = null;
    return startupUri;
  }
}

class _TestConnectDeviceController extends ConnectDeviceController {
  _TestConnectDeviceController({
    required List<Future<FitbitCallbackCompletion>> finalizeResponses,
    required bool hasPendingCallback,
    required bool hasResumablePendingCallback,
  }) : _finalizeResponses = List<Future<FitbitCallbackCompletion>>.from(
         finalizeResponses,
       ),
       _hasPendingCallback = hasPendingCallback,
       _hasResumablePendingCallback = hasResumablePendingCallback,
       super(
         deviceConnectionRepository: DeviceConnectionRepository(),
         fitbitCallbackSessionStore: _NoopFitbitCallbackSessionStore(),
         firebaseAuth: _FakeFirebaseAuth(currentUser: null),
       );

  final List<Future<FitbitCallbackCompletion>> _finalizeResponses;
  final bool _hasPendingCallback;
  final bool _hasResumablePendingCallback;

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
    return _hasPendingCallback;
  }

  @override
  Future<bool> hasResumablePendingFitbitCallback() async {
    return _hasResumablePendingCallback;
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
