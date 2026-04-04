import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_client/models/watch_data.dart';

import '../features/connect_device/application/connect_device_controller.dart';
import 'fitbit_callback_session_store.dart';
import 'fitbit_oauth.dart';

final fitbitCallbackCoordinatorProvider = Provider<FitbitCallbackCoordinator>((
  Ref ref,
) {
  final FitbitCallbackCoordinator coordinator = FitbitCallbackCoordinator(
    connectDeviceController: ref.read(connectDeviceControllerProvider.notifier),
    sessionStore: ref.watch(fitbitCallbackSessionStoreProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

enum FitbitCallbackCoordinatorState { idle, finalizing }

enum FitbitCallbackOutcomeType {
  duplicate,
  failed,
  ignored,
  pending,
  rejected,
  success,
}

class FitbitCallbackOutcome {
  const FitbitCallbackOutcome._(this.type, {this.device, this.message});

  final WatchData? device;
  final String? message;
  final FitbitCallbackOutcomeType type;

  factory FitbitCallbackOutcome.duplicate() {
    return const FitbitCallbackOutcome._(FitbitCallbackOutcomeType.duplicate);
  }

  factory FitbitCallbackOutcome.failed(String message) {
    return FitbitCallbackOutcome._(
      FitbitCallbackOutcomeType.failed,
      message: message,
    );
  }

  factory FitbitCallbackOutcome.ignored() {
    return const FitbitCallbackOutcome._(FitbitCallbackOutcomeType.ignored);
  }

  factory FitbitCallbackOutcome.pending() {
    return const FitbitCallbackOutcome._(FitbitCallbackOutcomeType.pending);
  }

  factory FitbitCallbackOutcome.rejected(String message) {
    return FitbitCallbackOutcome._(
      FitbitCallbackOutcomeType.rejected,
      message: message,
    );
  }

  factory FitbitCallbackOutcome.success(WatchData device) {
    return FitbitCallbackOutcome._(
      FitbitCallbackOutcomeType.success,
      device: device,
      message: 'Connected ${device.deviceName}.',
    );
  }

  bool get shouldRedirectToConnectDevice =>
      type == FitbitCallbackOutcomeType.failed ||
      type == FitbitCallbackOutcomeType.rejected;

  bool get shouldShowMessage => message != null && message!.trim().isNotEmpty;
}

class FitbitCallbackCoordinator extends ChangeNotifier {
  FitbitCallbackCoordinator({
    required ConnectDeviceController connectDeviceController,
    required FitbitCallbackSessionStore sessionStore,
    Future<void> Function(Duration)? delay,
    Duration? pendingRecoveryRetryDelay,
  }) : _connectDeviceController = connectDeviceController,
       _delay = delay ?? Future<void>.delayed,
       _pendingRecoveryRetryDelay =
           pendingRecoveryRetryDelay ?? const Duration(seconds: 5),
       _sessionStore = sessionStore;

  String? _activeFingerprint;
  FitbitCallbackOutcome? _deliveredOutcome;
  Future<void>? _pendingRecoveryTask;
  String? _pendingRecoveryFingerprint;
  FitbitCallbackCoordinatorState _state = FitbitCallbackCoordinatorState.idle;

  final ConnectDeviceController _connectDeviceController;
  final Future<void> Function(Duration) _delay;
  final Duration _pendingRecoveryRetryDelay;
  final FitbitCallbackSessionStore _sessionStore;

  bool _disposed = false;

  bool get isFinalizing => _state == FitbitCallbackCoordinatorState.finalizing;

  Future<bool> hasPendingCallbackSession() {
    return _connectDeviceController.hasPendingFitbitCallback();
  }

  Future<bool> hasResumablePendingCallbackSession() {
    return _connectDeviceController.hasResumablePendingFitbitCallback();
  }

  Future<FitbitCallbackOutcome> process(Uri uri) async {
    if (!isFitbitCallbackUri(uri)) {
      return FitbitCallbackOutcome.ignored();
    }

    final String? oauthError = _readTrimmed(uri.queryParameters['error']);
    final String? state = _readTrimmed(uri.queryParameters['state']);

    if (oauthError != null) {
      if (state != null) {
        await _sessionStore.clearPendingStateIfMatches(state);
      }

      return FitbitCallbackOutcome.rejected(
        'Fitbit sign-in failed: $oauthError',
      );
    }

    if (state == null) {
      return FitbitCallbackOutcome.rejected(
        'Fitbit sign-in did not return a valid OAuth state.',
      );
    }

    final String? code = _readTrimmed(uri.queryParameters['code']);
    if (code == null) {
      await _sessionStore.clearPendingStateIfMatches(state);
      return FitbitCallbackOutcome.rejected(
        'Fitbit sign-in did not return an authorization code.',
      );
    }

    final String fingerprint = buildFitbitCallbackFingerprint(
      code: code,
      state: state,
    );

    if (_isFingerprintAlreadyInFlight(fingerprint)) {
      return FitbitCallbackOutcome.duplicate();
    }

    if (await _sessionStore.hasProcessedFingerprint(fingerprint)) {
      return FitbitCallbackOutcome.duplicate();
    }

    final PendingFitbitCallbackSession? pendingSession = await _sessionStore
        .readPendingCallbackSession();
    if (pendingSession == null) {
      return FitbitCallbackOutcome.rejected(
        'This Fitbit callback is no longer active. Start the connection again.',
      );
    }

    if (pendingSession.state != state) {
      return FitbitCallbackOutcome.rejected(
        'Received an unexpected Fitbit callback state. Start the connection again.',
      );
    }

    final PendingFitbitCallbackSession updatedSession = pendingSession.copyWith(
      code: code,
    );
    await _sessionStore.savePendingCallbackSession(updatedSession);

    return _finalizePendingSession(
      fingerprint: fingerprint,
      session: updatedSession,
      startBackgroundRecoveryOnPending: true,
    );
  }

  Future<FitbitCallbackOutcome> resumePendingCallback() async {
    final PendingFitbitCallbackSession? session = await _sessionStore
        .readPendingCallbackSession();

    if (session == null || !session.hasCode) {
      return FitbitCallbackOutcome.ignored();
    }

    final String fingerprint = buildFitbitCallbackFingerprint(
      code: session.code!,
      state: session.state,
    );

    if (_isFingerprintAlreadyInFlight(fingerprint)) {
      return FitbitCallbackOutcome.pending();
    }

    if (await _sessionStore.hasProcessedFingerprint(fingerprint)) {
      await _sessionStore.clearPendingStateIfMatches(session.state);
      return FitbitCallbackOutcome.duplicate();
    }

    return _finalizePendingSession(
      fingerprint: fingerprint,
      session: session,
      startBackgroundRecoveryOnPending: true,
    );
  }

  FitbitCallbackOutcome? takeDeliveredOutcome() {
    final FitbitCallbackOutcome? deliveredOutcome = _deliveredOutcome;
    _deliveredOutcome = null;
    return deliveredOutcome;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _continuePendingRecovery(String fingerprint) async {
    try {
      while (!_disposed) {
        await _delay(_pendingRecoveryRetryDelay);
        if (_disposed) {
          return;
        }

        final PendingFitbitCallbackSession? session = await _sessionStore
            .readPendingCallbackSession();
        if (session == null || !session.hasCode) {
          return;
        }

        final String currentFingerprint = buildFitbitCallbackFingerprint(
          code: session.code!,
          state: session.state,
        );
        if (currentFingerprint != fingerprint) {
          return;
        }

        final FitbitCallbackOutcome outcome = await _finalizePendingSession(
          fingerprint: currentFingerprint,
          session: session,
          startBackgroundRecoveryOnPending: false,
        );

        if (outcome.type == FitbitCallbackOutcomeType.pending) {
          continue;
        }

        _deliveredOutcome = outcome;
        if (!_disposed) {
          notifyListeners();
        }
        return;
      }
    } finally {
      _pendingRecoveryTask = null;
      _pendingRecoveryFingerprint = null;
    }
  }

  Future<FitbitCallbackOutcome> _finalizePendingSession({
    required String fingerprint,
    required PendingFitbitCallbackSession session,
    required bool startBackgroundRecoveryOnPending,
  }) async {
    _setState(
      FitbitCallbackCoordinatorState.finalizing,
      activeFingerprint: fingerprint,
    );

    try {
      final FitbitCallbackCompletion result = await _connectDeviceController
          .finalizeFitbitCallback(code: session.code!, state: session.state);

      switch (result.type) {
        case FitbitCallbackCompletionType.success:
          final WatchData device = result.device!;
          await _sessionStore.markProcessedFingerprint(fingerprint);
          await _sessionStore.clearPendingStateIfMatches(session.state);
          return FitbitCallbackOutcome.success(device);
        case FitbitCallbackCompletionType.failed:
          await _sessionStore.clearPendingStateIfMatches(session.state);
          return FitbitCallbackOutcome.failed(
            result.message ?? 'Could not finish Fitbit sign-in.',
          );
        case FitbitCallbackCompletionType.pending:
          if (startBackgroundRecoveryOnPending) {
            _schedulePendingRecovery(fingerprint);
          }
          return FitbitCallbackOutcome.pending();
      }
    } catch (error) {
      await _sessionStore.clearPendingStateIfMatches(session.state);
      return FitbitCallbackOutcome.failed(
        'Could not finish Fitbit sign-in: ${fitbitUserVisibleError(error)}',
      );
    } finally {
      _setState(FitbitCallbackCoordinatorState.idle);
    }
  }

  bool _isFingerprintAlreadyInFlight(String fingerprint) {
    if (isFinalizing && _activeFingerprint == fingerprint) {
      return true;
    }

    return _pendingRecoveryTask != null &&
        _pendingRecoveryFingerprint == fingerprint;
  }

  void _schedulePendingRecovery(String fingerprint) {
    if (_pendingRecoveryTask != null) {
      return;
    }

    _pendingRecoveryFingerprint = fingerprint;
    _pendingRecoveryTask = _continuePendingRecovery(fingerprint);
  }

  void _setState(
    FitbitCallbackCoordinatorState state, {
    String? activeFingerprint,
  }) {
    _state = state;
    _activeFingerprint = activeFingerprint;
    notifyListeners();
  }
}

String? _readTrimmed(String? value) {
  if (value == null) {
    return null;
  }

  final String normalizedValue = value.trim();
  return normalizedValue.isEmpty ? null : normalizedValue;
}
