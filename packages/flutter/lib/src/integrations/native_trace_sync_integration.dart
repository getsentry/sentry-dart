// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';
import '../utils/internal_logger.dart';

@internal
class NativeTraceSyncIntegration implements Integration<SentryFlutterOptions> {
  static const integrationName = 'NativeTraceSync';
  final SentryNativeBinding _native;
  SentryOptions? _options;

  NativeTraceSyncIntegration(this._native);

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    if (!options.enableNativeTraceSync) {
      internalLogger.info('$integrationName: disabled, skipping setup');
      return;
    }

    _options = options;
    options.lifecycleRegistry
        .registerCallback<OnTraceReset>(_syncTraceToNative);
    options.sdk.addIntegration(integrationName);

    final traceId = hub.scope.propagationContext.traceId;
    final spanId = hub.getSpan()?.context.spanId ?? SpanId.newId();

    // Sync the initial PropagationContext created at Hub construction.
    _syncTraceToNative(OnTraceReset(traceId, spanId));
  }

  @override
  void close() {
    _options?.lifecycleRegistry
        .removeCallback<OnTraceReset>(_syncTraceToNative);
  }

  void _syncTraceToNative(OnTraceReset event) {
    _native.setTrace(event.traceId, event.spanId);
  }
}
