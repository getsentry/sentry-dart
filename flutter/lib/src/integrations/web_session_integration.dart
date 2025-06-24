// ignore_for_file: invalid_use_of_internal_member, implementation_imports

import 'package:meta/meta.dart';

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

  SentryFlutterOptions? _options;
  Hub? _hub;
  WebSessionHandler? _webSessionHandler;
  WebSessionHandler? get webSessionHandler => _webSessionHandler;
  SdkLifecycleCallback<OnBeforeSendEvent>? _onBeforeSendEventCallback;
  @visibleForTesting
  SdkLifecycleCallback<OnBeforeSendEvent>? get onBeforeSendEventCallback =>
      _onBeforeSendEventCallback;
  bool get _isEnabled => _webSessionHandler != null;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _options = options;
    _hub = hub;
    _options?.log(SentryLevel.info,
        '$integrationName initialization started, waiting for SentryNavigatorObserver to be initialized.');
  }

  @override
  void close() {
    if (_onBeforeSendEventCallback != null) {
      _hub?.removeCallback(_onBeforeSendEventCallback!);
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
    _onBeforeSendEventCallback = (lifecycleEvent) async {
      await _webSessionHandler?.updateSessionFromEvent(lifecycleEvent.event);
    };
    _hub?.registerCallback<OnBeforeSendEvent>(_onBeforeSendEventCallback!);
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
