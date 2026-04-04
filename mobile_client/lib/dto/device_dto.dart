import '../models/watch_data.dart';

/// DTO representing raw device information returned from backend APIs.
///
/// DTOs are transport-layer objects.
/// They can later be mapped into app-friendly models.
class DeviceDto {
  const DeviceDto({
    required this.deviceId,
    required this.deviceName,
    required this.type,
    required this.batteryLevel,
    required this.rawPayload,
  });

  final String deviceId;
  final String deviceName;
  final String type;
  final String? batteryLevel;
  final Map<String, dynamic> rawPayload;

  /// Creates a DTO from JSON.
  factory DeviceDto.fromJson(Map<String, dynamic> json) {
    return DeviceDto(
      deviceId: json['deviceId']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? 'Unknown Device',
      type: json['type']?.toString() ?? 'unknown',
      batteryLevel: json['batteryLevel']?.toString(),
      rawPayload: json,
    );
  }

  /// Converts the DTO back into JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'deviceId': deviceId,
      'deviceName': deviceName,
      'type': type,
      'batteryLevel': batteryLevel,
      'rawPayload': rawPayload,
    };
  }

  /// Maps this DTO to a [WatchData] app model.
  WatchData toModel() {
    return WatchData(
      userId: '',
      source: 'fitbit',
      deviceId: deviceId,
      deviceName: deviceName,
      connectedAt: DateTime.now(),
      type: type,
      batteryLevel: batteryLevel,
      rawPayload: rawPayload,
    );
  }
}