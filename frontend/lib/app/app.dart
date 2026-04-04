import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_client/constants/route_paths.dart';

import 'fitbit_callback_coordinator.dart';
import 'fitbit_link_coordinator.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Root application widget.
///
/// This widget connects the router, shared theme, and the Fitbit callback flow.
class CarebitApp extends ConsumerStatefulWidget {
  const CarebitApp({super.key, this.linkCoordinator});

  /// Optional link coordinator injected for deep-link handling.
  /// Primarily used in widget tests to provide a fake link source.
  final FitbitLinkSource? linkCoordinator;

  @override
  ConsumerState<CarebitApp> createState() => _CarebitAppState();
}

class _CarebitAppState extends ConsumerState<CarebitApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late final FitbitCallbackCoordinator _callbackCoordinator;
  late final FitbitLinkSource _linkSource;
  late final GoRouter _router;

  StreamSubscription<Uri>? _uriSubscription;
  FitbitLinkCoordinator? _ownedLinkCoordinator;
  Future<void> _callbackTask = Future<void>.value();
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    _router = buildAppRouter(initialLocation: RoutePaths.splash);
    _callbackCoordinator = ref.read(fitbitCallbackCoordinatorProvider);
    _callbackCoordinator.addListener(_handleDeliveredOutcome);

    if (widget.linkCoordinator == null) {
      _ownedLinkCoordinator = FitbitLinkCoordinator();
      _linkSource = _ownedLinkCoordinator!;
    } else {
      _linkSource = widget.linkCoordinator!;
    }

    _uriSubscription = _linkSource.uriStream.listen(
      (Uri uri) {
        _queueCallbackTask(() => _processCallbackUri(uri));
      },
      onError: (Object error, StackTrace stackTrace) {
        _showMessage('Could not read the Fitbit callback link: $error');
      },
    );

    unawaited(_initializeCallbackHandling());
  }

  @override
  void dispose() {
    _disposed = true;
    _callbackCoordinator.removeListener(_handleDeliveredOutcome);
    unawaited(_uriSubscription?.cancel());
    if (_ownedLinkCoordinator != null) {
      unawaited(_ownedLinkCoordinator!.dispose());
    }
    super.dispose();
  }

  Future<void> _initializeCallbackHandling() async {
    try {
      if (_ownedLinkCoordinator != null) {
        await _ownedLinkCoordinator!.initialize();
      }

      final Uri? startupUri = _linkSource.takeStartupUri();
      if (startupUri != null) {
        _queueCallbackTask(() => _processCallbackUri(startupUri));
        return;
      }

      _queueCallbackTask(_resumePendingCallbackIfNeeded);
    } catch (error) {
      _showMessage('Could not initialize Fitbit callback handling: $error');
    }
  }

  void _queueCallbackTask(Future<void> Function() task) {
    _callbackTask = _callbackTask.then((_) async {
      if (_disposed) {
        return;
      }

      try {
        await task();
      } catch (error) {
        _showMessage('Could not finish Fitbit sign-in: $error');
      }
    });
  }

  Future<void> _processCallbackUri(Uri uri) async {
    final FitbitCallbackOutcome outcome = await _callbackCoordinator.process(
      uri,
    );
    _handleCallbackOutcome(outcome);
  }

  Future<void> _resumePendingCallbackIfNeeded() async {
    final bool hasPendingSession = await _callbackCoordinator
        .hasResumablePendingCallbackSession();
    if (!hasPendingSession) {
      return;
    }

    final FitbitCallbackOutcome outcome = await _callbackCoordinator
        .resumePendingCallback();
    _handleCallbackOutcome(outcome);
  }

  void _handleDeliveredOutcome() {
    final FitbitCallbackOutcome? deliveredOutcome = _callbackCoordinator
        .takeDeliveredOutcome();
    if (deliveredOutcome == null) {
      return;
    }

    _handleCallbackOutcome(deliveredOutcome);
  }

  void _handleCallbackOutcome(FitbitCallbackOutcome outcome) {
    if (_disposed) {
      return;
    }

    switch (outcome.type) {
      case FitbitCallbackOutcomeType.success:
        if (outcome.shouldShowMessage) {
          _showMessage(outcome.message!);
        }
        _navigate(RoutePaths.healthMetrics);
        break;
      case FitbitCallbackOutcomeType.failed:
      case FitbitCallbackOutcomeType.rejected:
        if (outcome.shouldShowMessage) {
          _showMessage(outcome.message!);
        }
        if (outcome.shouldRedirectToConnectDevice) {
          _navigate(RoutePaths.connectDevice);
        }
        break;
      case FitbitCallbackOutcomeType.duplicate:
      case FitbitCallbackOutcomeType.ignored:
      case FitbitCallbackOutcomeType.pending:
        break;
    }
  }

  void _navigate(String location) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) {
        return;
      }

      _router.go(location);
    });
  }

  void _showMessage(String message) {
    final String normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) {
        return;
      }

      final ScaffoldMessengerState? messenger =
          _scaffoldMessengerKey.currentState;
      if (messenger == null) {
        return;
      }

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(normalizedMessage)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Carebit',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}
