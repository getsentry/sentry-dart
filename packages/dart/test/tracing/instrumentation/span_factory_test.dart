// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:sentry/sentry.dart';
import 'package:sentry/src/tracing/instrumentation/span_factory_integration.dart';
import 'package:test/test.dart';

import '../../mocks/mock_transport.dart';
import '../../test_utils.dart';

void main() {
  test('streaming factory provides known attributes on span start', () async {
    final options = defaultTestOptions()
      ..tracesSampleRate = 1.0
      ..traceLifecycle = SentryTraceLifecycle.stream;
    final hub = Hub(options);
    options.addIntegration(InstrumentationSpanFactorySetupIntegration());
    options.integrations.last.call(hub, options);

    Map<String, SentryAttribute>? startAttributes;
    options.lifecycleRegistry.registerCallback<OnSpanStartV2>((event) {
      if (event.span.name == 'child') {
        startAttributes = event.span.attributes;
      }
    });

    await hub.startSpan(
      'parent',
      (_) async {
        final parent = options.spanFactory.getSpan(hub)!;
        final child = options.spanFactory.createSpan(
          parentSpan: parent,
          operation: 'test.operation',
          description: 'child',
          origin: 'auto.test',
          data: const {
            'string': 'value',
            'integer': 42,
            'double': 1.5,
            'boolean': true,
          },
          isSynchronous: true,
        );
        await child?.finish();
      },
      parentSpan: null,
    );

    expect(
      startAttributes?[SemanticAttributesConstants.sentryOp]?.value,
      equals('test.operation'),
    );
    expect(
      startAttributes?[SemanticAttributesConstants.sentryOrigin]?.value,
      equals('auto.test'),
    );
    expect(startAttributes?['string']?.value, equals('value'));
    expect(startAttributes?['integer']?.value, equals(42));
    expect(startAttributes?['double']?.value, equals(1.5));
    expect(startAttributes?['boolean']?.value, isTrue);
    expect(startAttributes?['sync']?.value, isTrue);

    await hub.close();
  });

  test('legacy factory applies data and the synchronous marker', () async {
    final options = defaultTestOptions()
      ..tracesSampleRate = 1.0
      ..transport = MockTransport();
    final hub = Hub(options);
    final parent = hub.startTransaction('parent', 'parent');
    final factory = LegacyInstrumentationSpanFactory();

    final child = factory.createSpan(
      parentSpan: LegacyInstrumentationSpan(parent),
      operation: 'test.operation',
      description: 'child',
      origin: 'auto.test',
      data: const {'known': 'value'},
      isSynchronous: true,
    ) as LegacyInstrumentationSpan;
    final span = child.spanReference as SentrySpan;

    expect(span.origin, equals('auto.test'));
    expect(span.data['known'], equals('value'));
    expect(span.data['sync'], isTrue);

    await child.finish();
    await parent.finish();
    await hub.close();
  });
}
