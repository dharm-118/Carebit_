import '../core/result.dart';
import '../dto/health_metric_dto.dart';
import '../models/health_metric.dart';
import '../services/fitbit_api_service.dart';

/// Repository responsible for converting raw health metric DTOs
/// into clean app models.
class HealthMetricsRepository {
  HealthMetricsRepository({
    FitbitApiService? apiService,
  }) : _apiService = apiService ?? const FitbitApiService();

  final FitbitApiService _apiService;

  /// Fetches health metrics and maps them into HealthMetric models.
  Future<Result<List<HealthMetric>>> getHealthMetrics({
    String userId = 'placeholder-user',
    String deviceId = 'placeholder-device',
  }) async {
    final Result<List<HealthMetricDto>> result =
        await _apiService.fetchHealthMetrics();

    if (!result.isSuccess || result.data == null) {
      return Result.failure(
        result.errorMessage ?? 'Unknown health metrics repository error',
      );
    }

    final List<HealthMetric> metrics = result.data!
        .map(
          (HealthMetricDto dto) => HealthMetric(
            userId: userId,
            metricType: dto.metricType,
            value: dto.value,
            unit: dto.unit,
            timestamp: DateTime.tryParse(dto.timestamp) ?? DateTime.now(),
            source: dto.source,
            deviceId: deviceId,
            rawPayload: dto.rawPayload,
          ),
        )
        .toList();

    return Result.success(metrics);
  }
}