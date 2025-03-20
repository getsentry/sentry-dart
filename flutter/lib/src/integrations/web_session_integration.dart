// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';
import '../web/web_session_handler.dart';

/// Integration for handling web sessions in Sentry.
///
/// Enables tracking of web sessions in a manner similar to page views.
/// It requires using the[SentryNavigatorObserver] since sessions are automatically
/// started on route changes and updated when errors occur.
///
/// The integration is only active on web platforms with enableAutoSessionTracking enabled.
class WebSessionIntegration implements Integration<SentryFlutterOptions> {
  static const integrationName = 'WebSessionIntegration';
  final SentryNativeBinding _native;
  SentryFlutterOptions? _options;
  BeforeSendEventObserver? _observer;
  WebSessionHandler? _webSessionHandler;
  WebSessionHandler? get webSessionHandler => _webSessionHandler;
  bool _isEnabled = false;

  WebSessionIntegration(this._native);

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _options = options;

    _options?.logger(SentryLevel.info,
        '$integrationName initialization started, waiting for SentryNavigatorObserver to be initialized.');
  }

  @override
  void close() {
    if (_options != null && _observer != null) {
      _options!.removeBeforeSendEventObserver(_observer!);
    }
  }

  /// [SentryNavigatorObserver] is created at a later point than the integration
  /// so we need to wait until this function is called by the observer.
  void enable() {
    if (_isEnabled) {
      _options?.logger(
          SentryLevel.debug, '$integrationName is already enabled.');
      return;
    }
    if (!_shouldEnable()) {
      return;
    }

    _webSessionHandler = WebSessionHandler(_native);
    _observer = WebSessionUpdateObserver(_webSessionHandler!);
    _options?.addBeforeSendEventObserver(_observer!);
    _options?.sdk.addIntegration(integrationName);
    _isEnabled = true;
    _options?.logger(
        SentryLevel.info, '$integrationName successfully enabled.');
  }

  bool _shouldEnable() {
    if (_options == null) {
      return false;
    }

    if (!_options!.enableAutoSessionTracking) {
      _options?.logger(SentryLevel.info,
          '$integrationName disabled: enableAutoSessionTracking is not enabled');
      return false;
    }

    if (!_options!.platform.isWeb) {
      _options?.logger(
          SentryLevel.info, '$integrationName disabled: platform is not web');
      return false;
    }

    return true;
  }
}

@visibleForTesting
class WebSessionUpdateObserver implements BeforeSendEventObserver {
  final WebSessionHandler _webSessionHandler;
  WebSessionHandler? get webSessionHandler => _webSessionHandler;

  WebSessionUpdateObserver(this._webSessionHandler);

  @override
  FutureOr<void> onBeforeSendEvent(SentryEvent event, Hint hint) async {
    await _webSessionHandler.updateSessionFromEvent(event);
  }
}
