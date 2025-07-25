// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/generic_app_start_integration.dart';
// Internal import is fine in tests.
import 'package:sentry/src/transport/noop_transport.dart';
import 'package:sentry/src/sentry_tracer.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group('GenericAppStartIntegration (real impl)', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('when tracing is enabled', () {
      setUp(() {
        fixture.options.tracesSampleRate = 1.0;
      });

      test('adds sdk integration', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.options.sdk.integrations, contains('GenericAppStart'));
      });

      test('sets transaction ID on timeToDisplayTracker', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.options.timeToDisplayTracker.transactionId, isNotNull);
      });

      test('adds post frame callback', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.fakeFrameHandler.postFrameCallback, isNotNull);
      });

      test(
          'creates transaction with correct context when frame callback executes',
          () async {
        final sut = fixture.getSut();
        fixture.fakeFrameHandler.postFrameCallbackDelay = Duration.zero;

        sut.call(fixture.hub, fixture.options);

        await Future<void>.delayed(Duration(milliseconds: 10));

        final tracer = fixture.hub.scope.span as SentryTracer?;
        expect(tracer, isNotNull);
        expect(tracer!.name, 'root /');
        expect(tracer.context.operation, SentrySpanOperations.uiLoad);
        expect(tracer.origin, SentryTraceOrigins.autoUiTimeToDisplay);
      });

      test('tracks time to display when frame callback executes', () async {
        final sut = fixture.getSut();
        fixture.fakeFrameHandler.postFrameCallbackDelay = Duration.zero;

        sut.call(fixture.hub, fixture.options);

        await Future<void>.delayed(Duration(milliseconds: 100));

        final tracer = fixture.hub.scope.span as SentryTracer?;
        final hasTtidSpan = tracer!.children.any((span) =>
            span.context.operation ==
            SentrySpanOperations.uiTimeToInitialDisplay);
        expect(hasTtidSpan, isTrue);
      });

      test('finishes transaction when frame callback executes', () async {
        final sut = fixture.getSut();
        fixture.fakeFrameHandler.postFrameCallbackDelay = Duration.zero;

        sut.call(fixture.hub, fixture.options);

        // Wait longer than autoFinishAfter (3s) + delay to ensure finish.
        await Future<void>.delayed(Duration(seconds: 4));

        final envelopes = fixture.fakeTransport.envelopes;
        expect(envelopes.length, 1);
        final capturedTransaction =
            await _transactionFromEnvelope(envelopes.first);
        final spans = capturedTransaction['spans'] as List;
        final span = spans.first as Map<dynamic, dynamic>;
        expect(span['op'], SentrySpanOperations.uiTimeToInitialDisplay);
        expect(span['description'], 'root / initial display');
        expect(capturedTransaction['contexts']['trace']['op'],
            SentrySpanOperations.uiLoad);
        expect(capturedTransaction['contexts']['trace']['origin'],
            SentryTraceOrigins.autoUiTimeToDisplay);
      });

      test('uses correct start timestamp from clock', () async {
        final fixedTime = DateTime(2023, 1, 1, 12, 0, 0).toUtc();
        fixture.options.clock = () => fixedTime;
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        await Future<void>.delayed(Duration(milliseconds: 100));

        final tracer = fixture.hub.scope.span as SentryTracer?;
        expect(tracer, isNotNull);
        expect(tracer!.startTimestamp, fixedTime);
      });

      test('uses clock for end timestamp in frame callback', () async {
        var callCount = 0;
        final startTime = DateTime(2023, 1, 1, 12, 0, 0).toUtc();
        final endTime = DateTime(2023, 1, 1, 12, 0, 1).toUtc();
        fixture.options.clock = () {
          callCount++;
          return callCount == 1 ? startTime : endTime;
        };

        final sut = fixture.getSut();
        fixture.fakeFrameHandler.postFrameCallbackDelay = Duration.zero;

        sut.call(fixture.hub, fixture.options);

        // Wait longer than autoFinishAfter (3s) + delay to ensure finish.
        await Future<void>.delayed(Duration(seconds: 4));

        final envelopes = fixture.fakeTransport.envelopes;
        expect(envelopes.length, 1);
        final capturedTransaction =
            await _transactionFromEnvelope(envelopes.first);
        final spans = capturedTransaction['spans'] as List;
        final span = spans.first as Map<dynamic, dynamic>;
        expect(span['op'], SentrySpanOperations.uiTimeToInitialDisplay);
        expect(span['description'], 'root / initial display');

        // Compare TTID span times
        final ttidStartTimestamp =
            DateTime.parse(span['start_timestamp'].toString());
        final ttidEndTimestamp = DateTime.parse(span['timestamp'].toString());
        expect(ttidStartTimestamp, startTime);
        expect(ttidEndTimestamp, endTime);

        // Compare transaction times
        final transactionStartTimestamp =
            DateTime.parse(capturedTransaction['start_timestamp'].toString());
        final transactionEndTimestamp =
            DateTime.parse(capturedTransaction['timestamp'].toString());
        expect(transactionStartTimestamp, startTime);
        expect(transactionEndTimestamp, endTime);
      });

      test('maintains transaction ID consistency between setup and tracking',
          () async {
        final sut = fixture.getSut();
        fixture.fakeFrameHandler.postFrameCallbackDelay = Duration.zero;

        sut.call(fixture.hub, fixture.options);

        final transactionIdAfterSetup =
            fixture.options.timeToDisplayTracker.transactionId;
        expect(transactionIdAfterSetup, isNotNull);

        await Future<void>.delayed(Duration(milliseconds: 10));

        final tracer = fixture.hub.scope.span as SentryTracer?;
        expect(tracer, isNotNull);
        expect(tracer!.context.spanId, transactionIdAfterSetup);
      });
    });

    group('when tracing is disabled', () {
      setUp(() {
        fixture.options.tracesSampleRate = null;
      });

      test('does not add sdk integration', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.options.sdk.integrations, isEmpty);
      });

      test('does not set transaction ID on timeToDisplayTracker', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.options.timeToDisplayTracker.transactionId, isNull);
      });

      test('does not add post frame callback', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.fakeFrameHandler.postFrameCallback, isNull);
      });

      test('does not create any transactions', () {
        final sut = fixture.getSut();

        sut.call(fixture.hub, fixture.options);

        expect(fixture.hub.scope.span, isNull);
      });
    });

    group('integration constants', () {
      test('has correct integration name', () {
        expect(GenericAppStartIntegration.integrationName, 'GenericAppStart');
      });
    });
  });
}

class Fixture {
  Fixture() {
    options = defaultTestOptions();
    options.transport = fakeTransport;
    hub = Hub(options);
  }

  final fakeTransport = _FakeTransport();
  late final SentryFlutterOptions options;
  late final Hub hub;
  final fakeFrameHandler = FakeFrameCallbackHandler();

  GenericAppStartIntegration getSut() {
    return GenericAppStartIntegration(fakeFrameHandler);
  }
}

class _FakeTransport implements Transport {
  final envelopes = <SentryEnvelope>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) {
    envelopes.add(envelope);
    return Future.value(SentryId.empty());
  }
}

Future<Map<String, dynamic>> _transactionFromEnvelope(
    SentryEnvelope envelope) async {
  final data = await envelope.items.first.dataFactory();
  final utf8Data = utf8.decode(data);
  final envelopeItemJson = jsonDecode(utf8Data);
  return envelopeItemJson as Map<String, dynamic>;
}
