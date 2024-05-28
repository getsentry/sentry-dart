@TestOn('vm')
library dart_test;

import 'dart:isolate';

import 'package:sentry/src/sentry_isolate_extension.dart';
import 'package:sentry/src/sentry_options.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_hub.dart';

void main() {
  group("SentryIsolate", () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

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
      isolate.removeSentryErrorListener(port);
      isolate.resume(isolate.pauseCapability!);

      await Future.delayed(Duration(milliseconds: 10));

      expect(fixture.hub.captureEventCalls.isEmpty, true);
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
