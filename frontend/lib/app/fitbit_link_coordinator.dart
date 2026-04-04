import 'dart:async';

import 'package:app_links/app_links.dart';

abstract interface class FitbitLinkSource {
  Stream<Uri> get uriStream;
  Object? get startupError;

  Uri? takeStartupUri();
}

class FitbitLinkCoordinator implements FitbitLinkSource {
  static const Duration _startupLinkTimeout = Duration(milliseconds: 800);

  FitbitLinkCoordinator({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  final StreamController<Uri> _uriStreamController =
      StreamController<Uri>.broadcast();
  final Completer<Uri?> _startupLinkCompleter = Completer<Uri?>();

  StreamSubscription<Uri>? _uriSubscription;
  Uri? _startupUri;
  Object? _startupError;
  bool _initialized = false;

  @override
  Stream<Uri> get uriStream => _uriStreamController.stream;

  @override
  Object? get startupError => _startupError;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    _uriSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _startupUri ??= uri;
        if (!_startupLinkCompleter.isCompleted) {
          _startupLinkCompleter.complete(uri);
        }
        _uriStreamController.add(uri);
      },
      onError: (Object error) {
        _startupError ??= error;
        if (!_startupLinkCompleter.isCompleted) {
          _startupLinkCompleter.complete(null);
        }
      },
    );

    unawaited(_resolveInitialLink());

    final Uri? startupUri = await Future.any(<Future<Uri?>>[
      _startupLinkCompleter.future,
      Future<Uri?>.delayed(_startupLinkTimeout, () => null),
    ]);
    _startupUri ??= startupUri;
  }

  Future<void> _resolveInitialLink() async {
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();

      if (initialUri == null) {
        return;
      }

      _startupUri ??= initialUri;
      if (!_startupLinkCompleter.isCompleted) {
        _startupLinkCompleter.complete(initialUri);
      }
    } catch (error) {
      _startupError ??= error;
      if (!_startupLinkCompleter.isCompleted) {
        _startupLinkCompleter.complete(null);
      }
    }
  }

  @override
  Uri? takeStartupUri() {
    final Uri? uri = _startupUri;
    _startupUri = null;
    return uri;
  }

  Future<void> dispose() async {
    await _uriSubscription?.cancel();
    await _uriStreamController.close();
  }
}
