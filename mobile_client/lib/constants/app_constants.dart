/// Application-wide constants used by the Carebit client layer.
///
/// This file stores values shared across repositories,
/// services, and future app integrations.
class AppConstants {
  AppConstants._();

  /// Base backend URL used by the frontend/mobile client.
  ///
  /// IMPORTANT:
  /// - For Android emulator, the default 10.0.2.2 works for localhost on host machine.
  /// - For a PHYSICAL Android or iPhone device, pass your computer's LAN IP
  ///   using --dart-define=CAREBIT_BACKEND_URL=http://YOUR_IP:5001/carebit-e30d4/us-central1
  static const String backendBaseUrl = String.fromEnvironment(
    'CAREBIT_BACKEND_URL',
    defaultValue: 'http://10.0.2.2:5001/carebit-e30d4/us-central1',
  );

  /// API timeout duration in seconds for HTTP requests.
  static const int apiTimeoutInSeconds = 30;

  /// Firestore collection name for connected watch/device data.
  static const String watchDataCollection = 'watch_data';

  /// Firestore collection name for health metrics.
  static const String healthMetricsCollection = 'health_metrics';

  /// Backend endpoint for starting Fitbit OAuth.
  static const String fitbitAuthStartEndpoint = '/fitbitAuthStart';

  /// Backend endpoint for OAuth callback exchange.
  static const String fitbitAuthCallbackEndpoint = '/fitbitAuthCallback';

  /// Backend endpoint for fetching connected Fitbit devices.
  static const String fitbitDevicesEndpoint = '/fitbitDevices';

  /// Backend endpoint for fetching Fitbit health metrics.
  static const String fitbitHealthMetricsEndpoint = '/fitbitHealthMetrics';

  /// Metric type identifier for blood oxygen (SpO2).
  static const String metricTypeSpo2 = 'spo2';

  /// Metric type identifier for basal metabolic rate.
  static const String metricTypeBmr = 'bmr';

  /// Metric type identifier for step count.
  static const String metricTypeSteps = 'steps';

  /// Maximum value for the health score ring.
  static const int healthScoreMax = 100;

  /// Provider identifier for Fitbit devices.
  static const String providerFitbit = 'fitbit';

  /// How long the splash screen waits before redirecting.
  static const Duration splashRedirectDelay = Duration(seconds: 2);
}