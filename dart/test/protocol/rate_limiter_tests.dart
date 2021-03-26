import 'package:sentry/src/transport/rate_limiter.dart';
import 'package:test/test.dart';

void main() {
  var fixture = Fixture();

  setUp(() {
    fixture = Fixture();
  });

  group('RateLimiter Tests', () {
    test('uses X-Sentry-Rate-Limit and allows sending if time has passed', () {
      //TODO(denis): Implement test
    });

    test('parse X-Sentry-Rate-Limit and set its values and retry after should be true', () {
      //TODO(denis): Implement test
    });

    test('parse X-Sentry-Rate-Limit and set its values and retry after should be false', () {
      //TODO(denis): Implement test
    });

    test('When X-Sentry-Rate-Limit categories are empty, applies to all the categories', () {
      //TODO(denis): Implement test
    });

    test('When all categories is set but expired, applies only for specific category', () {
      //TODO(denis): Implement test
    });

    test('When category has shorter rate limiting, do not apply new timestamp', () {
      //TODO(denis): Implement test
    });

    test('When category has longer rate limiting, apply new timestamp', () {
      //TODO(denis): Implement test
    });

    test('When both retry headers are not present, default delay is set', () {
      //TODO(denis): Implement test
    });
  });
}

class Fixture {
  final sut = RateLimiter();
}
