// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import '../../sentry_flutter.dart';
import '../navigation/time_to_display_tracker.dart';
import '../utils/internal_logger.dart';
import 'app_start_emitter.dart';
import 'app_start_info.dart';

const _appStartTypeKey = 'app_start_type';

@internal
final class StaticAppStartEmitter implements AppStartEmitter {
  StaticAppStartEmitter({
    required Hub hub,
    required SentryTransactionContext context,
    required TimeToDisplayTracker timeToDisplayTracker,
    required bool standalone,
  })  : _hub = hub,
        _context = context,
        _timeToDisplayTracker = timeToDisplayTracker,
        _standalone = standalone;

  final Hub _hub;
  final SentryTransactionContext _context;
  final TimeToDisplayTracker _timeToDisplayTracker;
  final bool _standalone;

  @override
  Future<void> emit(AppStartInfo appStartInfo) async {
    final rootScreenTransaction = _hub.startTransactionWithContext(
      _context,
      startTimestamp: appStartInfo.start,
      waitForChildren: true,
      autoFinishAfter: const Duration(seconds: 3),
      bindToScope: true,
      trimEnd: true,
    );
    if (rootScreenTransaction is! SentryTracer) {
      return;
    }

    if (_standalone) {
      // Start TTID/TTFD tracking before awaiting the standalone capture: the
      // ui.load root's autoFinishAfter timer is already running and the
      // capture can block on transport. Tracking first attaches the TTID
      // child, so the root cannot auto-finish childless (and be dropped)
      // while the standalone transaction is being sent.
      final displayTracking = _timeToDisplayTracker.track(
        rootScreenTransaction,
        ttidEndTimestamp: appStartInfo.end,
      );
      await _emitStandalone(appStartInfo);
      await displayTracking;
      return;
    }

    _writeAttachedEncoding(rootScreenTransaction, appStartInfo);
    await _attachAppStartSpans(appStartInfo, rootScreenTransaction,
        standalone: false);

    await _timeToDisplayTracker.track(
      rootScreenTransaction,
      ttidEndTimestamp: appStartInfo.end,
    );
  }

  @override
  void cancel() {
    // Static app start only reserves an ID at setup; emit creates the transaction.
  }

  Future<void> _emitStandalone(AppStartInfo appStartInfo) async {
    final transaction = _hub.startTransactionWithContext(
      SentryTransactionContext(
        'App Start',
        SentrySpanOperations.appStart,
        origin: SentryTraceOrigins.autoAppStart,
      ),
      startTimestamp: appStartInfo.start,
      waitForChildren: true,
      autoFinishAfter: const Duration(seconds: 30),
      // No trimEnd: the explicit finish timestamp below is authoritative;
      // trimming would let an out-of-range native span time stretch the
      // transaction past the measured app start end, making its duration
      // disagree with the app start measurement.
      onFinish: (transaction) =>
          _writeStandaloneEncoding(transaction, appStartInfo),
    );
    if (transaction is! SentryTracer) {
      return;
    }
    await _attachAppStartSpans(appStartInfo, transaction, standalone: true);
    await transaction.finish(endTimestamp: appStartInfo.end);
  }

  void _writeAttachedEncoding(
    SentryTracer transaction,
    AppStartInfo appStartInfo,
  ) {
    transaction.setData(_appStartTypeKey, appStartInfo.type.name);

    // We need to add the measurements before we add the child spans. If a
    // child span finishes the transaction, measurements can no longer be added.
    final measurement = appStartInfo.toMeasurement();
    transaction.measurements[measurement.name] = measurement;
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

    // The standalone root already represents the app start, so the breakdown
    // spans attach directly to it with dedicated operations; the attached
    // shape keeps nesting them under a per-type wrapper span.
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
