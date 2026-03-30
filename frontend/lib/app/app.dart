import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_client/constants/route_paths.dart';

import 'fitbit_oauth.dart';
import 'router.dart';
import 'theme/app_theme.dart';

final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class CarebitApp extends ConsumerStatefulWidget {
  const CarebitApp({super.key});

  @override
  ConsumerState<CarebitApp> createState() => _CarebitAppState();
}

class _CarebitAppState extends ConsumerState<CarebitApp> {
  static const Duration _backendTimeout = Duration(seconds: 3);

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _uriSubscription;
  bool _isHandlingFitbitCallback = false;

  @override
  void initState() {
    super.initState();
    _initializeFitbitCallbackHandling();
  }

  Future<void> _initializeFitbitCallbackHandling() async {
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();

      if (initialUri != null) {
        await _handleFitbitCallback(initialUri);
      }
    } catch (_) {
      // Ignore malformed initial deep links and keep the app usable.
    }

    _uriSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        unawaited(_handleFitbitCallback(uri));
      },
      onError: (_) {
        _showMessage('Could not read the Fitbit callback URL.');
      },
    );
  }

  Future<void> _handleFitbitCallback(Uri uri) async {
    if (!isFitbitCallbackUri(uri) || _isHandlingFitbitCallback) {
      return;
    }

    _isHandlingFitbitCallback = true;

    try {
      final String? oauthError = uri.queryParameters['error'];

      if (oauthError != null && oauthError.isNotEmpty) {
        _showMessage('Fitbit sign-in failed: $oauthError');
        return;
      }

      final String? code = uri.queryParameters['code'];

      if (code == null || code.trim().isEmpty) {
        _showMessage('Fitbit sign-in did not return an authorization code.');
        return;
      }

      await _exchangeFitbitCode(
        code: code.trim(),
        state: uri.queryParameters['state'],
      );

      _showMessage('Fitbit connected successfully.');
      ref.read(appRouterProvider).go(RoutePaths.healthMetrics);
    } catch (error) {
      _showMessage('Could not finish Fitbit sign-in: $error');
    } finally {
      _isHandlingFitbitCallback = false;
    }
  }

  Future<void> _exchangeFitbitCode({
    required String code,
    String? state,
  }) async {
    Object? lastError;

    for (final String host in carebitBackendHosts()) {
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
          throw Exception(_extractErrorMessage(body));
        }

        return;
      } catch (error) {
        lastError = error;
      } finally {
        httpClient.close(force: true);
      }
    }

    throw Exception(
      'Could not reach the Fitbit backend callback endpoint. '
      'On a physical Android phone, run `adb reverse tcp:5002 tcp:5002`. '
      'Last error: $lastError',
    );
  }

  String _extractErrorMessage(String body) {
    try {
      final Object? decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        final Object? error = decoded['error'];

        if (error is String && error.isNotEmpty) {
          return error;
        }
      }
    } catch (_) {
      // Fall back to a generic message when the backend response is not JSON.
    }

    return 'Fitbit token exchange failed.';
  }

  void _showMessage(String message) {
    appScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _uriSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Carebit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      routerConfig: router,
    );
  }
}
