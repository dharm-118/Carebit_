import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/result.dart';
import '../dto/device_dto.dart';
import '../models/watch_data.dart';
import '../services/fitbit_api_service.dart';

// ---------------------------------------------------------------------------
// Finalize result types
// ---------------------------------------------------------------------------

sealed class FitbitCallbackFinalizeResult {
  const FitbitCallbackFinalizeResult();
}

final class FitbitCallbackFinalizeSuccess extends FitbitCallbackFinalizeResult {
  const FitbitCallbackFinalizeSuccess(this.device);

  final WatchData device;
}

enum FitbitCallbackFinalizePendingReason {
  retryableNetwork,
  processingBackend,
}

final class FitbitCallbackFinalizePending extends FitbitCallbackFinalizeResult {
  const FitbitCallbackFinalizePending({required this.reason});

  final FitbitCallbackFinalizePendingReason reason;
}

final class FitbitCallbackFinalizeFailure extends FitbitCallbackFinalizeResult {
  const FitbitCallbackFinalizeFailure(this.message);

  final String message;
}

// ---------------------------------------------------------------------------
// Status snapshot types
// ---------------------------------------------------------------------------

enum FitbitCallbackStatusKind { processing, succeeded, failed }

class FitbitCallbackStatusSnapshot {
  const FitbitCallbackStatusSnapshot({
    required this.kind,
    this.device,
    this.message,
  });

  final FitbitCallbackStatusKind kind;
  final WatchData? device;
  final String? message;
}

// ---------------------------------------------------------------------------
// Backend health snapshot
// ---------------------------------------------------------------------------

class CarebitBackendHealthSnapshot {
  const CarebitBackendHealthSnapshot({
    required this.fitbitConfigured,
    this.missingFitbitConfig = const <String>[],
  });

  final bool fitbitConfigured;
  final List<String> missingFitbitConfig;
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Repository responsible for connection-related operations.
class DeviceConnectionRepository {
  DeviceConnectionRepository({
    FitbitApiService? apiService,
    http.Client? client,
  }) : _apiService = apiService ?? const FitbitApiService(),
       _client = client ?? http.Client();

  final FitbitApiService _apiService;
  final http.Client _client;

  static const Duration _defaultTimeout = Duration(seconds: 30);

  // -------------------------------------------------------------------------
  // Legacy methods (used by existing screens / controller code)
  // -------------------------------------------------------------------------

  /// Requests OAuth start URL from backend.
  Future<Result<String>> getFitbitAuthorizationUrl() {
    return _apiService.fetchAuthorizationUrl();
  }

  /// Exchanges OAuth authorization code through backend.
  Future<Result<Map<String, dynamic>>> completeOAuthCallback(String code) {
    return _apiService.exchangeOAuthCode(code);
  }

  /// Gets connected devices after successful OAuth.
  Future<Result<List<DeviceDto>>> getConnectedDevices() {
    return _apiService.fetchConnectedDevices();
  }

  // -------------------------------------------------------------------------
  // New endpoint-URI–based methods
  // -------------------------------------------------------------------------

  /// Probes backend health and Fitbit configuration.
  Future<Result<CarebitBackendHealthSnapshot>> probeCarebitBackendHealth({
    required Uri endpointUri,
    Duration? timeout,
  }) async {
    try {
      final http.Response response = await _client
          .get(endpointUri)
          .timeout(timeout ?? _defaultTimeout);

      if (_isHtmlResponse(response)) {
        return Result.failure(
          'Received unexpected HTML response from health (HTTP ${response.statusCode}).',
        );
      }

      if (response.statusCode != 200) {
        return Result.failure(
          'Could not reach the Carebit backend health endpoint: HTTP ${response.statusCode}.',
        );
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return Result.failure('Malformed health response from backend.');
      }

      final bool ok = decoded['ok'] == true;
      final bool fitbitConfigured = decoded['fitbitConfigured'] == true;
      final List<String> missing = _extractStringList(decoded['fitbitMissingConfig']);

      if (!ok) {
        return Result.failure('Backend health check returned ok=false.');
      }

      return Result.success(
        CarebitBackendHealthSnapshot(
          fitbitConfigured: fitbitConfigured,
          missingFitbitConfig: missing,
        ),
      );
    } catch (error) {
      return Result.failure(
        'Could not reach the Carebit backend health endpoint: $error',
      );
    }
  }

  /// Requests a Fitbit OAuth authorization URL from the backend.
  Future<Result<Uri>> fetchFitbitAuthorizationUrl({
    required Uri endpointUri,
    String? state,
  }) async {
    try {
      final Uri requestUri = state != null
          ? endpointUri.replace(
              queryParameters: <String, String>{
                ...endpointUri.queryParameters,
                'state': state,
              },
            )
          : endpointUri;

      final http.Response response = await _client
          .get(requestUri)
          .timeout(_defaultTimeout);

      if (_isHtmlResponse(response)) {
        return Result.failure(
          'Received unexpected HTML response from fitbitAuthStart (HTTP ${response.statusCode}).',
        );
      }

      if (response.statusCode != 200) {
        return Result.failure(
          'Failed to start Fitbit OAuth: HTTP ${response.statusCode}.',
        );
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return Result.failure('Malformed auth-start response from backend.');
      }

      final String? authUrl =
          decoded['authUrl']?.toString() ?? decoded['url']?.toString();
      if (authUrl == null || authUrl.isEmpty) {
        return Result.failure('Backend did not return a valid auth URL.');
      }

      final Uri? parsedUri = Uri.tryParse(authUrl);
      if (parsedUri == null) {
        return Result.failure('Backend returned an invalid auth URL: $authUrl');
      }

      return Result.success(parsedUri);
    } catch (error) {
      return Result.failure('OAuth start error: $error');
    }
  }

  /// Finalizes a Fitbit OAuth callback by exchanging code + Firebase token.
  Future<FitbitCallbackFinalizeResult> finalizeFitbitConnection({
    required Uri endpointUri,
    required String code,
    required String firebaseIdToken,
    required String state,
  }) async {
    try {
      final Uri requestUri = endpointUri.replace(
        queryParameters: <String, String>{
          'code': code,
          'state': state,
        },
      );

      final http.Response response = await _client
          .get(
            requestUri,
            headers: <String, String>{
              'Authorization': 'Bearer $firebaseIdToken',
            },
          )
          .timeout(_defaultTimeout);

      if (_isHtmlResponse(response)) {
        return FitbitCallbackFinalizeFailure(
          'Received unexpected HTML response from fitbitAuthCallback (HTTP ${response.statusCode}).',
        );
      }

      if (response.statusCode == 202) {
        return const FitbitCallbackFinalizePending(
          reason: FitbitCallbackFinalizePendingReason.processingBackend,
        );
      }

      if (response.statusCode != 200) {
        final String message = _extractErrorMessage(
          response.body,
          fallback: 'Fitbit callback failed: HTTP ${response.statusCode}.',
        );
        return FitbitCallbackFinalizeFailure(message);
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const FitbitCallbackFinalizeFailure(
          'Malformed finalize response from backend.',
        );
      }

      final WatchData device = WatchData.fromJson(decoded);
      return FitbitCallbackFinalizeSuccess(device);
    } on TimeoutException {
      return const FitbitCallbackFinalizePending(
        reason: FitbitCallbackFinalizePendingReason.retryableNetwork,
      );
    } catch (error) {
      return FitbitCallbackFinalizeFailure('Callback error: $error');
    }
  }

  /// Polls the callback status endpoint.
  Future<Result<FitbitCallbackStatusSnapshot>> fetchFitbitCallbackStatus({
    required Uri endpointUri,
    required String firebaseIdToken,
    required String state,
  }) async {
    try {
      final Uri requestUri = endpointUri.replace(
        queryParameters: <String, String>{'state': state},
      );

      final http.Response response = await _client
          .get(
            requestUri,
            headers: <String, String>{
              'Authorization': 'Bearer $firebaseIdToken',
            },
          )
          .timeout(_defaultTimeout);

      if (_isHtmlResponse(response)) {
        return Result.failure(
          'Received unexpected HTML response from fitbitAuthCallbackStatus (HTTP ${response.statusCode}).',
        );
      }

      if (response.statusCode != 200) {
        return Result.failure(
          'Status check failed: HTTP ${response.statusCode}.',
        );
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return Result.failure('Malformed status response from backend.');
      }

      final String statusStr = decoded['status']?.toString() ?? '';
      final FitbitCallbackStatusKind kind = switch (statusStr) {
        'succeeded' => FitbitCallbackStatusKind.succeeded,
        'failed' => FitbitCallbackStatusKind.failed,
        _ => FitbitCallbackStatusKind.processing,
      };

      WatchData? device;
      if (kind == FitbitCallbackStatusKind.succeeded &&
          decoded['device'] is Map<String, dynamic>) {
        device = WatchData.fromJson(decoded['device'] as Map<String, dynamic>);
      }

      return Result.success(
        FitbitCallbackStatusSnapshot(kind: kind, device: device),
      );
    } catch (error) {
      return Result.failure('Status check error: $error');
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static bool _isHtmlResponse(http.Response response) {
    final String? contentType = response.headers['content-type'];
    return contentType != null && contentType.contains('text/html');
  }

  static String _extractErrorMessage(
    String body, {
    required String fallback,
  }) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final String? error = decoded['error']?.toString();
        if (error != null && error.isNotEmpty) {
          return error;
        }
      }
    } catch (_) {}
    return fallback;
  }

  static List<String> _extractStringList(Object? value) {
    if (value is! List<Object?>) return const <String>[];
    return value
        .whereType<String>()
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
  }
}

