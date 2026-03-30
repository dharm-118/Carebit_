/// Shared constants used by the frontend package and the local mobile_client package.
abstract final class AppConstants {
  static const String appName = 'Carebit';

  static const Duration splashRedirectDelay = Duration(milliseconds: 1200);

  static const String watchDataCollection = 'watch_data';
  static const String healthMetricsCollection = 'health_metrics';

  static const String providerFitbit = 'fitbit';

  static const String metricTypeHeartRate = 'heart_rate';
  static const String metricTypeSpo2 = 'spo2';
  static const String metricTypeBmr = 'bmr';
  static const String metricTypeSteps = 'steps';
  static const String metricTypeSleep = 'sleep';

  static const int healthScoreMax = 100;
}
