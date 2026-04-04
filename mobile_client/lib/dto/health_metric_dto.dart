/// DTO representing raw health metric data returned by backend APIs.
///
/// This object is useful for parsing server responses
/// before mapping into strongly typed app models.
class HealthMetricDto {
  const HealthMetricDto({
    required this.metricType,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.source,
    required this.rawPayload,
  });

  final String metricType;
  final String value;
  final String unit;
  final String timestamp;
  final String source;
  final Map<String, dynamic> rawPayload;

  /// Creates a DTO from JSON.
  factory HealthMetricDto.fromJson(Map<String, dynamic> json) {
    return HealthMetricDto(
      metricType: json['metricType']?.toString() ?? 'unknown',
      value: json['value']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      source: json['source']?.toString() ?? 'fitbit',
      rawPayload: json,
    );
  }

  /// Converts the DTO back into JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'metricType': metricType,
      'value': value,
      'unit': unit,
      'timestamp': timestamp,
      'source': source,
      'rawPayload': rawPayload,
    };
  }
}