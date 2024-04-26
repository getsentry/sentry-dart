// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import '../../sentry_flutter.dart';
import '../integrations/integrations.dart';
import '../native/sentry_native.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
class NativeAppStartEventProcessor implements EventProcessor {
  final SentryNative _native;
  final Hub _hub;

  NativeAppStartEventProcessor(
    this._native, {
    Hub? hub,
  }) : _hub = hub ?? HubAdapter();

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (_native.didAddAppStartMeasurement || event is! SentryTransaction) {
      return event;
    }

    final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();
    final measurement = appStartInfo?.toMeasurement();

    if (measurement != null) {
      event.measurements[measurement.name] = measurement;
      _native.didAddAppStartMeasurement = true;
    }

    final transaction = event.tracer;
    if (appStartInfo != null) {
      await _attachAppStartSpans(appStartInfo, transaction);
    }

    return event;
  }

  Future<void> _attachAppStartSpans(
      AppStartInfo appStartInfo, SentryTracer transaction) async {
    final op = 'app.start.${appStartInfo.type.name}';
    final transactionTraceId = transaction.context.traceId;

    final appStartSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: op,
        description: '${appStartInfo.type.name.capitalize()} start',
        parentSpanId: transaction.context.spanId,
        traceId: transactionTraceId,
        startTimestamp: appStartInfo.start,
        endTimestamp: appStartInfo.end);

    final pluginRegistrationSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: op,
        description: AppStartSpanDescriptions.pluginRegistration,
        parentSpanId: appStartSpan.context.spanId,
        traceId: transactionTraceId,
        startTimestamp: appStartInfo.start,
        endTimestamp: appStartInfo.pluginRegistration);

    final mainIsolateSetupSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: op,
        description: AppStartSpanDescriptions.mainIsolateSetup,
        parentSpanId: appStartSpan.context.spanId,
        traceId: transactionTraceId,
        startTimestamp: appStartInfo.pluginRegistration,
        endTimestamp: appStartInfo.mainIsolateStart);

    final firstFrameRenderSpan = await _createAndFinishSpan(
        tracer: transaction,
        operation: op,
        description: AppStartSpanDescriptions.firstFrameRender,
        parentSpanId: appStartSpan.context.spanId,
        traceId: transactionTraceId,
        startTimestamp: SentryFlutter.mainIsolateStartTime,
        endTimestamp: appStartInfo.end);

    transaction.children.addAll([
      appStartSpan,
      pluginRegistrationSpan,
      mainIsolateSetupSpan,
      firstFrameRenderSpan
    ]);
  }

  Future<SentrySpan> _createAndFinishSpan({
    required SentryTracer tracer,
    required String operation,
    required String description,
    required SpanId? parentSpanId,
    required SentryId? traceId,
    required DateTime startTimestamp,
    required DateTime endTimestamp,
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
        startTimestamp: startTimestamp);
    await span.finish(endTimestamp: endTimestamp);
    return span;
  }
}

extension _StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

class AppStartSpanDescriptions {
  static const String pluginRegistration = 'App start to plugin registration';
  static const String mainIsolateSetup = 'Main isolate setup';
  static const String firstFrameRender = 'First frame render';
  // TODO: Add iOS and Android specific descriptions when implementing native spans
}
