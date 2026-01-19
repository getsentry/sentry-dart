import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/metric/metric.dart';
import 'package:sentry/src/telemetry/metric/metric_capture_pipeline.dart';
import 'package:test/test.dart';

import '../../mocks/mock_telemetry_processor.dart';
import '../../test_utils.dart';

void main() {
  group('$MetricCapturePipeline', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('when capturing a metric', () {
      test('forwards to telemetry processor', () async {
        final metric = fixture.createMetric();

        await fixture.pipeline.captureMetric(metric, scope: fixture.scope);

        expect(fixture.processor.addedMetrics.length, 1);
        expect(fixture.processor.addedMetrics.first, same(metric));
      });

      test('adds default attributes', () async {
        await fixture.scope.setUser(SentryUser(id: 'user-id'));
        fixture.scope.setAttributes({
          'scope-key': SentryAttribute.string('scope-value'),
        });

        final metric = fixture.createMetric()
          ..attributes['custom'] = SentryAttribute.string('metric-value');

        await fixture.pipeline.captureMetric(metric, scope: fixture.scope);

        final attributes = metric.attributes;
        expect(attributes['scope-key']?.value, 'scope-value');
        expect(attributes['custom']?.value, 'metric-value');
        expect(attributes[SemanticAttributesConstants.sentryEnvironment]?.value,
            'test-env');
        expect(attributes[SemanticAttributesConstants.sentryRelease]?.value,
            'test-release');
        expect(attributes[SemanticAttributesConstants.sentrySdkName]?.value,
            fixture.options.sdk.name);
        expect(attributes[SemanticAttributesConstants.sentrySdkVersion]?.value,
            fixture.options.sdk.version);
        expect(
            attributes[SemanticAttributesConstants.userId]?.value, 'user-id');
      });

      test('prefers scope attributes over defaults', () async {
        fixture.scope.setAttributes({
          SemanticAttributesConstants.sentryEnvironment:
              SentryAttribute.string('scope-env'),
        });

        final metric = fixture.createMetric();

        await fixture.pipeline.captureMetric(metric, scope: fixture.scope);

        final attributes = metric.attributes;
        expect(attributes[SemanticAttributesConstants.sentryEnvironment]?.value,
            'scope-env');
        expect(attributes[SemanticAttributesConstants.sentryRelease]?.value,
            'test-release');
      });

      test(
          'dispatches OnProcessMetric after scope merge but before beforeSendMetric',
          () async {
        final operations = <String>[];
        bool hasScopeAttrInCallback = false;

        fixture.scope.setAttributes({
          'scope-attr': SentryAttribute.string('scope-value'),
        });

        fixture.options.lifecycleRegistry
            .registerCallback<OnProcessMetric>((event) {
          operations.add('onProcessMetric');
          hasScopeAttrInCallback =
              event.metric.attributes.containsKey('scope-attr');
        });

        fixture.options.beforeSendMetric = (metric) {
          operations.add('beforeSendMetric');
          return metric;
        };

        final metric = fixture.createMetric();

        await fixture.pipeline.captureMetric(metric, scope: fixture.scope);

        expect(operations, ['onProcessMetric', 'beforeSendMetric']);
        expect(hasScopeAttrInCallback, isTrue);
      });

      test('keeps attributes added by lifecycle callbacks', () async {
        fixture.options.lifecycleRegistry
            .registerCallback<OnProcessMetric>((event) {
          event.metric.attributes['callback-key'] =
              SentryAttribute.string('callback-value');
          event.metric
                  .attributes[SemanticAttributesConstants.sentryEnvironment] =
              SentryAttribute.string('callback-env');
        });

        final metric = fixture.createMetric();

        await fixture.pipeline.captureMetric(metric, scope: fixture.scope);

        final attributes = metric.attributes;
        expect(attributes['callback-key']?.value, 'callback-value');
        expect(attributes[SemanticAttributesConstants.sentryEnvironment]?.value,
            'callback-env');
      });

      test('does not add user attributes when sendDefaultPii is false',
          () async {
        fixture.options.sendDefaultPii = false;
        await fixture.scope.setUser(SentryUser(id: 'user-id'));

        final metric = fixture.createMetric();

        await fixture.pipeline.captureMetric(metric, scope: fixture.scope);

        expect(
          metric.attributes.containsKey(SemanticAttributesConstants.userId),
          isFalse,
        );
      });
    });

    group('when metrics are disabled', () {
      test('does not add metrics to processor', () async {
        fixture.options.enableMetrics = false;

        final metric = fixture.createMetric();

        await fixture.pipeline.captureMetric(metric, scope: fixture.scope);

        expect(fixture.processor.addedMetrics, isEmpty);
      });
    });

    group('when beforeSendMetric is configured', () {
      test('returning null drops the metric', () async {
        fixture.options.beforeSendMetric = (_) => null;

        final metric = fixture.createMetric();

        await fixture.pipeline.captureMetric(metric, scope: fixture.scope);

        expect(fixture.processor.addedMetrics, isEmpty);
      });

      test('can mutate the metric', () async {
        fixture.options.beforeSendMetric = (metric) {
          metric.name = 'modified-name';
          metric.attributes['added-key'] = SentryAttribute.string('added');
          return metric;
        };

        final metric = fixture.createMetric(name: 'original-name');

        await fixture.pipeline.captureMetric(metric, scope: fixture.scope);

        expect(fixture.processor.addedMetrics.length, 1);
        final captured = fixture.processor.addedMetrics.first;
        expect(captured.name, 'modified-name');
        expect(captured.attributes['added-key']?.value, 'added');
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions()
    ..environment = 'test-env'
    ..release = 'test-release'
    ..sendDefaultPii = true
    ..enableMetrics = true;

  final processor = MockTelemetryProcessor();

  late final Scope scope;
  late final MetricCapturePipeline pipeline;

  Fixture() {
    options.telemetryProcessor = processor;
    scope = Scope(options);
    pipeline = MetricCapturePipeline(options);
  }

  SentryMetric createMetric({String name = 'test-metric'}) {
    return SentryCounterMetric(
      timestamp: DateTime.now().toUtc(),
      name: name,
      value: 1,
      traceId: SentryId.newId(),
    );
  }
}
