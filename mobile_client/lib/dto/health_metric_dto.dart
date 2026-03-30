import '../models/health_metric.dart';

/// Transfer object used for health metric payloads.
class HealthMetricDto {
  const HealthMetricDto({
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

  factory HealthMetricDto.fromJson(Map<String, dynamic> json) {
    return HealthMetricDto(
      userId: _asString(json['userId']),
      metricType: _asString(json['metricType']),
      value: _asDouble(json['value']),
      unit: _asString(json['unit']),
      timestamp: _asDateTime(json['timestamp']),
      source: _asString(json['source']),
      deviceId: _asString(json['deviceId']),
      rawPayload: _asMap(json['rawPayload']),
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

  HealthMetric toModel() {
    return HealthMetric(
      userId: userId,
      metricType: metricType,
      value: value,
      unit: unit,
      timestamp: timestamp,
      source: source,
      deviceId: deviceId,
      rawPayload: rawPayload,
    );
  }
}

String _asString(Object? value) => value?.toString() ?? '';

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

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
