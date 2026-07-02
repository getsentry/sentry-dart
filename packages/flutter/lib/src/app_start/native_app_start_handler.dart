// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../utils/internal_logger.dart';
import 'app_start_info.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';
import 'dart:async';

/// Static-lifecycle adapter that maps [AppStartInfo] onto v1 transactions.
///
/// Owned by the app start tracker; not a seam on its own.
@internal
class NativeAppStartHandler {
  late Hub _hub;

  Future<void> call(
    Hub hub,
    SentryFlutterOptions options, {
    required SentryTransactionContext context,
    required AppStartInfo appStartInfo,
    required bool standalone,
  }) async {
    _hub = hub;

    final rootScreenTransaction = _hub.startTransactionWithContext(
      context,
      startTimestamp: appStartInfo.start,
      waitForChildren: true,
      autoFinishAfter: Duration(seconds: 3),
      bindToScope: true,
      trimEnd: true,
    );

    SentryTracer sentryTracer;
    if (rootScreenTransaction is SentryTracer) {
      sentryTracer = rootScreenTransaction;
    } else {
      return;
    }

    if (standalone) {
      await _trackStandalone(appStartInfo);
    } else {
      sentryTracer.setData("app_start_type", appStartInfo.type.name);

      // We need to add the measurements before we add the child spans
      // If the child span finish the transaction will finish and then we cannot add measurements
      SentryMeasurement? measurement = appStartInfo.toMeasurement();
      sentryTracer.measurements[measurement.name] = measurement;

      await _attachAppStartSpans(appStartInfo, sentryTracer, standalone: false);
    }

    await options.timeToDisplayTracker.track(
      rootScreenTransaction,
      ttidEndTimestamp: appStartInfo.end,
    );
  }

  Future<void> _trackStandalone(AppStartInfo appStartInfo) async {
    final transaction = _hub.startTransactionWithContext(
      SentryTransactionContext(
        'App Start',
        SentrySpanOperations.appStart,
        origin: SentryTraceOrigins.autoAppStart,
      ),
      startTimestamp: appStartInfo.start,
      waitForChildren: true,
      autoFinishAfter: Duration(seconds: 30),
      trimEnd: true,
      onFinish: (transaction) =>
          _writeStandaloneEncoding(transaction, appStartInfo),
    );
    if (transaction is! SentryTracer) {
      return;
    }
    await _attachAppStartSpans(appStartInfo, transaction, standalone: true);
    await transaction.finish(endTimestamp: appStartInfo.end);
  }

  /// Writes the app start measurement in the transaction's finish path, so a
  /// deferred finalization (e.g. an extended app start) picks up the final
  /// values.
  void _writeStandaloneEncoding(
    ISentrySpan transaction,
    AppStartInfo appStartInfo,
  ) {
    if (transaction is! SentryTracer) {
      return;
    }
    transaction.setData("app_start_type", appStartInfo.type.name);
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

    // The standalone root already represents the app start, so the breakdown
    // spans attach directly to it with dedicated operations; the attached
    // shape keeps nesting them under a per-type wrapper span.
    SentrySpan? appStartSpan;
    if (!standalone) {
      appStartSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: appStartInfo.appStartTypeOperation,
        description: appStartInfo.appStartTypeDescription,
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
    );

    final pluginRegistrationSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: operationFor(SentrySpanOperations.appStartPluginRegistration),
      description: appStartInfo.pluginRegistrationDescription,
      parentSpanId: parentSpanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.start,
      endTimestamp: appStartInfo.pluginRegistration,
      appStartType: appStartInfo.type.name,
    );

    final sentrySetupSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: operationFor(SentrySpanOperations.appStartSentrySetup),
      description: appStartInfo.sentrySetupDescription,
      parentSpanId: parentSpanId,
      traceId: transactionTraceId,
      startTimestamp: appStartInfo.pluginRegistration,
      endTimestamp: appStartInfo.sentrySetupStart,
      appStartType: appStartInfo.type.name,
    );

    final firstFrameRenderSpan = await _createAndFinishSpan(
      tracer: transaction,
      operation: operationFor(SentrySpanOperations.appStartFirstFrameRender),
      description: appStartInfo.firstFrameRenderDescription,
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
  }) async {
    await Future.forEach<TimeSpan>(appStartInfo.nativeSpanTimes,
        (timeSpan) async {
      try {
        final span = await _createAndFinishSpan(
          tracer: transaction,
          operation: operation,
          description: timeSpan.description,
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
    });
  }

  Future<SentrySpan> _createAndFinishSpan({
    required SentryTracer tracer,
    required String operation,
    required String description,
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
        parentSpanId: parentSpanId,
        traceId: traceId,
      ),
      _hub,
      startTimestamp: startTimestamp,
    );
    span.setData("app_start_type", appStartType);
    await span.finish(endTimestamp: endTimestamp);
    return span;
  }
}
