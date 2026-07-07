// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import '../../sentry_flutter.dart';
import '../utils/internal_logger.dart';
import 'app_start_info.dart';

const _appStartTypeKey = 'app_start_type';

@internal
final class StaticAppStartSpanWriter {
  StaticAppStartSpanWriter({required Hub hub}) : _hub = hub;

  final Hub _hub;

  Future<void> writeAttached(
    SentryTracer transaction,
    AppStartInfo appStartInfo,
  ) async {
    transaction.setData(_appStartTypeKey, appStartInfo.type.name);

    // Measurements must be added before child spans. If a child span finishes
    // the transaction, measurements can no longer be added.
    final measurement = appStartInfo.toMeasurement();
    transaction.measurements[measurement.name] = measurement;

    await _attachAppStartSpans(
      appStartInfo,
      transaction,
      standalone: false,
    );
  }

  Future<void> writeStandalone(
    SentryTracer transaction,
    AppStartInfo appStartInfo,
  ) async {
    await _attachAppStartSpans(
      appStartInfo,
      transaction,
      standalone: true,
    );
  }

  /// Writes standalone app-start values in the transaction finish path, so a
  /// deferred finalization can stamp the final values at the actual end.
  void writeStandaloneEncoding(
    ISentrySpan transaction,
    AppStartInfo appStartInfo,
  ) {
    if (transaction is! SentryTracer) {
      return;
    }
    transaction.setData(_appStartTypeKey, appStartInfo.type.name);
    transaction.setData(
      SemanticAttributesConstants.appVitalsStartValue,
      appStartInfo.duration.inMilliseconds.toDouble(),
    );
    transaction.setData(
      SemanticAttributesConstants.appVitalsStartType,
      appStartInfo.type.name,
    );
    final measurement = appStartInfo.toMeasurement();
    transaction.measurements[measurement.name] = measurement;
  }

  Future<void> _attachAppStartSpans(
    AppStartInfo appStartInfo,
    SentryTracer transaction, {
    required bool standalone,
  }) async {
    final transactionTraceId = transaction.context.traceId;
    final appStartEnd = appStartInfo.end;
    // The attached shape predates span origins and keeps them unset; the
    // standalone shape is new, so its breakdown spans carry the auto origin.
    final origin = standalone ? SentryTraceOrigins.autoAppStart : null;

    // The standalone root already represents the app start, so breakdown spans
    // attach directly to it. The attached shape keeps them nested under the
    // per-type wrapper span.
    SentrySpan? appStartSpan;
    if (!standalone) {
      appStartSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: appStartInfo.appStartTypeOperation,
        description: appStartInfo.appStartTypeDescription,
        origin: origin,
        parentSpanId: transaction.context.spanId,
        traceId: transactionTraceId,
        startTimestamp: appStartInfo.start,
        endTimestamp: appStartEnd,
        appStartType: appStartInfo.type.name,
      );
    }
    final parentSpanId =
        appStartSpan?.context.spanId ?? transaction.context.spanId;
    String operationFor(String standaloneOperation) =>
        standalone ? standaloneOperation : appStartInfo.appStartTypeOperation;

    await _attachNativeSpans(
      appStartInfo,
      transaction,
      parentSpanId,
      operation: operationFor(SentrySpanOperations.appStartNative),
      origin: origin,
    );

    final pluginRegistrationSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: operationFor(SentrySpanOperations.appStartPluginRegistration),
      description: AppStartInfo.pluginRegistrationDescription,
      origin: origin,
      parentSpanId: parentSpanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.start,
      endTimestamp: appStartInfo.pluginRegistration,
      appStartType: appStartInfo.type.name,
    );

    final sentrySetupSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: operationFor(SentrySpanOperations.appStartSentrySetup),
      description: AppStartInfo.sentrySetupDescription,
      origin: origin,
      parentSpanId: parentSpanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.pluginRegistration,
      endTimestamp: appStartInfo.sentrySetupStart,
      appStartType: appStartInfo.type.name,
    );

    final firstFrameRenderSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: operationFor(SentrySpanOperations.appStartFirstFrameRender),
      description: AppStartInfo.firstFrameRenderDescription,
      origin: origin,
      parentSpanId: parentSpanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.sentrySetupStart,
      endTimestamp: appStartEnd,
      appStartType: appStartInfo.type.name,
    );

    transaction.children.addAll([
      if (appStartSpan != null) appStartSpan,
      pluginRegistrationSpan,
      sentrySetupSpan,
      firstFrameRenderSpan
    ]);
  }

  Future<void> _attachNativeSpans(
    AppStartInfo appStartInfo,
    SentryTracer transaction,
    SpanId parentSpanId, {
    required String operation,
    required String? origin,
  }) async {
    for (final timeSpan in appStartInfo.nativeSpanTimes) {
      try {
        final span = await _createAndFinishSpan(
          tracer: transaction,
          operation: operation,
          description: timeSpan.description,
          origin: origin,
          parentSpanId: parentSpanId,
          traceId: transaction.context.traceId,
          startTimestamp: timeSpan.start,
          endTimestamp: timeSpan.end,
          appStartType: appStartInfo.type.name,
        );
        span.data.putIfAbsent('native', () => true);
        transaction.children.add(span);
      } catch (error, stackTrace) {
        internalLogger.warning(
          'Failed to attach native span to app start transaction',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<SentrySpan> _createAndFinishSpan({
    required SentryTracer tracer,
    required String operation,
    required String description,
    required String? origin,
    required SpanId parentSpanId,
    required SentryId traceId,
    required DateTime startTimestamp,
    required DateTime endTimestamp,
    required String appStartType,
  }) async {
    final span = SentrySpan(
      tracer,
      SentrySpanContext(
        operation: operation,
        description: description,
        origin: origin,
        parentSpanId: parentSpanId,
        traceId: traceId,
      ),
      _hub,
      startTimestamp: startTimestamp,
    );
    span.setData(_appStartTypeKey, appStartType);
    await span.finish(endTimestamp: endTimestamp);
    return span;
  }
}
