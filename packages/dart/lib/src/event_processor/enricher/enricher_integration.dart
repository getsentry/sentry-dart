import 'dart:async';

import 'package:meta/meta.dart';

import '../../hub.dart';
import '../../integration.dart';
import '../../protocol.dart';
import '../../sdk_lifecycle_hooks.dart';
import '../../sentry_options.dart';
import '../../telemetry/default_attributes.dart';
import '../../telemetry/sentry_trace_lifecycle.dart';
import '../../utils.dart';
import '../../utils/internal_logger.dart';
import 'enricher_event_processor.dart';

/// Registers an [EnricherEventProcessor] for events and wires its
/// platform-derived contexts onto logs, metrics, and spans via lifecycle
/// callbacks.
///
/// On the attribute path, non-segment spans plus logs and metrics receive
/// only the device and os attributes in [minimalContextAttributes]. Segment
/// spans receive the full [Contexts.toAttributes] projection.
///
/// Attributes are always added with `addAllIfAbsent` semantics so richer
/// data set by other producers (e.g. native integrations) wins.
@internal
class EnricherIntegration implements Integration<SentryOptions> {
  EnricherIntegration(this._enricher);

  final EnricherEventProcessor _enricher;

  SentryOptions? _options;
  SdkLifecycleCallback<OnProcessLog>? _logCallback;
  SdkLifecycleCallback<OnProcessMetric>? _metricCallback;
  SdkLifecycleCallback<OnProcessSpan>? _spanCallback;

  @override
  void call(Hub hub, SentryOptions options) {
    _options = options;
    options.addEventProcessor(_enricher);

    if (options.enableLogs) {
      _logCallback = (event) async {
        try {
          event.log.attributes.addAllIfAbsent(await _minimalAttributes());
        } catch (exception, stackTrace) {
          internalLogger.error(
            'EnricherIntegration failed to build contexts for $OnProcessLog',
            error: exception,
            stackTrace: stackTrace,
          );
        }
      };
      options.lifecycleRegistry.registerCallback<OnProcessLog>(_logCallback!);
    }

    if (options.enableMetrics) {
      _metricCallback = (event) async {
        try {
          event.metric.attributes.addAllIfAbsent(await _minimalAttributes());
        } catch (exception, stackTrace) {
          internalLogger.error(
            'EnricherIntegration failed to build contexts for $OnProcessMetric',
            error: exception,
            stackTrace: stackTrace,
          );
        }
      };
      options.lifecycleRegistry
          .registerCallback<OnProcessMetric>(_metricCallback!);
    }

    if (options.traceLifecycle == SentryTraceLifecycle.stream) {
      _spanCallback = (event) async {
        try {
          final span = event.span;
          final contexts = await _enricher.buildContexts();
          final attributes = identical(span, span.segmentSpan)
              ? contexts.toAttributes()
              : _filterMinimal(contexts);
          span.setAttributesIfAbsent(attributes);
        } catch (exception, stackTrace) {
          internalLogger.error(
            'EnricherIntegration failed to build contexts for $OnProcessSpan',
            error: exception,
            stackTrace: stackTrace,
          );
        }
      };
      options.lifecycleRegistry.registerCallback<OnProcessSpan>(_spanCallback!);
    }

    options.sdk.addIntegration('Enricher');
  }

  @override
  void close() {
    final options = _options;
    if (options == null) return;

    if (_logCallback != null) {
      options.lifecycleRegistry.removeCallback<OnProcessLog>(_logCallback!);
      _logCallback = null;
    }
    if (_metricCallback != null) {
      options.lifecycleRegistry
          .removeCallback<OnProcessMetric>(_metricCallback!);
      _metricCallback = null;
    }
    if (_spanCallback != null) {
      options.lifecycleRegistry.removeCallback<OnProcessSpan>(_spanCallback!);
      _spanCallback = null;
    }
  }

  Future<Map<String, SentryAttribute>> _minimalAttributes() async {
    return _filterMinimal(await _enricher.buildContexts());
  }

  Map<String, SentryAttribute> _filterMinimal(Contexts contexts) {
    final full = contexts.toAttributes();
    return {
      for (final key in minimalContextAttributes)
        if (full.containsKey(key)) key: full[key]!,
    };
  }
}
