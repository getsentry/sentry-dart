@TestOn('vm')
library dart_test;

import 'package:http/io_client.dart' show IOClient;
import 'package:sentry/sentry.dart';
import 'package:sentry/src/transport/http_transport.dart';
import 'package:sentry/src/transport/rate_limiter.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('proxy', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('options.httpProxy should set client to IoClient', () async {
      fixture.options.httpProxy = "PROXY xxxx:xxxx";
      fixture.getSut();

      expect(fixture.options.httpClient is IOClient, true);
    });
  });
}

class Fixture {
  final options = SentryOptions(dsn: fakeDsn);

  HttpTransport getSut() {
    final rateLimiter = RateLimiter(options);
    return HttpTransport(options, rateLimiter);
  }
}
