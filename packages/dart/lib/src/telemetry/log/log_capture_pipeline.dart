import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../client_reports/discard_reason.dart';
import '../../transport/data_category.dart';
import '../../utils/internal_logger.dart';
import '../default_attributes.dart';

@internal
class LogCapturePipeline {
  final SentryOptions _options;

  LogCapturePipeline(this._options);

  FutureOr<void> captureLog(SentryLog log, {Scope? scope}) async {
    if (!_options.enableLogs) {
      internalLogger
          .debug('$LogCapturePipeline: Logs disabled, dropping ${log.body}');
      return;
    }

    try {
      if (scope != null) {
        // Populate traceId from scope if not already set
        if (log.traceId == null || log.traceId == SentryId.empty()) {
          log.traceId = scope.propagationContext.traceId;
        }
        log.attributes.addAllIfAbsent(scope.attributes);
      }

      await _options.lifecycleRegistry
          .dispatchCallback<OnProcessLog>(OnProcessLog(log));

      log.attributes.addAllIfAbsent(defaultAttributes(_options, scope: scope));

      final beforeSendLog = _options.beforeSendLog;
      SentryLog? processedLog = log;
      if (beforeSendLog != null) {
        try {
          final callbackResult = beforeSendLog(log);

          if (callbackResult is Future<SentryLog?>) {
            processedLog = await callbackResult;
          } else {
            processedLog = callbackResult;
          }
        } catch (exception, stackTrace) {
          internalLogger.error(
            'The beforeSendLog callback threw an exception',
            error: exception,
            stackTrace: stackTrace,
          );
          if (_options.automatedTestMode) {
            rethrow;
          }
        }
      }

      if (processedLog == null) {
        _options.recorder
            .recordLostEvent(DiscardReason.beforeSend, DataCategory.logItem);
        internalLogger.debug(
            '$LogCapturePipeline: Log "${log.body}" dropped by beforeSendLog');
        return;
      }

      _options.telemetryProcessor.addLog(processedLog);
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Error capturing log "${log.body}"',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
    }
  }
}
