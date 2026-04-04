/// App model representing a connected wearable device.
///
/// This is the clean model the UI/repositories can use,
/// separate from raw backend DTO transport objects.
class WatchData {
  const WatchData({
    required this.userId,
    required this.source,
    required this.deviceId,
    required this.deviceName,
    required this.connectedAt,
    this.manufacturer,
    this.type,
    this.batteryLevel,
    this.lastSyncTime,
    this.rawPayload = const <String, dynamic>{},
  });

  final String userId;
  final String source;
  final String deviceId;
  final String deviceName;
  final DateTime connectedAt;
  final String? manufacturer;
  final String? type;
  final String? batteryLevel;
  final DateTime? lastSyncTime;
  final Map<String, dynamic> rawPayload;

  /// Creates a WatchData model from JSON.
  factory WatchData.fromJson(Map<String, dynamic> json) {
    return WatchData(
      userId: json['userId']?.toString() ?? '',
      source: json['source']?.toString() ??
          json['provider']?.toString() ??
          'fitbit',
      deviceId: json['deviceId']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? 'Unknown Device',
      connectedAt: DateTime.tryParse(json['connectedAt']?.toString() ?? '') ??
          DateTime.now(),
      manufacturer: json['manufacturer']?.toString(),
      type: json['type']?.toString(),
      batteryLevel: json['batteryLevel']?.toString(),
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.tryParse(json['lastSyncTime'].toString())
          : null,
      rawPayload:
          (json['rawPayload'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }

  /// Converts the WatchData model into JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'source': source,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'connectedAt': connectedAt.toIso8601String(),
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (type != null) 'type': type,
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
      if (lastSyncTime != null) 'lastSyncTime': lastSyncTime!.toIso8601String(),
      'rawPayload': rawPayload,
    };
  }
}
