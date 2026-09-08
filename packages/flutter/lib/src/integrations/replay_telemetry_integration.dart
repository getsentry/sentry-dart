// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';
import '../native/sentry_native_binding.dart';

/// Integration that adds replay-related information to telemetry
/// using lifecycle callbacks.
@internal
class ReplayTelemetryIntegration implements Integration<SentryFlutterOptions> {
  static const String integrationName = 'ReplayTelemetry';

  final SentryNativeBinding? _native;
  ReplayTelemetryIntegration(this._native);

  SentryFlutterOptions? _options;
  SdkLifecycleCallback<OnProcessLog>? _onProcessLog;
  SdkLifecycleCallback<OnProcessMetric>? _onProcessMetric;
  SdkLifecycleCallback<OnProcessSpan>? _onProcessSpan;
  SdkLifecycleCallback<OnGenerateNewTrace>? _onGenerateNewTrace;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    // Deliberately not gated on `options.replay.isEnabled`: with both sample
    // rates at zero a replay can still be started through `SentryFlutter.replay`.
    // Registering unconditionally is safe because `_replayAttributes` keys off
    // whether a replay is actually recording, not off the configuration.
    _options = options;

    _onProcessLog = (OnProcessLog event) {
      final attributes = _replayAttributes(hub.scope.replayId);
      if (attributes != null) {
        event.log.attributes.addAll(attributes);
      }
    };

    _onProcessMetric = (OnProcessMetric event) {
      final attributes = _replayAttributes(hub.scope.replayId);
      if (attributes != null) {
        event.metric.attributes.addAll(attributes);
      }
    };

    _onProcessSpan = (OnProcessSpan event) {
      final attributes = _replayAttributes(hub.scope.replayId);
      if (attributes != null) {
        event.span.setAttributes(attributes);
      }

      final span = event.span;
      if (identical(span, span.segmentSpan)) {
        return _native?.registerSegmentName(span.name);
      }
    };

    _onGenerateNewTrace = (OnGenerateNewTrace event) async {
      await _native?.registerTraceId(event.traceId);
    };

    // Register the initial trace id. Subsequent changes are handled by the callback.
    await _native?.registerTraceId(hub.scope.propagationContext.traceId);

    options.lifecycleRegistry.registerCallback<OnProcessLog>(_onProcessLog!);
    options.lifecycleRegistry.registerCallback<OnProcessMetric>(
      _onProcessMetric!,
    );
    options.lifecycleRegistry.registerCallback<OnProcessSpan>(_onProcessSpan!);
    options.lifecycleRegistry.registerCallback<OnGenerateNewTrace>(
      _onGenerateNewTrace!,
    );
    options.sdk.addIntegration(integrationName);
  }

  /// Attributes describing the replay that is currently recording, or `null`
  /// when none is.
  ///
  /// Derived from live SDK state rather than from the sample rates, so replays
  /// started manually through `SentryFlutter.replay` are covered too.
  Map<String, SentryAttribute>? _replayAttributes(SentryId? scopeReplayId) {
    final replayId = scopeReplayId ?? _native?.replayId;
    if (replayId == null || replayId == SentryId.empty()) {
      return null;
    }

    // Both native layers put the replay ID on the scope only while recording in
    // session mode, so an ID the binding knows about but the scope doesn't
    // belongs to a replay that is still buffering.
    final isBuffering = scopeReplayId == null;

    return {
      SemanticAttributesConstants.sentryReplayId: SentryAttribute.string(
        replayId.toString(),
      ),
      if (isBuffering)
        SemanticAttributesConstants.sentryInternalReplayIsBuffering:
            SentryAttribute.bool(true),
    };
  }

  @override
  Future<void> close() async {
    final options = _options;
    final onProcessLog = _onProcessLog;
    final onProcessMetric = _onProcessMetric;
    final onProcessSpan = _onProcessSpan;
    final onGenerateNewTrace = _onGenerateNewTrace;

    if (options != null) {
      if (onProcessLog != null) {
        options.lifecycleRegistry.removeCallback<OnProcessLog>(onProcessLog);
      }
      if (onProcessMetric != null) {
        options.lifecycleRegistry.removeCallback<OnProcessMetric>(
          onProcessMetric,
        );
      }
      if (onProcessSpan != null) {
        options.lifecycleRegistry.removeCallback<OnProcessSpan>(onProcessSpan);
      }
      if (onGenerateNewTrace != null) {
        options.lifecycleRegistry.removeCallback<OnGenerateNewTrace>(
          onGenerateNewTrace,
        );
      }
    }

    _options = null;
    _onProcessLog = null;
    _onProcessMetric = null;
    _onProcessSpan = null;
    _onGenerateNewTrace = null;
  }
}
