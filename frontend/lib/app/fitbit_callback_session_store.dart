import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _pendingStateKey = 'carebit.fitbit.pending_state';
const String _pendingCallbackSessionKey =
    'carebit.fitbit.pending_callback_session';
const String _processedFingerprintsKey =
    'carebit.fitbit.processed_fingerprints';
const int _processedFingerprintLimit = 12;

final fitbitCallbackSessionStoreProvider = Provider<FitbitCallbackSessionStore>((
  Ref ref,
) {
  throw StateError(
    'fitbitCallbackSessionStoreProvider must be overridden at application startup.',
  );
});

abstract interface class FitbitCallbackSessionStore {
  Future<void> clearPendingState();

  Future<void> clearPendingStateIfMatches(String expectedState);

  Future<bool> hasProcessedFingerprint(String fingerprint);

  Future<void> markProcessedFingerprint(String fingerprint);

  Future<PendingFitbitCallbackSession?> readPendingCallbackSession();

  Future<String?> readPendingState();

  Future<void> savePendingCallbackSession(PendingFitbitCallbackSession session);

  Future<void> savePendingState(String state);
}

class PendingFitbitCallbackSession {
  const PendingFitbitCallbackSession({
    required this.state,
    this.code,
    this.backendHost,
  });

  final String state;
  final String? code;
  final String? backendHost;

  bool get hasCode => (code?.trim() ?? '').isNotEmpty;

  PendingFitbitCallbackSession copyWith({
    String? code,
    String? state,
    String? backendHost,
  }) {
    return PendingFitbitCallbackSession(
      backendHost: backendHost ?? this.backendHost,
      code: code ?? this.code,
      state: state ?? this.state,
    );
  }

  Map<String, String> toJson() {
    final Map<String, String> payload = <String, String>{'state': state};
    final String normalizedCode = code?.trim() ?? '';
    final String normalizedBackendHost = backendHost?.trim() ?? '';

    if (normalizedCode.isNotEmpty) {
      payload['code'] = normalizedCode;
    }

    if (normalizedBackendHost.isNotEmpty) {
      payload['backendHost'] = normalizedBackendHost;
    }

    return payload;
  }

  static PendingFitbitCallbackSession? fromJsonObject(Object? value) {
    if (value is! Map) {
      return null;
    }

    final String? state = _normalizeSessionString(value['state']);
    if (state == null) {
      return null;
    }

    return PendingFitbitCallbackSession(
      backendHost: _normalizeSessionString(value['backendHost']),
      code: _normalizeSessionString(value['code']),
      state: state,
    );
  }
}

class SharedPreferencesFitbitCallbackSessionStore
    implements FitbitCallbackSessionStore {
  SharedPreferencesFitbitCallbackSessionStore({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  @override
  Future<void> clearPendingState() async {
    await _sharedPreferences.remove(_pendingCallbackSessionKey);
    await _sharedPreferences.remove(_pendingStateKey);
  }

  @override
  Future<void> clearPendingStateIfMatches(String expectedState) async {
    final String? pendingState = readPendingStateSync();
    if (pendingState != expectedState) {
      return;
    }

    await clearPendingState();
  }

  @override
  Future<bool> hasProcessedFingerprint(String fingerprint) async {
    return _processedFingerprintsSync().contains(fingerprint);
  }

  @override
  Future<void> markProcessedFingerprint(String fingerprint) async {
    final List<String> fingerprints = <String>[
      fingerprint,
      ..._processedFingerprintsSync().where(
        (String entry) => entry != fingerprint,
      ),
    ];
    final List<String> trimmedFingerprints = fingerprints
        .take(_processedFingerprintLimit)
        .toList(growable: false);
    await _sharedPreferences.setStringList(
      _processedFingerprintsKey,
      trimmedFingerprints,
    );
  }

  @override
  Future<PendingFitbitCallbackSession?> readPendingCallbackSession() async {
    return readPendingCallbackSessionSync();
  }

  @override
  Future<String?> readPendingState() async {
    return readPendingStateSync();
  }

  @override
  Future<void> savePendingCallbackSession(
    PendingFitbitCallbackSession session,
  ) async {
    final PendingFitbitCallbackSession normalizedSession =
        PendingFitbitCallbackSession(
          backendHost: _normalizeSessionString(session.backendHost),
          code: _normalizeSessionString(session.code),
          state: _normalizeRequiredState(session.state),
        );

    await _sharedPreferences.setString(
      _pendingCallbackSessionKey,
      jsonEncode(normalizedSession.toJson()),
    );
    await _sharedPreferences.setString(
      _pendingStateKey,
      normalizedSession.state,
    );
  }

  @override
  Future<void> savePendingState(String state) async {
    await savePendingCallbackSession(
      PendingFitbitCallbackSession(state: state),
    );
  }

  PendingFitbitCallbackSession? readPendingCallbackSessionSync() {
    final String? rawSession = _sharedPreferences.getString(
      _pendingCallbackSessionKey,
    );

    if (rawSession != null && rawSession.trim().isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(rawSession);
        final PendingFitbitCallbackSession? decodedSession =
            PendingFitbitCallbackSession.fromJsonObject(decoded);

        if (decodedSession != null) {
          return decodedSession;
        }
      } catch (_) {
        // Fall back to the legacy state-only key if the session payload is invalid.
      }
    }

    final String? state = _normalizeSessionString(
      _sharedPreferences.getString(_pendingStateKey),
    );
    if (state == null) {
      return null;
    }

    return PendingFitbitCallbackSession(state: state);
  }

  String? readPendingStateSync() {
    return readPendingCallbackSessionSync()?.state;
  }

  List<String> _processedFingerprintsSync() {
    return _sharedPreferences
            .getStringList(_processedFingerprintsKey)
            ?.where((String entry) => entry.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
  }
}

String buildFitbitCallbackFingerprint({
  required String code,
  required String state,
}) {
  return _stableFingerprintHash('$state::$code');
}

String generateFitbitOAuthState() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(
    24,
    (_) => random.nextInt(256),
    growable: false,
  );
  return base64UrlEncode(bytes).replaceAll('=', '');
}

String _stableFingerprintHash(String rawValue) {
  const int offsetBasis = 0xcbf29ce484222325;
  const int fnvPrime = 0x100000001b3;
  int hash = offsetBasis;

  for (final int byte in utf8.encode(rawValue)) {
    hash ^= byte;
    hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
  }

  return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
}

String _normalizeRequiredState(String state) {
  final String? normalizedState = _normalizeSessionString(state);

  if (normalizedState == null) {
    throw StateError('Fitbit OAuth state must not be empty.');
  }

  return normalizedState;
}

String? _normalizeSessionString(Object? value) {
  if (value is! String) {
    return null;
  }

  final String normalizedValue = value.trim();
  return normalizedValue.isEmpty ? null : normalizedValue;
}
