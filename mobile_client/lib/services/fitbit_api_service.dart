import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../dto/device_dto.dart';
import '../dto/health_metric_dto.dart';

/// Shared API service scaffold for future Fitbit integration.
///
/// The HTTP client is already part of the package so this layer can move to
/// real API calls later without changing the package structure.
class FitbitApiService {
  FitbitApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<DeviceDto> fetchConnectedDevice({required String userId}) async {
    return DeviceDto(
      userId: userId,
      deviceId: 'fitbit-sense-2',
      deviceName: 'Fitbit Sense 2',
      manufacturer: 'Fitbit',
      connectedAt: DateTime.now().subtract(const Duration(days: 3)),
      source: AppConstants.providerFitbit,
      firmwareVersion: '194.61.1',
      metadata: const <String, dynamic>{
        'batteryLevel': 93,
        'bluetoothState': 'connected',
      },
    );
  }

  Future<List<HealthMetricDto>> fetchWeeklyHealthMetrics({
    required String userId,
    required String deviceId,
  }) async {
    final DateTime now = DateTime.now();

    return <HealthMetricDto>[
      HealthMetricDto(
        userId: userId,
        metricType: AppConstants.metricTypeSpo2,
        value: 97,
        unit: '%',
        timestamp: now,
        source: AppConstants.providerFitbit,
        deviceId: deviceId,
        rawPayload: const <String, dynamic>{'quality': 'good'},
      ),
      HealthMetricDto(
        userId: userId,
        metricType: AppConstants.metricTypeBmr,
        value: 1500,
        unit: 'kcal',
        timestamp: now,
        source: AppConstants.providerFitbit,
        deviceId: deviceId,
        rawPayload: const <String, dynamic>{'confidence': 'estimated'},
      ),
      HealthMetricDto(
        userId: userId,
        metricType: AppConstants.metricTypeSteps,
        value: 0,
        unit: 'steps',
        timestamp: now,
        source: AppConstants.providerFitbit,
        deviceId: deviceId,
        rawPayload: const <String, dynamic>{'status': 'no_sync_yet'},
      ),
    ];
  }

  void dispose() {
    _client.close();
  }
}
