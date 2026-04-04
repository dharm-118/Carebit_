import 'package:go_router/go_router.dart';
import 'package:mobile_client/constants/route_paths.dart';

import '../features/connect_device/presentation/connect_device_screen.dart';
import '../features/health_metrics/presentation/health_metrics_screen.dart';
import '../features/splash/presentation/splash_screen.dart';

/// Central route configuration for the app.
///
/// Route path values are imported from the shared mobile_client layer so the
/// frontend does not duplicate hardcoded navigation strings.
GoRouter buildAppRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <GoRoute>[
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.connectDevice,
        builder: (context, state) => const ConnectDeviceScreen(),
      ),
      GoRoute(
        path: RoutePaths.healthMetrics,
        builder: (context, state) => const HealthMetricsScreen(),
      ),
    ],
  );
}

final GoRouter appRouter = buildAppRouter(
  initialLocation: RoutePaths.splash,
);
