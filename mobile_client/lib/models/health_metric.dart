/// Shared health metric model used by the frontend package.
class HealthMetric {
  const HealthMetric({
    required this.userId,
    required this.metricType,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.source,
    required this.deviceId,
    this.rawPayload = const <String, dynamic>{},
  });

  final String userId;
  final String metricType;
  final double value;
  final String unit;
  final DateTime timestamp;
  final String source;
  final String deviceId;
  final Map<String, dynamic> rawPayload;

  HealthMetric copyWith({
    String? userId,
    String? metricType,
    double? value,
    String? unit,
    DateTime? timestamp,
    String? source,
    String? deviceId,
    Map<String, dynamic>? rawPayload,
  }) {
    return HealthMetric(
      userId: userId ?? this.userId,
      metricType: metricType ?? this.metricType,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      deviceId: deviceId ?? this.deviceId,
      rawPayload: rawPayload ?? this.rawPayload,
    );
  }

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
