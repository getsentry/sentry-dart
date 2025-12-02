import 'package:sentry/sentry.dart';
import 'package:sentry/src/protocol/noop_span.dart';
import 'package:sentry/src/protocol/simple_span.dart';
import 'package:test/test.dart';

import 'mocks/mock_client_report_recorder.dart';
import 'mocks/mock_sentry_client.dart';
import 'test_utils.dart';

void main() {
  group('Hub', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('startSpan', () {
      group('span creation', () {
        test('returns SimpleSpan when tracing is enabled', () {
          final hub = fixture.getSut();

          final span = hub.startSpan('test-span');

          expect(span, isA<SimpleSpan>());
        });

        test('returns NoOpSpan when tracing is disabled', () {
          final hub = fixture.getSut(tracesSampleRate: null);

          final span = hub.startSpan('test-span');

          expect(span, isA<NoOpSpan>());
        });

        test('returns NoOpSpan when hub is closed', () async {
          final hub = fixture.getSut();
          await hub.close();

          final span = hub.startSpan('test-span');

          expect(span, isA<NoOpSpan>());
        });

        test('sets span name from parameter', () {
          final hub = fixture.getSut();

          final span = hub.startSpan('my-span-name');

          expect(span.name, equals('my-span-name'));
        });

        test('sets attributes on span when provided', () {
          final hub = fixture.getSut();
          final attributes = {
            'attr1': SentryAttribute.string('value1'),
            'attr2': SentryAttribute.int(42),
          };

          final span = hub.startSpan('test-span', attributes: attributes);

          expect(span.attributes, equals(attributes));
        });
      });

      group('active span handling', () {
        test('sets span as active on scope when active is true', () {
          final hub = fixture.getSut();

          final span = hub.startSpan('test-span', active: true);

          expect(hub.scope.getActiveSpan(), equals(span));
        });

        test('does not set span as active on scope when active is false', () {
          final hub = fixture.getSut();

          hub.startSpan('test-span', active: false);

          expect(hub.scope.getActiveSpan(), isNull);
        });
      });

      group('parent span resolution', () {
        test('creates root span when no active span exists', () {
          final hub = fixture.getSut();

          final span = hub.startSpan('test-span');

          expect(span.parentSpan, isNull);
        });

        test('uses active span as parent when parentSpan is not provided', () {
          final hub = fixture.getSut();
          final parentSpan = hub.startSpan('parent-span');

          final childSpan = hub.startSpan('child-span');

          expect(childSpan.parentSpan, equals(parentSpan));
        });

        test('uses explicit parentSpan instead of active span when provided',
            () {
          final hub = fixture.getSut();
          final explicitParent = hub.startSpan('explicit-parent');
          hub.startSpan('other-span'); // Changes active span

          final childSpan = hub.startSpan(
            'child-span',
            parentSpan: explicitParent,
            active: false,
          );

          expect(childSpan.parentSpan, equals(explicitParent));
        });

        test('creates root span when parentSpan is explicitly set to null', () {
          final hub = fixture.getSut();
          hub.startSpan('active-span');

          final rootSpan = hub.startSpan('root-span', parentSpan: null);

          expect(rootSpan.parentSpan, isNull);
        });

        test('should not allow finished span to be use as parent', () {
          // TODO: this test case needs more clarification
        });
      });
    });

    group('captureSpan', () {
      // TODO: add test that it was added to buffer

      test('removes span from active spans on scope', () {
        final hub = fixture.getSut();
        final span = hub.startSpan('test-span');
        expect(hub.scope.activeSpans, contains(span));

        hub.captureSpan(span);

        expect(hub.scope.activeSpans, isNot(contains(span)));
      });

      test('does nothing when hub is closed', () async {
        final hub = fixture.getSut();
        final span = hub.startSpan('test-span');
        await hub.close();

        // Should not throw
        hub.captureSpan(span);
      });
    });
  });
}

class Fixture {
  final client = MockSentryClient();
  final recorder = MockClientReportRecorder();

  final options = defaultTestOptions();

  Hub getSut({
    double? tracesSampleRate = 1.0,
    TracesSamplerCallback? tracesSampler,
    bool debug = false,
  }) {
    options.tracesSampleRate = tracesSampleRate;
    options.tracesSampler = tracesSampler;
    options.debug = debug;

    final hub = Hub(options);

    hub.bindClient(client);
    options.recorder = recorder;

    return hub;
  }
}
