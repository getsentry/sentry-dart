import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

import '../native/sentry_native_binding.dart';
import '../sentry_flutter_options.dart';
import '../utils/internal_logger.dart';

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
  Future<void>? _closeFuture;

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
      internalLogger.fatal(
        'nativeSdkIntegration failed to be installed',
        error: exception,
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
    await _closeNative(isExplicit: true);
  }

  // Both the detach observer and an explicit Sentry.close() call reach this
  // method, and either order is possible - the underlying native SDKs
  // aren't guaranteed to tolerate being closed twice, so only the first
  // caller actually invokes _native.close(); later callers await that same
  // in-flight/completed close instead of returning immediately, so
  // Sentry.close() never resolves before native cleanup has actually
  // finished.
  //
  // Known limitation: isExplicit is only honored on the first call. If a
  // detach fires first (isExplicit: false, Android's worker deliberately
  // left running) and a genuine Sentry.close() only arrives afterwards,
  // this returns the already-completed detach close without revisiting the
  // worker. #3960's repro doesn't call Sentry.close() after detach, so this
  // is documented rather than solved speculatively.
  Future<void> _closeNative({required bool isExplicit}) {
    final existing = _closeFuture;
    if (existing != null) {
      return existing;
    }
    final future = _doCloseNative(isExplicit: isExplicit);
    _closeFuture = future;
    return future;
  }

  Future<void> _doCloseNative({required bool isExplicit}) async {
    try {
      await _native.close(isExplicit: isExplicit);
    } catch (exception, stackTrace) {
      internalLogger.fatal(
        'nativeSdkIntegration failed to be closed',
        error: exception,
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
/// Android's core JNI worker isolate (`AndroidCoreWorker`, the resource
/// #3960 was actually about) no longer depends on this observer for its own
/// cleanup - it ties its shutdown directly to this isolate's exit instead
/// (see AndroidCoreWorker.closeOnOwnerExit), so it survives a cached engine
/// detaching and later reattaching. This observer still closes everything
/// else the native SDK owns (e.g. the crash handler, replay recorder),
/// which remains subject to the limitation below. It calls _closeNative
/// with isExplicit: false precisely so SentryNativeJava.close() knows not
/// to force the worker closed on this non-terminal signal.
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
      // isExplicit: false - a detach doesn't necessarily mean the engine is
      // gone for good, so resources that are safe to keep running across a
      // reattach (e.g. Android's core worker isolate) are left alone here.
      unawaited(_integration._closeNative(isExplicit: false));
    }
  }
}
