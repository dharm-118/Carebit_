import '../core/result.dart';
import '../dto/device_dto.dart';
import '../models/watch_data.dart';
import '../services/fitbit_api_service.dart';

/// Repository responsible for converting raw device DTOs
/// into clean WatchData models for app use.
///
/// Repositories act as a boundary between:
/// - transport layer data
/// - app-friendly models
class DeviceRepository {
  DeviceRepository({
    FitbitApiService? apiService,
  }) : _apiService = apiService ?? const FitbitApiService();

  final FitbitApiService _apiService;

  /// Fetches connected devices and maps them into WatchData models.
  Future<Result<List<WatchData>>> getConnectedDevices({
    String userId = 'placeholder-user',
  }) async {
    final Result<List<DeviceDto>> result =
        await _apiService.fetchConnectedDevices();

    if (!result.isSuccess || result.data == null) {
      return Result.failure(
        result.errorMessage ?? 'Unknown device repository error',
      );
    }

    final List<WatchData> devices = result.data!
        .map(
          (DeviceDto dto) => WatchData(
            userId: userId,
            provider: 'fitbit',
            deviceId: dto.deviceId,
            deviceName: dto.deviceName,
            type: dto.type,
            batteryLevel: dto.batteryLevel,
            lastSyncTime: null,
            connectedAt: DateTime.now(),
            rawPayload: dto.rawPayload,
          ),
        )
        .toList();

    return Result.success(devices);
  }
}