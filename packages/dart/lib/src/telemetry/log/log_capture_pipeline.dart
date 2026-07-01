import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../client_reports/discard_reason.dart';
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
        // TODO(major-v10): this can be removed once we make the traceId required on the log
        if (log.traceId == null || log.traceId == SentryId.empty()) {
          log.traceId = scope.propagationContext.traceId;
        }
        log.attributes.addAllIfAbsent(scope.attributes);
      }

      final hint = Hint();

      await _options.lifecycleRegistry
          .dispatchCallback<OnProcessLog>(OnProcessLog(log, hint));

      log.attributes.addAllIfAbsent(defaultAttributes(_options, scope: scope));

      final beforeSendLog = _options.beforeSendLog;
      SentryLog? processedLog = log;
      if (beforeSendLog != null) {
        try {
          final callbackResult = beforeSendLog(log, hint);

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
        _options.recorder.recordLostLog(
          DiscardReason.beforeSend,
          bytes: _approximateLogBytes(log),
        );
        internalLogger.debug(
            '$LogCapturePipeline: Log "${log.body}" dropped by beforeSendLog');
        return;
      }

      _options.telemetryProcessor.addLog(processedLog);
    } catch (exception, stackTrace) {
      _options.recorder.recordLostLog(
        DiscardReason.internalSdkError,
        bytes: _approximateLogBytes(log),
      );
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

int? _approximateLogBytes(SentryLog log) {
  try {
    return utf8JsonEncoder.convert(log.toJson()).length;
  } catch (exception, stackTrace) {
    internalLogger.warning(
      'Failed to estimate dropped log size',
      error: exception,
      stackTrace: stackTrace,
    );
    return null;
  }
}
