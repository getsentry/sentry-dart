// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';
import '../native/sentry_native_binding.dart';

/// Integration that adds replay-related information to logs and metrics
/// using lifecycle callbacks.
@internal
class ReplayTelemetryIntegration implements Integration<SentryFlutterOptions> {
  static const String integrationName = 'ReplayTelemetry';

  final SentryNativeBinding? _native;
  ReplayTelemetryIntegration(this._native);

  SentryFlutterOptions? _options;
  SdkLifecycleCallback<OnProcessLog>? _onProcessLog;
  SdkLifecycleCallback<OnProcessMetric>? _onProcessMetric;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    if (!options.replay.isEnabled) {
      return;
    }
    final sessionSampleRate = options.replay.sessionSampleRate ?? 0;
    final onErrorSampleRate = options.replay.onErrorSampleRate ?? 0;

    _options = options;

    _onProcessLog = (OnProcessLog event) {
      _addReplayAttributes(
        hub.scope.replayId,
        event.log.attributes,
        sessionSampleRate: sessionSampleRate,
        onErrorSampleRate: onErrorSampleRate,
      );
    };

    _onProcessMetric = (OnProcessMetric event) {
      _addReplayAttributes(
        hub.scope.replayId,
        event.metric.attributes,
        sessionSampleRate: sessionSampleRate,
        onErrorSampleRate: onErrorSampleRate,
      );
    };

    options.lifecycleRegistry.registerCallback<OnProcessLog>(_onProcessLog!);
    options.lifecycleRegistry
        .registerCallback<OnProcessMetric>(_onProcessMetric!);
    options.sdk.addIntegration(integrationName);
  }

  void _addReplayAttributes(
    SentryId? scopeReplayId,
    Map<String, SentryAttribute> attributes, {
    required double sessionSampleRate,
    required double onErrorSampleRate,
  }) {
    final replayId = scopeReplayId ?? _native?.replayId;
    final replayIsBuffering = replayId != null && scopeReplayId == null;

    if (sessionSampleRate > 0 && replayId != null && !replayIsBuffering) {
      attributes[SemanticAttributesConstants.sentryReplayId] =
          SentryAttribute.string(scopeReplayId.toString());
    } else if (onErrorSampleRate > 0 && replayId != null && replayIsBuffering) {
      attributes[SemanticAttributesConstants.sentryReplayId] =
          SentryAttribute.string(replayId.toString());
      attributes[SemanticAttributesConstants.sentryInternalReplayIsBuffering] =
          SentryAttribute.bool(true);
    }
  }

  @override
  Future<void> close() async {
    final options = _options;
    final onProcessLog = _onProcessLog;
    final onProcessMetric = _onProcessMetric;

    if (options != null) {
      if (onProcessLog != null) {
        options.lifecycleRegistry.removeCallback<OnProcessLog>(onProcessLog);
      }
      if (onProcessMetric != null) {
        options.lifecycleRegistry
            .removeCallback<OnProcessMetric>(onProcessMetric);
      }
    }

    _options = null;
    _onProcessLog = null;
    _onProcessMetric = null;
  }
}
