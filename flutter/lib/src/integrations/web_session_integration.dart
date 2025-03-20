// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';
import '../web/web_session_handler.dart';

/// Integration for handling web sessions in Sentry.
///
/// This integration requires the [SentryNavigationObserver] to enable.
class WebSessionIntegration implements Integration<SentryFlutterOptions> {
  static const _integrationName = 'WebSessionIntegration';
  final SentryNativeBinding _native;
  SentryFlutterOptions? _options;
  BeforeSendEventObserver? _observer;
  WebSessionHandler? _webSessionHandler;
  WebSessionHandler? get webSessionHandler => _webSessionHandler;

  WebSessionIntegration(this._native);

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _options = options;

    _log(SentryLevel.info,
        '$_integrationName initialization started, waiting for SentryNavigatorObserver to be initialized.');
  }

  @override
  FutureOr<void> close() {
    if (_options != null && _observer != null) {
      _options!.removeBeforeSendEventObserver(_observer!);
    }
  }

  /// Should only be called once and from [SentryNavigatorObserver].
  void enable() {
    if (!_shouldEnable()) {
      return;
    }

    _webSessionHandler = WebSessionHandler(_native);
    _observer = _BeforeSendEventObserver(_webSessionHandler!);
    _options?.addBeforeSendEventObserver(_observer!);
    _options?.sdk.addIntegration(_integrationName);
    _log(SentryLevel.info, '$_integrationName successfully enabled.');
  }

  bool _shouldEnable() {
    if (_options == null) {
      return false;
    }

    if (!_options!.enableAutoSessionTracking) {
      _log(SentryLevel.info,
          '$_integrationName disabled: enableAutoSessionTracking is not enabled');
      return false;
    }

    if (!_options!.platform.isWeb) {
      _log(SentryLevel.info, '$_integrationName disabled: platform is not web');
      return false;
    }

    return true;
  }

  void _log(SentryLevel level, String message) {
    _options?.logger(level, message);
  }
}

class _BeforeSendEventObserver implements BeforeSendEventObserver {
  final WebSessionHandler _webSessionHandler;

  _BeforeSendEventObserver(this._webSessionHandler);

  @override
  FutureOr<void> onBeforeSendEvent(SentryEvent event, Hint hint) async {
    await _webSessionHandler.updateSessionFromEvent(event);
  }
}
