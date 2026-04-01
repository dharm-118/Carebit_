import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_client/constants/route_paths.dart';

import 'fitbit_link_coordinator.dart';
import 'fitbit_oauth.dart';
import 'router.dart';
import 'theme/app_theme.dart';

final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class CarebitApp extends StatefulWidget {
  const CarebitApp({required this.linkCoordinator, super.key});

  final FitbitLinkCoordinator linkCoordinator;

  @override
  State<CarebitApp> createState() => _CarebitAppState();
}

class _CarebitAppState extends State<CarebitApp> {
  static const Duration _backendTimeout = Duration(seconds: 3);

  StreamSubscription<Uri>? _uriSubscription;
  bool _isHandlingFitbitCallback = false;
  bool _isFinalizingFitbitCallback = false;
  String? _pendingStartupMessage;
  String? _lastHandledFitbitCallback;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _uriSubscription = widget.linkCoordinator.uriStream.listen(
      (Uri uri) {
        if (_router == null) {
          return;
        }

        unawaited(_handleFitbitCallback(uri));
      },
      onError: (_) {
        _showMessage('Could not read the Fitbit callback URL.');
      },
    );
    unawaited(_initializeApp());
  }

  Future<void> _initializeApp() async {
    final Uri? initialUri = widget.linkCoordinator.takeStartupUri();
    final bool launchedFromFitbitCallback =
        initialUri != null && isFitbitCallbackUri(initialUri);

    if (widget.linkCoordinator.startupError != null) {
      _pendingStartupMessage = 'Could not read the Fitbit callback URL.';
    }

    _router = buildAppRouter(
      initialLocation: launchedFromFitbitCallback
          ? RoutePaths.healthMetrics
          : RoutePaths.splash,
    );

    if (!mounted) {
      return;
    }

    setState(() {});
    _flushPendingMessage();

    if (initialUri != null) {
      await _handleFitbitCallback(
        initialUri,
        redirectToConnectOnFailure: launchedFromFitbitCallback,
      );
      _flushPendingMessage();
    }
  }

  Future<void> _handleFitbitCallback(
    Uri uri, {
    bool redirectToConnectOnFailure = false,
  }) async {
    final String callbackKey = uri.toString();

    if (!isFitbitCallbackUri(uri) ||
        _isHandlingFitbitCallback ||
        _lastHandledFitbitCallback == callbackKey) {
      return;
    }

    _isHandlingFitbitCallback = true;

    try {
      final String? oauthError = uri.queryParameters['error'];

      if (oauthError != null && oauthError.isNotEmpty) {
        throw Exception('Fitbit sign-in failed: $oauthError');
      }

      final String? code = uri.queryParameters['code'];

      if (code == null || code.trim().isEmpty) {
        throw Exception('Fitbit sign-in did not return an authorization code.');
      }

      if (mounted) {
        setState(() {
          _isFinalizingFitbitCallback = true;
        });
      }
      _router?.go(RoutePaths.healthMetrics);

      await _exchangeFitbitCode(
        code: code.trim(),
        state: uri.queryParameters['state'],
      );

      _lastHandledFitbitCallback = callbackKey;
      _router?.go(RoutePaths.healthMetrics);
      _showMessage('Fitbit account connected successfully.');
    } catch (error) {
      _lastHandledFitbitCallback = callbackKey;
      if (redirectToConnectOnFailure) {
        _router?.go(RoutePaths.connectDevice);
      }
      _showMessage(
        'Could not finish Fitbit sign-in: ${fitbitUserVisibleError(error)}',
      );
    } finally {
      _isHandlingFitbitCallback = false;
      if (mounted && _isFinalizingFitbitCallback) {
        setState(() {
          _isFinalizingFitbitCallback = false;
        });
      }
    }
  }

  Future<void> _exchangeFitbitCode({
    required String code,
    String? state,
  }) async {
    final List<String> backendHosts = carebitBackendHosts(
      preferredHost: preferredCarebitBackendHost(),
    );

    for (final String host in backendHosts) {
      final HttpClient httpClient = HttpClient()
        ..connectionTimeout = _backendTimeout;

      try {
        final Uri exchangeUri = fitbitTokenExchangeUri(
          host: host,
          code: code,
          state: state,
        );
        final HttpClientRequest request = await httpClient
            .getUrl(exchangeUri)
            .timeout(_backendTimeout);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');

        final HttpClientResponse response = await request.close().timeout(
          _backendTimeout,
        );
        final String body = await response.transform(utf8.decoder).join();

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            extractFitbitBackendErrorMessage(
              body,
              fallbackMessage: 'Fitbit token exchange failed.',
            ),
          );
        }

        rememberCarebitBackendHost(host);
        return;
      } catch (_) {
        // Try the next available backend target.
      } finally {
        httpClient.close(force: true);
      }
    }

    throw Exception(fitbitBackendConnectionErrorMessage(duringCallback: true));
  }

  void _showMessage(String message) {
    final ScaffoldMessengerState? messenger =
        appScaffoldMessengerKey.currentState;

    if (messenger == null) {
      _pendingStartupMessage = message;
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _flushPendingMessage() {
    final String? message = _pendingStartupMessage;

    if (message == null) {
      return;
    }

    _pendingStartupMessage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      appScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  @override
  void dispose() {
    _uriSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter? router = _router;

    if (router == null) {
      return MaterialApp(
        title: 'Carebit',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        home: const Scaffold(body: SizedBox.shrink()),
      );
    }

    return MaterialApp.router(
      title: 'Carebit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        return Stack(
          children: <Widget>[
            child ?? const SizedBox.shrink(),
            if (_isFinalizingFitbitCallback)
              const _FitbitCallbackTransitionOverlay(),
          ],
        );
      },
    );
  }
}

class _FitbitCallbackTransitionOverlay extends StatelessWidget {
  const _FitbitCallbackTransitionOverlay();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Finishing Fitbit connection...',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
