import 'dart:async';

import 'package:sentry/sentry.dart';

import '../../sentry_flutter.dart';
import '../integrations/integrations.dart';
import '../native/sentry_native.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
class NativeAppStartEventProcessor implements EventProcessor {
  final SentryNative _native;

  NativeAppStartEventProcessor(this._native);

  @override
  Future<SentryEvent?> apply(SentryEvent event, {Hint? hint}) async {
    if (_native.didAddAppStartMeasurement || event is! SentryTransaction) {
      return event;
    }

    final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();
    final measurement = appStartInfo?.toMeasurement();

    if (measurement != null) {
      event.measurements[measurement.name] = measurement;
      _native.didAddAppStartMeasurement = true;
    }

    final op = 'app.start.${appStartInfo?.type.name}';

    print('NativeAppStartEventProcessor.apply: ${event.tracer}');

    final tracer = event.tracer;

    // final spanParent = SentrySpan(
    //     tracer,
    //     SentrySpanContext(
    //       operation: op,
    //       description: 'Cold start',
    //       parentSpanId: tracer.context.spanId,
    //       traceId: tracer.context.traceId,
    //     ),
    //     Sentry.currentHub,
    //     startTimestamp: appStartInfo?.start);
    //
    // final span = SentrySpan(
    //     tracer,
    //     SentrySpanContext(
    //       operation: op,
    //       description: 'Engine init',
    //       parentSpanId: spanParent.context.spanId,
    //       traceId: tracer.context.traceId,
    //     ),
    //     Sentry.currentHub,
    //     startTimestamp: appStartInfo?.start);
    // await span.finish(endTimestamp: appStartInfo?.engineEnd);
    //
    // final span2 = SentrySpan(
    //     tracer,
    //     SentrySpanContext(
    //       operation: op,
    //       description: 'Dart loading',
    //       parentSpanId: spanParent.context.spanId,
    //       traceId: tracer.context.traceId,
    //     ),
    //     Sentry.currentHub,
    //     startTimestamp: appStartInfo?.engineEnd);
    // await span2.finish(endTimestamp: SentryFlutter.dartLoadingEnd);
    //
    // final span3 = SentrySpan(
    //     tracer,
    //     SentrySpanContext(
    //       operation: op,
    //       description: 'First frame loading',
    //       parentSpanId: spanParent.context.spanId,
    //       traceId: tracer.context.traceId,
    //     ),
    //     Sentry.currentHub,
    //     startTimestamp: SentryFlutter.dartLoadingEnd);
    // await span3.finish(endTimestamp: appStartInfo?.end);
    //
    // await spanParent.finish(endTimestamp: appStartInfo?.end);
    //
    // tracer.children.add(spanParent);
    // tracer.children.add(span);
    // tracer.children.add(span2);
    // tracer.children.add(span3);

    return event;
  }
}
