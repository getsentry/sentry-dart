import '../../../sentry.dart';
import '../../utils/internal_logger.dart';

class InstrumentationSpanFactorySetupIntegration
    extends Integration<SentryOptions> {
  static const integrationName = 'InstrumentationSpanFactorySetup';

  @override
  void call(Hub hub, SentryOptions options) {
    if (options.traceLifecycle == SentryTraceLifecycle.static) {
      options.spanFactory = LegacyInstrumentationSpanFactory();
    } else {
      options.spanFactory = StreamingInstrumentationSpanFactory(hub);
    }

    options.sdk.addIntegration(integrationName);
    internalLogger
        .debug('$integrationName: Span factory configured successfully');
  }
}
