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
  SdkLifecycleCallback<OnTransactionCaptured>? _onTransactionCaptured;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    if (!options.replay.isEnabled) {
      return;
    }
    final sessionSampleRate = options.replay.sessionSampleRate ?? 0;
    final onErrorSampleRate = options.replay.onErrorSampleRate ?? 0;

    _options = options;

    _onProcessLog = (OnProcessLog event) {
      final attributes = _replayAttributes(
        hub.scope.replayId,
        sessionSampleRate: sessionSampleRate,
        onErrorSampleRate: onErrorSampleRate,
      );
      if (attributes != null) {
        event.log.attributes.addAll(attributes);
      }
    };

    _onProcessMetric = (OnProcessMetric event) {
      final attributes = _replayAttributes(
        hub.scope.replayId,
        sessionSampleRate: sessionSampleRate,
        onErrorSampleRate: onErrorSampleRate,
      );
      if (attributes != null) {
        event.metric.attributes.addAll(attributes);
      }
    };

    _onProcessSpan = (OnProcessSpan event) {
      final attributes = _replayAttributes(
        hub.scope.replayId,
        sessionSampleRate: sessionSampleRate,
        onErrorSampleRate: onErrorSampleRate,
      );
      if (attributes != null) {
        event.span.setAttributes(attributes);
      }
      final segmentSpan = event.span.segmentSpan;
      if (identical(event.span, segmentSpan)) {
        _native?.registerTraceId(segmentSpan.traceId);
      }
    };

    _onTransactionCaptured = (OnTransactionCaptured event) {
      _native?.registerTraceId(event.traceId);
    };

    options.lifecycleRegistry.registerCallback<OnProcessLog>(_onProcessLog!);
    options.lifecycleRegistry
        .registerCallback<OnProcessMetric>(_onProcessMetric!);
    options.lifecycleRegistry.registerCallback<OnProcessSpan>(_onProcessSpan!);
    options.lifecycleRegistry
        .registerCallback<OnTransactionCaptured>(_onTransactionCaptured!);
    options.sdk.addIntegration(integrationName);
  }

  ({SentryId replayId, bool replayIsBuffering})? _replayContext(
    SentryId? scopeReplayId, {
    required double sessionSampleRate,
    required double onErrorSampleRate,
  }) {
    final replayId = scopeReplayId ?? _native?.replayId;
    final replayIsBuffering = replayId != null && scopeReplayId == null;

    if (sessionSampleRate > 0 && replayId != null && !replayIsBuffering) {
      return (replayId: replayId, replayIsBuffering: replayIsBuffering);
    } else if (onErrorSampleRate > 0 && replayId != null && replayIsBuffering) {
      return (replayId: replayId, replayIsBuffering: replayIsBuffering);
    }
    return null;
  }

  Map<String, SentryAttribute>? _replayAttributes(
    SentryId? scopeReplayId, {
    required double sessionSampleRate,
    required double onErrorSampleRate,
  }) {
    final replayContext = _replayContext(
      scopeReplayId,
      sessionSampleRate: sessionSampleRate,
      onErrorSampleRate: onErrorSampleRate,
    );
    if (replayContext == null) {
      return null;
    }

    return {
      SemanticAttributesConstants.sentryReplayId:
          SentryAttribute.string(replayContext.replayId.toString()),
      if (replayContext.replayIsBuffering)
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
    final onTransactionCaptured = _onTransactionCaptured;

    if (options != null) {
      if (onProcessLog != null) {
        options.lifecycleRegistry.removeCallback<OnProcessLog>(onProcessLog);
      }
      if (onProcessMetric != null) {
        options.lifecycleRegistry
            .removeCallback<OnProcessMetric>(onProcessMetric);
      }
      if (onProcessSpan != null) {
        options.lifecycleRegistry.removeCallback<OnProcessSpan>(onProcessSpan);
      }
      if (onTransactionCaptured != null) {
        options.lifecycleRegistry
            .removeCallback<OnTransactionCaptured>(onTransactionCaptured);
      }
    }

    _options = null;
    _onProcessLog = null;
    _onProcessMetric = null;
    _onProcessSpan = null;
    _onTransactionCaptured = null;
  }
}
