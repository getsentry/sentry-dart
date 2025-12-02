import 'package:sentry/sentry.dart';
import 'package:sentry/src/protocol/noop_span.dart';
import 'package:sentry/src/protocol/simple_span.dart';
import 'package:test/test.dart';

import 'mocks/mock_client_report_recorder.dart';
import 'mocks/mock_sentry_client.dart';
import 'test_utils.dart';

void main() {
  group('Hub startSpan', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('startSpan returns SimpleSpan when tracing is enabled', () {
      final hub = fixture.getSut();

      final span = hub.startSpan('test-span');

      expect(span, isA<SimpleSpan>());
    });

    test('startSpan returns NoOpSpan when tracing is disabled', () {
      final hub = fixture.getSut(tracesSampleRate: null);

      final span = hub.startSpan('test-span');

      expect(span, isA<NoOpSpan>());
    });

    test('startSpan returns NoOpSpan when hub is disabled', () async {
      final hub = fixture.getSut();
      await hub.close();

      final span = hub.startSpan('test-span');

      expect(span, isA<NoOpSpan>());
    });

    test('startSpan sets span name', () {
      final hub = fixture.getSut();

      final span = hub.startSpan('my-span-name');

      expect(span, isA<SimpleSpan>());
      // TODO: verify span name once SimpleSpan implements it
    });

    test('startSpan with active=true sets span as active on scope', () {
      final hub = fixture.getSut();

      final span = hub.startSpan('test-span', active: true);

      expect(hub.scope.getActiveSpan(), equals(span));
    });

    test('startSpan with active=false does not set span as active on scope',
        () {
      final hub = fixture.getSut();

      hub.startSpan('test-span', active: false);

      expect(hub.scope.getActiveSpan(), isNull);
    });

    test('startSpan uses active span as parent when parentSpan is not provided',
        () {
      final hub = fixture.getSut();

      // Start first span which becomes active
      final parentSpan = hub.startSpan('parent-span');
      expect(hub.scope.getActiveSpan(), equals(parentSpan));

      // Start second span - should use active span as parent
      final childSpan = hub.startSpan('child-span');
      expect(childSpan, isA<SimpleSpan>());
      expect(childSpan.parentSpan, equals(parentSpan));
    });

    test('startSpan with explicit parentSpan uses that as parent', () {
      final hub = fixture.getSut();

      final explicitParent = hub.startSpan('explicit-parent');
      // Start another span to change active span
      hub.startSpan('other-span');

      // Start span with explicit parent
      final childSpan = hub.startSpan('child-span',
          parentSpan: explicitParent, active: false);

      expect(childSpan, isA<SimpleSpan>());
      expect(childSpan.parentSpan, equals(explicitParent));
    });

    test('startSpan with parentSpan=null creates root/segment span', () {
      final hub = fixture.getSut();

      // Start active span first
      hub.startSpan('active-span');

      // Start span with null parent - should be root span
      final rootSpan = hub.startSpan('root-span', parentSpan: null);

      expect(rootSpan, isA<SimpleSpan>());
      expect(rootSpan.parentSpan, isNull);
    });

    test('startSpan with attributes sets attributes on span', () {
      final hub = fixture.getSut();
      final attributes = {
        'attr1': SentryAttribute.string('value1'),
        'attr2': SentryAttribute.int(42),
      };

      final span = hub.startSpan('test-span', attributes: attributes);

      expect(span, isA<SimpleSpan>());
      // TODO: verify attributes once SimpleSpan implements it
    });
  });

  group('Hub captureSpan', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('captureSpan removes span from active spans', () {
      final hub = fixture.getSut();

      final span = hub.startSpan('test-span');
      expect(hub.scope.activeSpans, contains(span));

      hub.captureSpan(span);

      expect(hub.scope.activeSpans, isNot(contains(span)));
    });

    test('captureSpan does nothing when hub is disabled', () async {
      final hub = fixture.getSut();
      final span = hub.startSpan('test-span');
      await hub.close();

      // Should not throw
      hub.captureSpan(span);
    });
  });
}

class Fixture {
  final client = MockSentryClient();
  final recorder = MockClientReportRecorder();

  final options = defaultTestOptions();

  SentryLevel? loggedLevel;
  String? loggedMessage;
  Object? loggedException;

  Hub getSut({
    double? tracesSampleRate = 1.0,
    TracesSamplerCallback? tracesSampler,
    bool debug = false,
  }) {
    options.tracesSampleRate = tracesSampleRate;
    options.tracesSampler = tracesSampler;
    options.debug = debug;
    options.log = mockLogger;

    final hub = Hub(options);

    hub.bindClient(client);
    options.recorder = recorder;

    return hub;
  }

  void mockLogger(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    loggedLevel = level;
    loggedMessage = message;
    loggedException = exception;
  }
}
