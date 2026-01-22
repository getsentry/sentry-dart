import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../client_reports/discard_reason.dart';
import '../../transport/data_category.dart';
import '../../utils/internal_logger.dart';
import '../default_attributes.dart';

@internal
class MetricCapturePipeline {
  final SentryOptions _options;

  MetricCapturePipeline(this._options);

  Future<void> captureMetric(SentryMetric metric, {Scope? scope}) async {
    if (!_options.enableMetrics) {
      internalLogger.debug(
          '$MetricCapturePipeline: Metrics disabled, dropping ${metric.name}');
      return;
    }

    try {
      if (scope != null) {
        metric.attributes.addAllIfAbsent(scope.attributes);
      }

      await _options.lifecycleRegistry
          .dispatchCallback<OnProcessMetric>(OnProcessMetric(metric));

      metric.attributes
          .addAllIfAbsent(defaultAttributes(_options, scope: scope));

      final beforeSendMetric = _options.beforeSendMetric;
      SentryMetric? processedMetric = metric;
      if (beforeSendMetric != null) {
        try {
          processedMetric = await beforeSendMetric(metric);
        } catch (exception, stackTrace) {
          _options.log(
            SentryLevel.error,
            'The beforeSendMetric callback threw an exception',
            exception: exception,
            stackTrace: stackTrace,
          );
          if (_options.automatedTestMode) {
            rethrow;
          }
        }
      }
      if (processedMetric == null) {
        _options.recorder
            .recordLostEvent(DiscardReason.beforeSend, DataCategory.metric);
        internalLogger.debug(
            '$MetricCapturePipeline: Metric ${metric.name} dropped by beforeSendMetric');
        return;
      }

      _options.telemetryProcessor.addMetric(processedMetric);
      internalLogger.debug(
          '$MetricCapturePipeline: Metric ${processedMetric.name} (${processedMetric.type}) captured');
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Error capturing metric ${metric.name}',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
    }
  }
}
