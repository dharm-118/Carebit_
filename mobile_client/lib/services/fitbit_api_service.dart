import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../core/result.dart';
import '../dto/device_dto.dart';
import '../dto/health_metric_dto.dart';

/// Service responsible for making raw HTTP requests to backend APIs.
///
/// The Flutter app never exchanges Fitbit client secrets directly.
/// It only talks to the Carebit backend.
class FitbitApiService {
  const FitbitApiService();

  /// Calls the backend OAuth start endpoint and returns the Fitbit auth URL.
  Future<Result<String>> fetchAuthorizationUrl() async {
    try {
      final Uri uri = Uri.parse(
        '${AppConstants.backendBaseUrl}${AppConstants.fitbitAuthStartEndpoint}',
      );

      final http.Response response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: AppConstants.apiTimeoutInSeconds),
          );

      if (response.statusCode != 200) {
        return Result.failure(
          'Failed to start Fitbit OAuth. Status: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;

      final String? authUrl = decoded['authUrl']?.toString();

      if (authUrl == null || authUrl.isEmpty) {
        return Result.failure('Backend did not return a valid authUrl.');
      }

      return Result.success(authUrl);
    } catch (error) {
      return Result.failure('OAuth start error: $error');
    }
  }

  /// Sends Fitbit OAuth code to backend callback endpoint.
  Future<Result<Map<String, dynamic>>> exchangeOAuthCode(String code) async {
    try {
      final Uri uri = Uri.parse(
        '${AppConstants.backendBaseUrl}${AppConstants.fitbitAuthCallbackEndpoint}?code=$code',
      );

      final http.Response response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: AppConstants.apiTimeoutInSeconds),
          );

      if (response.statusCode != 200) {
        return Result.failure(
          'Failed to complete OAuth callback. Status: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;

      return Result.success(decoded);
    } catch (error) {
      return Result.failure('OAuth callback error: $error');
    }
  }

  /// Fetches connected Fitbit-supported devices from backend.
  Future<Result<List<DeviceDto>>> fetchConnectedDevices() async {
    try {
      final Uri uri = Uri.parse(
        '${AppConstants.backendBaseUrl}${AppConstants.fitbitDevicesEndpoint}',
      );

      final http.Response response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: AppConstants.apiTimeoutInSeconds),
          );

      if (response.statusCode != 200) {
        return Result.failure(
          'Failed to fetch devices. Status: ${response.statusCode}',
        );
      }

      final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;

      final List<DeviceDto> devices = decoded
          .map((dynamic item) => DeviceDto.fromJson(item as Map<String, dynamic>))
          .toList();

      return Result.success(devices);
    } catch (error) {
      return Result.failure('Device fetch error: $error');
    }
  }

  /// Fetches health metrics from backend.
  Future<Result<List<HealthMetricDto>>> fetchHealthMetrics() async {
    try {
      final Uri uri = Uri.parse(
        '${AppConstants.backendBaseUrl}${AppConstants.fitbitHealthMetricsEndpoint}',
      );

      final http.Response response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: AppConstants.apiTimeoutInSeconds),
          );

      if (response.statusCode != 200) {
        return Result.failure(
          'Failed to fetch health metrics. Status: ${response.statusCode}',
        );
      }

      final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;

      final List<HealthMetricDto> metrics = decoded
          .map(
            (dynamic item) =>
                HealthMetricDto.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      return Result.success(metrics);
    } catch (error) {
      return Result.failure('Health metrics fetch error: $error');
    }
  }
}