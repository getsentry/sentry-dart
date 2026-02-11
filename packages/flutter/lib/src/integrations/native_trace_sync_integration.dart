// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';

/// Synchronizes the Dart [PropagationContext] to the native SDK so that
/// native crashes/errors share the same trace as Dart events.
@internal
class NativeTraceSyncIntegration implements Integration<SentryFlutterOptions> {
  static const integrationName = 'NativeTraceSync';
  final SentryNativeBinding _native;
  SentryOptions? _options;

  NativeTraceSyncIntegration(this._native);

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    options.lifecycleRegistry
        .registerCallback<OnTraceReset>(_syncTraceToNative);
    options.sdk.addIntegration(integrationName);

    // Sync the initial PropagationContext created at Hub construction.
    _syncTraceToNative(OnTraceReset(hub.scope.propagationContext));
  }

  @override
  void close() {
    _options?.lifecycleRegistry
        .removeCallback<OnTraceReset>(_syncTraceToNative);
  }

  void _syncTraceToNative(OnTraceReset event) {
    final ctx = event.propagationContext;
    _native.setTrace(ctx.traceId, sampleRand: ctx.sampleRand);
  }
}
