import '../models/watch_data.dart';

/// Transfer object used for connected device payloads.
class DeviceDto {
  const DeviceDto({
    required this.userId,
    required this.deviceId,
    required this.deviceName,
    required this.manufacturer,
    required this.connectedAt,
    required this.source,
    this.firmwareVersion,
    this.metadata = const <String, dynamic>{},
  });

  final String userId;
  final String deviceId;
  final String deviceName;
  final String manufacturer;
  final DateTime connectedAt;
  final String source;
  final String? firmwareVersion;
  final Map<String, dynamic> metadata;

  factory DeviceDto.fromJson(Map<String, dynamic> json) {
    return DeviceDto(
      userId: _asString(json['userId']),
      deviceId: _asString(json['deviceId']),
      deviceName: _asString(json['deviceName']),
      manufacturer: _asString(json['manufacturer']),
      connectedAt: _asDateTime(json['connectedAt']),
      source: _asString(json['source']),
      firmwareVersion: json['firmwareVersion']?.toString(),
      metadata: _asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'manufacturer': manufacturer,
      'connectedAt': connectedAt.toIso8601String(),
      'source': source,
      'firmwareVersion': firmwareVersion,
      'metadata': metadata,
    };
  }

  WatchData toModel() {
    return WatchData(
      userId: userId,
      deviceId: deviceId,
      deviceName: deviceName,
      manufacturer: manufacturer,
      connectedAt: connectedAt,
      source: source,
      firmwareVersion: firmwareVersion,
      metadata: metadata,
    );
  }
}

String _asString(Object? value) => value?.toString() ?? '';

DateTime _asDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map(
      (dynamic key, dynamic entryValue) => MapEntry(key.toString(), entryValue),
    );
  }

  return <String, dynamic>{};
}
