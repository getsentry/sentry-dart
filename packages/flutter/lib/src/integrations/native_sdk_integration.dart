import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

import '../native/sentry_native_binding.dart';
import '../sentry_flutter_options.dart';

Integration<SentryFlutterOptions> createSdkIntegration(
    SentryNativeBinding native) {
  return NativeSdkIntegration(native);
}

/// Enables Sentry's native SDKs (Android and iOS) with options.
class NativeSdkIntegration implements Integration<SentryFlutterOptions> {
  NativeSdkIntegration(this._native);

  SentryFlutterOptions? _options;
  final SentryNativeBinding _native;
  _NativeBindingLifecycleObserver? _lifecycleObserver;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    _options = options;

    // `_native` is shared for the whole app, so in a multi-view app we can't
    // tell whether one view detaching means it's safe to close - same
    // reasoning as WidgetsBindingIntegration's multi-view gate.
    if (!options.isMultiViewApp) {
      final observer = _NativeBindingLifecycleObserver(this);
      _lifecycleObserver = observer;
      options.bindingUtils.instance?.addObserver(observer);
    }

    if (!options.autoInitializeNativeSdk) {
      return;
    }

    try {
      await _native.init(hub);
      options.sdk.addIntegration('nativeSdkIntegration');
    } catch (exception, stackTrace) {
      options.log(
        SentryLevel.fatal,
        'nativeSdkIntegration failed to be installed',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (_options?.automatedTestMode ?? false) {
        rethrow;
      }
    }
  }

  @override
  Future<void> close() async {
    final observer = _lifecycleObserver;
    if (observer != null) {
      _options?.bindingUtils.instance?.removeObserver(observer);
      _lifecycleObserver = null;
    }

    // The native binding may start background resources unconditionally
    // (e.g. Android's AndroidCoreWorker), regardless of autoInitializeNativeSdk,
    // so close() must always run to stop them. See #3960.
    await _closeNative();
  }

  Future<void> _closeNative() async {
    try {
      await _native.close();
    } catch (exception, stackTrace) {
      _options?.log(
        SentryLevel.fatal,
        'nativeSdkIntegration failed to be closed',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (_options?.automatedTestMode ?? false) {
        rethrow;
      }
    }
  }
}

/// Closes the native binding when the engine hosting it detaches - e.g. when
/// its Android Activity is destroyed - so background resources it started
/// unconditionally don't outlive it. See
/// https://github.com/getsentry/sentry-dart/issues/3960.
///
/// Known limitation: this close is permanent for the lifetime of this
/// isolate. A cached/reused engine that goes `detached` and is later
/// reattached to a new Activity (add-to-app hosts) will not have its native
/// SDK restarted - `SentryFlutter.init` typically isn't called again on
/// reattach, since skipping that re-run is the point of caching the engine.
/// #3960's repro doesn't involve engine reattachment, so this is left
/// unhandled here rather than risk depending on unverified re-init semantics
/// in the underlying native SDKs.
class _NativeBindingLifecycleObserver with WidgetsBindingObserver {
  _NativeBindingLifecycleObserver(this._integration);

  final NativeSdkIntegration _integration;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // Not awaited - didChangeAppLifecycleState is synchronous, and
      // SentryNativeBinding.close() implementations are expected to do
      // their critical shutdown work (if any) synchronously, before their
      // first `await`, so it runs within this call stack rather than after
      // a microtask hop that may never come. See #3960.
      // Routed through _closeNative() so errors from its asynchronous tail
      // are still logged instead of becoming unhandled Future errors.
      unawaited(_integration._closeNative());
    }
  }
}
