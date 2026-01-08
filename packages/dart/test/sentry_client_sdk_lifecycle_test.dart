import 'package:sentry/sentry.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks/mock_client_report_recorder.dart';
import 'mocks/mock_telemetry_processor.dart';
import 'mocks/mock_transport.dart';
import 'sentry_client_test.dart';
import 'test_utils.dart';
import 'utils/url_details_test.dart';

void main() {
  group('SDK lifecycle callbacks', () {
    late Fixture fixture;

    setUp(() => fixture = Fixture());

    group('Logs', () {
      SentryLog givenLog() {
        return SentryLog(
          timestamp: DateTime.now(),
          traceId: SentryId.newId(),
          level: SentryLogLevel.info,
          body: 'test',
          attributes: {
            'attribute': SentryAttribute.string('value'),
          },
        );
      }

      test('captureLog triggers OnBeforeCaptureLog', () async {
        fixture.options.enableLogs = true;
        fixture.options.environment = 'test-environment';
        fixture.options.release = 'test-release';

        final log = givenLog();

        final scope = Scope(fixture.options);
        final span = MockSpan();
        scope.span = span;

        final client = fixture.getSut();
        final mockProcessor = MockTelemetryProcessor();
        fixture.options.telemetryProcessor = mockProcessor;

        fixture.options.lifecycleRegistry
            .registerCallback<OnBeforeCaptureLog>((event) {
          event.log.attributes['test'] = SentryAttribute.string('test-value');
        });

        await client.captureLog(log, scope: scope);

        expect(mockProcessor.addedLogs.length, 1);
        final capturedLog = mockProcessor.addedLogs.first;

        expect(capturedLog.attributes['test']?.value, "test-value");
        expect(capturedLog.attributes['test']?.type, 'string');
      });
    });

    group('SentryEvent', () {
      test('captureEvent triggers OnBeforeSendEvent', () async {
        fixture.options.enableLogs = true;
        fixture.options.environment = 'test-environment';
        fixture.options.release = 'test-release';

        final event = SentryEvent();

        final scope = Scope(fixture.options);
        final span = MockSpan();
        scope.span = span;

        final client = fixture.getSut();
        final mockProcessor = MockTelemetryProcessor();
        fixture.options.telemetryProcessor = mockProcessor;

        fixture.options.lifecycleRegistry
            .registerCallback<OnBeforeSendEvent>((event) {
          event.event.release = '999';
        });

        await client.captureEvent(event, scope: scope);

        final capturedEnvelope = (fixture.transport).envelopes.first;
        final capturedEvent = await eventFromEnvelope(capturedEnvelope);

        expect(capturedEvent.release, '999');
      });
    });
  });
}

class Fixture {
  final recorder = MockClientReportRecorder();
  final transport = MockTransport();

  final options = defaultTestOptions()
    ..platform = MockPlatform.iOS()
    ..groupExceptions = true;

  late SentryTransactionContext _context;
  late SentryTracer tracer;

  SentryLevel? loggedLevel;
  Object? loggedException;

  SentryClient getSut({
    bool sendDefaultPii = false,
    bool attachStacktrace = true,
    bool attachThreads = false,
    double? sampleRate,
    BeforeSendCallback? beforeSend,
    BeforeSendTransactionCallback? beforeSendTransaction,
    BeforeSendCallback? beforeSendFeedback,
    EventProcessor? eventProcessor,
    bool provideMockRecorder = true,
    bool debug = false,
    Transport? transport,
  }) {
    options.tracesSampleRate = 1.0;
    options.sendDefaultPii = sendDefaultPii;
    options.attachStacktrace = attachStacktrace;
    options.attachThreads = attachThreads;
    options.sampleRate = sampleRate;
    options.beforeSend = beforeSend;
    options.beforeSendTransaction = beforeSendTransaction;
    options.beforeSendFeedback = beforeSendFeedback;
    options.debug = debug;
    options.log = mockLogger;

    if (eventProcessor != null) {
      options.addEventProcessor(eventProcessor);
    }

    // Internally also creates a SentryClient instance
    final hub = Hub(options);
    _context = SentryTransactionContext(
      'name',
      'op',
    );
    tracer = SentryTracer(_context, hub);

    // Reset transport
    options.transport = transport ?? this.transport;

    // Again create SentryClient instance
    final client = SentryClient(options);

    if (provideMockRecorder) {
      options.recorder = recorder;
    }
    return client;
  }

  Future<SentryEvent?> droppingBeforeSend(SentryEvent event, Hint hint) async {
    return null;
  }

  SentryTransaction fakeTransaction() {
    return SentryTransaction(
      tracer,
      sdk: SdkVersion(name: 'sdk1', version: '1.0.0'),
      breadcrumbs: [],
    );
  }

  SentryEvent fakeFeedbackEvent() {
    return SentryEvent(
      type: 'feedback',
      contexts: Contexts(feedback: fakeFeedback()),
      level: SentryLevel.info,
    );
  }

  SentryFeedback fakeFeedback() {
    return SentryFeedback(
      message: 'fixture-message',
      contactEmail: 'fixture-contactEmail',
      name: 'fixture-name',
      replayId: 'fixture-replayId',
      url: "https://fixture-url.com",
      associatedEventId: SentryId.fromId('1d49af08b6e2c437f9052b1ecfd83dca'),
    );
  }

  void mockLogger(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    loggedLevel = level;
    loggedException = exception;
  }
}
