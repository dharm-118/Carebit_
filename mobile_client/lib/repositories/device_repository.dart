import '../core/result.dart';
import '../models/watch_data.dart';
import '../services/fitbit_api_service.dart';

/// Repository wrapper around the shared Fitbit API service for connected devices.
class DeviceRepository {
  DeviceRepository({FitbitApiService? apiService})
    : _apiService = apiService ?? FitbitApiService();

  final FitbitApiService _apiService;

  Future<Result<WatchData>> getConnectedDevice({
    String userId = 'demo-user',
  }) async {
    try {
      final dto = await _apiService.fetchConnectedDevice(userId: userId);
      return ResultSuccess<WatchData>(dto.toModel());
    } catch (error) {
      return ResultFailure<WatchData>(
        'Failed to load connected device: $error',
      );
    }
  }
}
