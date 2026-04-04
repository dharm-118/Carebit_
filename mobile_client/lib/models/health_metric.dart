/// App model representing a single health metric record.
///
/// This model is designed to mirror future Firestore and backend data,
/// while remaining convenient for the UI layer.
class HealthMetric {
  const HealthMetric({
    required this.userId,
    required this.metricType,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.source,
    required this.deviceId,
    required this.rawPayload,
  });

  final String userId;
  final String metricType;
  final num value;
  final String unit;
  final DateTime timestamp;
  final String source;
  final String deviceId;
  final Map<String, dynamic> rawPayload;

  /// Creates a HealthMetric from JSON.
  factory HealthMetric.fromJson(Map<String, dynamic> json) {
    return HealthMetric(
      userId: json['userId']?.toString() ?? '',
      metricType: json['metricType']?.toString() ?? 'unknown',
      value: (json['value'] as num?) ?? 0,
      unit: json['unit']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      source: json['source']?.toString() ?? 'fitbit',
      deviceId: json['deviceId']?.toString() ?? '',
      rawPayload:
          (json['rawPayload'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }

  /// Converts the HealthMetric to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'metricType': metricType,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
      'deviceId': deviceId,
      'rawPayload': rawPayload,
    };
  }
}
