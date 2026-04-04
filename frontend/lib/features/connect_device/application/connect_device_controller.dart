import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_client/core/result.dart';
import 'package:mobile_client/models/watch_data.dart';
import 'package:mobile_client/repositories/device_connection_repository.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/carebit_backend_runtime.dart';
import '../../../app/fitbit_callback_session_store.dart';
import '../../../app/fitbit_oauth.dart';

// ---------------------------------------------------------------------------
// Completion types (controller-level)
// ---------------------------------------------------------------------------

enum FitbitCallbackCompletionType { success, failed, pending }

class FitbitCallbackCompletion {
  const FitbitCallbackCompletion._({
    required this.type,
    this.device,
    this.message,
  });

  final FitbitCallbackCompletionType type;
  final WatchData? device;
  final String? message;

  factory FitbitCallbackCompletion.success(WatchData device) =>
      FitbitCallbackCompletion._(
        type: FitbitCallbackCompletionType.success,
        device: device,
      );

  factory FitbitCallbackCompletion.failed(String message) =>
      FitbitCallbackCompletion._(
        type: FitbitCallbackCompletionType.failed,
        message: message,
      );

  factory FitbitCallbackCompletion.pending() =>
      const FitbitCallbackCompletion._(
        type: FitbitCallbackCompletionType.pending,
      );
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ConnectDeviceState {
  const ConnectDeviceState({
    this.isConnecting = false,
    this.isHandlingCallback = false,
    this.errorMessage,
  });

  final bool isConnecting;
  final bool isHandlingCallback;
  final String? errorMessage;

  ConnectDeviceState copyWith({
    bool? isConnecting,
    bool? isHandlingCallback,
    String? errorMessage,
  }) {
    return ConnectDeviceState(
      isConnecting: isConnecting ?? this.isConnecting,
      isHandlingCallback: isHandlingCallback ?? this.isHandlingCallback,
      errorMessage: errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class ConnectDeviceController extends StateNotifier<ConnectDeviceState> {
  ConnectDeviceController({
    required DeviceConnectionRepository deviceConnectionRepository,
    required FitbitCallbackSessionStore fitbitCallbackSessionStore,
    required FirebaseAuth firebaseAuth,
    CarebitBackendRuntime? backendRuntime,
    List<String> Function({String? preferredHost})? backendHostsResolver,
    Future<bool> Function(Uri)? launchExternalUri,
    Future<void> Function(Duration)? delay,
    Duration? callbackFinalizeRetryInterval,
    Duration? callbackRecoveryWindow,
    Duration? callbackStatusPollInterval,
  }) : _repository = deviceConnectionRepository,
       _sessionStore = fitbitCallbackSessionStore,
       _firebaseAuth = firebaseAuth,
       _backendRuntime = backendRuntime,
       _backendHostsResolver = backendHostsResolver,
       _launchExternalUri = launchExternalUri ?? _defaultLaunch,
       _delay = delay ?? Future<void>.delayed,
       _callbackRecoveryWindow =
           callbackRecoveryWindow ?? const Duration(seconds: 30),
       _callbackStatusPollInterval =
           callbackStatusPollInterval ?? const Duration(seconds: 2),
       super(const ConnectDeviceState());

  final DeviceConnectionRepository _repository;
  final FitbitCallbackSessionStore _sessionStore;
  final FirebaseAuth _firebaseAuth;
  final CarebitBackendRuntime? _backendRuntime;
  final List<String> Function({String? preferredHost})? _backendHostsResolver;
  final Future<bool> Function(Uri) _launchExternalUri;
  final Future<void> Function(Duration) _delay;
  final Duration _callbackRecoveryWindow;
  final Duration _callbackStatusPollInterval;

  static Future<bool> _defaultLaunch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Updates the connecting state from the UI layer.
  void setConnecting({required bool isConnecting, String? errorMessage}) {
    state = state.copyWith(
      isConnecting: isConnecting,
      errorMessage: errorMessage,
    );
  }

  /// Returns true if there is an active callback in progress.
  Future<bool> hasPendingFitbitCallback() async => state.isHandlingCallback;

  /// Returns true if there is a resumable pending callback in the session store.
  Future<bool> hasResumablePendingFitbitCallback() async {
    final PendingFitbitCallbackSession? session = await _sessionStore
        .readPendingCallbackSession();
    return session != null && session.hasCode;
  }

  /// Starts the Fitbit OAuth flow: probes hosts, gets auth URL, launches browser.
  Future<Result<void>> startFitbitConnection() async {
    final CarebitBackendRuntime runtime =
        _backendRuntime ?? CarebitBackendRuntime.currentPlatform();
    final String? preferred = preferredCarebitBackendHost();
    final List<String> hosts = _backendHostsResolver != null
        ? _backendHostsResolver(preferredHost: preferred)
        : carebitBackendHosts(preferredHost: preferred, runtime: runtime);

    if (hosts.isEmpty) {
      return Result.failure(
        fitbitNoBackendHostConfiguredMessage(runtime: runtime),
      );
    }

    String? workingHost;
    final List<String> attempted = <String>[];
    String? lastError;

    for (final String host in hosts) {
      attempted.add(host);
      final Result<CarebitBackendHealthSnapshot> health = await _repository
          .probeCarebitBackendHealth(endpointUri: carebitHealthUri(host));
      if (health.isFailure) {
        lastError = health.errorOrNull;
        continue;
      }
      final CarebitBackendHealthSnapshot snapshot = health.dataOrNull!;
      if (!snapshot.fitbitConfigured) {
        lastError = fitbitBackendConfigurationErrorMessage(
          host: host,
          missing: snapshot.missingFitbitConfig,
        );
        continue;
      }
      workingHost = host;
      break;
    }

    if (workingHost == null) {
      return Result.failure(
        fitbitAuthStartHostResolutionErrorMessage(
          attemptedHosts: attempted,
          lastError: lastError,
        ),
      );
    }

    rememberCarebitBackendHost(workingHost);

    final String oauthState = generateFitbitOAuthState();
    await _sessionStore.savePendingCallbackSession(
      PendingFitbitCallbackSession(state: oauthState, backendHost: workingHost),
    );

    final Result<Uri> authResult = await _repository
        .fetchFitbitAuthorizationUrl(
          endpointUri: fitbitAuthStartJsonUri(workingHost),
          state: oauthState,
        );

    if (authResult.isFailure) {
      await _sessionStore.clearPendingState();
      return Result.failure(
        authResult.errorOrNull ?? 'Failed to get Fitbit authorization URL.',
      );
    }

    final Uri authUri = authResult.dataOrNull!;
    final bool launched = await _launchExternalUri(authUri);
    if (!launched) {
      await _sessionStore.clearPendingState();
      return Result.failure('Could not open Fitbit login page.');
    }

    return Result.voidSuccess;
  }

  /// Finalizes a Fitbit OAuth callback given the OAuth code and state.
  Future<FitbitCallbackCompletion> finalizeFitbitCallback({
    required String code,
    required String state,
  }) async {
    this.state = this.state.copyWith(
      errorMessage: null,
      isHandlingCallback: true,
    );

    try {
      final String? token = await _getFirebaseIdToken();
      if (token == null) {
        return FitbitCallbackCompletion.failed(
          'Firebase ID token was unavailable after refresh.',
        );
      }

      final PendingFitbitCallbackSession? session = await _sessionStore
          .readPendingCallbackSession();
      final String? backendHost =
          session?.backendHost ?? preferredCarebitBackendHost();

      if (backendHost == null) {
        return FitbitCallbackCompletion.failed(
          'No Carebit backend host is available to complete Fitbit sign-in.',
        );
      }

      rememberCarebitBackendHost(backendHost);

      final FitbitCallbackFinalizeResult result = await _repository
          .finalizeFitbitConnection(
            endpointUri: fitbitAuthCallbackUri(backendHost),
            code: code,
            firebaseIdToken: token,
            state: state,
          );

      switch (result) {
        case FitbitCallbackFinalizeSuccess s:
          return FitbitCallbackCompletion.success(s.device);
        case FitbitCallbackFinalizeFailure f:
          return FitbitCallbackCompletion.failed(f.message);
        case FitbitCallbackFinalizePending _:
          return _pollCallbackStatus(
            backendHost: backendHost,
            firebaseIdToken: token,
            state: state,
          );
      }
    } finally {
      this.state = this.state.copyWith(isHandlingCallback: false);
    }
  }

  /// Resumes a pending callback session stored from a previous attempt.
  Future<FitbitCallbackCompletion> resumePendingFitbitCallback() async {
    final PendingFitbitCallbackSession? session = await _sessionStore
        .readPendingCallbackSession();

    if (session == null || !session.hasCode) {
      return FitbitCallbackCompletion.failed(
        'Fitbit sign-in session could not be resumed. Start the connection again.',
      );
    }

    return finalizeFitbitCallback(code: session.code!, state: session.state);
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  Future<String?> _getFirebaseIdToken() async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) return null;

    final String? token = await user.getIdToken(false);
    if (token != null && token.trim().isNotEmpty) return token;

    final String? refreshed = await user.getIdToken(true);
    if (refreshed != null && refreshed.trim().isNotEmpty) return refreshed;

    return null;
  }

  Future<FitbitCallbackCompletion> _pollCallbackStatus({
    required String backendHost,
    required String firebaseIdToken,
    required String state,
  }) async {
    final DateTime deadline = DateTime.now().add(_callbackRecoveryWindow);
    final Uri statusUri = fitbitAuthCallbackStatusUri(backendHost);

    while (DateTime.now().isBefore(deadline)) {
      await _delay(_callbackStatusPollInterval);

      final Result<FitbitCallbackStatusSnapshot> statusResult =
          await _repository.fetchFitbitCallbackStatus(
            endpointUri: statusUri,
            firebaseIdToken: firebaseIdToken,
            state: state,
          );

      if (statusResult.isFailure) {
        break;
      }

      final FitbitCallbackStatusSnapshot snapshot = statusResult.dataOrNull!;
      switch (snapshot.kind) {
        case FitbitCallbackStatusKind.succeeded:
          return FitbitCallbackCompletion.success(snapshot.device!);
        case FitbitCallbackStatusKind.failed:
          return FitbitCallbackCompletion.failed(
            snapshot.message ?? 'Fitbit callback finalization failed.',
          );
        case FitbitCallbackStatusKind.processing:
          continue;
      }
    }

    return FitbitCallbackCompletion.pending();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final StateNotifierProvider<ConnectDeviceController, ConnectDeviceState>
connectDeviceControllerProvider =
    StateNotifierProvider<ConnectDeviceController, ConnectDeviceState>(
      (ref) => ConnectDeviceController(
        deviceConnectionRepository: DeviceConnectionRepository(),
        fitbitCallbackSessionStore: ref.watch(
          fitbitCallbackSessionStoreProvider,
        ),
        firebaseAuth: FirebaseAuth.instance,
      ),
    );
