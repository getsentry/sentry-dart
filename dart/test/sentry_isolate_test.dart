@TestOn('vm')

import 'dart:isolate';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_isolate.dart';
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
