/// Shared watch/device model used by the frontend package.
class WatchData {
  const WatchData({
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

  WatchData copyWith({
    String? userId,
    String? deviceId,
    String? deviceName,
    String? manufacturer,
    DateTime? connectedAt,
    String? source,
    String? firmwareVersion,
    Map<String, dynamic>? metadata,
  }) {
    return WatchData(
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      manufacturer: manufacturer ?? this.manufacturer,
      connectedAt: connectedAt ?? this.connectedAt,
      source: source ?? this.source,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      metadata: metadata ?? this.metadata,
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
}
