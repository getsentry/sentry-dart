@TestOn('vm')

import 'dart:isolate';

import 'package:sentry/src/hub.dart';
import 'package:sentry/src/protocol/span_status.dart';
import 'package:sentry/src/sentry_isolate_extension.dart';
import 'package:sentry/src/sentry_options.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_hub.dart';
import 'mocks/mock_sentry_client.dart';

void main() {
  group("SentryIsolate", () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    // increase coverage of handleIsolateError

    test('add error listener', () async {
      final throwingClosure = (String message) async {
        throw StateError(message);
      };

      final isolate =
          await Isolate.spawn(throwingClosure, "message", paused: true);
      isolate.addSentryErrorListener(hub: fixture.hub);
      isolate.resume(isolate.pauseCapability!);

      await Future.delayed(Duration(milliseconds: 10));

      expect(fixture.hub.captureEventCalls.first, isNotNull);
    });

    test('remove error listener', () async {
      final throwingClosure = (String message) async {
        throw StateError(message);
      };

      final isolate =
          await Isolate.spawn(throwingClosure, "message", paused: true);
      final port = isolate.addSentryErrorListener(hub: fixture.hub);
      isolate.removeSentryErrorListenerAndClosePort(port);
      isolate.resume(isolate.pauseCapability!);

      await Future.delayed(Duration(milliseconds: 10));

      expect(fixture.hub.captureEventCalls.isEmpty, true);
    });

    test('marks transaction as internal error if no status', () async {
      final exception = StateError('error');
      final stackTrace = StackTrace.current.toString();

      final hub = Hub(fixture.options);
      final client = MockSentryClient();
      hub.bindClient(client);

      final sut = fixture.getSut();

      hub.startTransaction('name', 'operation', bindToScope: true);

      await sut.handleIsolateError(
          hub, fixture.options, [exception.toString(), stackTrace]);

      final span = hub.getSpan();

      expect(span?.status, const SpanStatus.internalError());

      await span?.finish();
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions(dsn: fakeDsn)..tracesSampleRate = 1.0;

  Isolate getSut() {
    return Isolate.current;
  }
}
