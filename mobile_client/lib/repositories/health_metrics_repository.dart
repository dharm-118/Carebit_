import '../core/result.dart';
import '../models/health_metric.dart';
import '../services/fitbit_api_service.dart';

/// Repository wrapper around the shared Fitbit API service for health metrics.
class HealthMetricsRepository {
  HealthMetricsRepository({FitbitApiService? apiService})
    : _apiService = apiService ?? FitbitApiService();

  final FitbitApiService _apiService;

  Future<Result<List<HealthMetric>>> getWeeklyMetrics({
    String userId = 'demo-user',
    String deviceId = 'fitbit-sense-2',
  }) async {
    try {
      final dtos = await _apiService.fetchWeeklyHealthMetrics(
        userId: userId,
        deviceId: deviceId,
      );

      return ResultSuccess<List<HealthMetric>>(
        dtos.map((dto) => dto.toModel()).toList(growable: false),
      );
    } catch (error) {
      return ResultFailure<List<HealthMetric>>(
        'Failed to load weekly metrics: $error',
      );
    }
  }
}
