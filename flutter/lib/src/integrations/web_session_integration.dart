// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';
import '../web/web_session_handler.dart';

/// Integration for handling web sessions in Sentry.
///
/// Enables tracking of web sessions in a manner similar to page views.
/// It requires using the [SentryNavigatorObserver] since sessions are automatically
/// started on route changes and updated when errors occur.
///
/// The integration is only active on web platforms with enableAutoSessionTracking enabled.
class WebSessionIntegration implements Integration<SentryFlutterOptions> {
  WebSessionIntegration(this._native);

  final SentryNativeBinding _native;

  static const integrationName = 'WebSessionIntegration';

  WebSessionHandler? get webSessionHandler => _webSessionHandler;
  bool get _isEnabled => _webSessionHandler != null;

  SentryFlutterOptions? _options;
  WebSessionHandler? _webSessionHandler;
  Hub? _hub;
  SdkLifecycleEventCallback<BeforeSendEventEvent>? _callback;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _options = options;
    _hub = hub;
    _options?.log(SentryLevel.info,
        '$integrationName initialization started, waiting for SentryNavigatorObserver to be initialized.');
  }

  @override
  void close() {
    if (_callback != null && _webSessionHandler != null) {
      _hub?.removeCallback(_callback!);
    }
  }

  /// [SentryNavigatorObserver] is created at a later point than the integration
  /// so we need to wait until this function is called by the observer.
  void enable() {
    if (_isEnabled) {
      _options?.log(SentryLevel.debug, '$integrationName is already enabled.');
      return;
    }
    if (!_shouldEnable()) {
      return;
    }

    _webSessionHandler = WebSessionHandler(_native);
    _callback = (event) {
      _webSessionHandler?.updateSessionFromEvent(event.event);
    };
    _hub?.registerCallback<BeforeSendEventEvent>(_callback!);

    _options?.sdk.addIntegration(integrationName);
    _options?.log(SentryLevel.info, '$integrationName successfully enabled.');
  }

  bool _shouldEnable() {
    if (_options == null) {
      return false;
    }
    if (!_options!.enableAutoSessionTracking) {
      _options?.log(SentryLevel.info,
          '$integrationName disabled: enableAutoSessionTracking is not enabled');
      return false;
    }
    return true;
  }
}
