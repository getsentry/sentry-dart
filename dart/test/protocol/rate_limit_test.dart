import 'package:sentry/src/transport/rate_limit.dart';
import 'package:sentry/src/transport/rate_limit_category.dart';
import 'package:test/test.dart';

void main() {
  group('parseRateLimitHeader', () {
    test('single rate limit with single category', () {
      final sut = RateLimit.parseRateLimitHeader('50:transaction');

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].durationInMillis, 50000);
    });

    test('single rate limit with multiple categories', () {
      final sut = RateLimit.parseRateLimitHeader('50:transaction;session');

      expect(sut.length, 2);

      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].durationInMillis, 50000);

      expect(sut[1].category, RateLimitCategory.session);
      expect(sut[1].durationInMillis, 50000);
    });

    test('don`t apply rate limit for unknown categories ', () {
      final sut = RateLimit.parseRateLimitHeader('50:somethingunknown');

      expect(sut.length, 0);
    });

    test('apply all if there are no categories', () {
      final sut = RateLimit.parseRateLimitHeader('50');

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.all);
      expect(sut[0].durationInMillis, 50000);
    });

    test('multiple rate limits', () {
      final sut = RateLimit.parseRateLimitHeader('50:transaction, 70:session');

      expect(sut.length, 2);

      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].durationInMillis, 50000);

      expect(sut[1].category, RateLimitCategory.session);
      expect(sut[1].durationInMillis, 70000);
    });

    test('ignore case', () {
      final sut = RateLimit.parseRateLimitHeader('50:TRANSACTION');

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].durationInMillis, 50000);
    });

    test('un-parseable returns default duration', () {
      final sut = RateLimit.parseRateLimitHeader('foobar:transaction');

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].durationInMillis, RateLimit.HTTP_RETRY_AFTER_DEFAULT_DELAY_MILLIS);
    });
  });

  group('parseRetryAfterHeader', () {
    test('null returns default category all with default duration', () {
      final sut = RateLimit.parseRetryAfterHeader(null);

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.all);
      expect(sut[0].durationInMillis, RateLimit.HTTP_RETRY_AFTER_DEFAULT_DELAY_MILLIS);
    });

    test('parseable returns default category with duration in millis', () {
      final sut = RateLimit.parseRetryAfterHeader('8');

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.all);
      expect(sut[0].durationInMillis, 8000);
    });

    test('un-parseable returns default category with default duration', () {
      final sut = RateLimit.parseRetryAfterHeader('foobar');

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.all);
      expect(sut[0].durationInMillis, RateLimit.HTTP_RETRY_AFTER_DEFAULT_DELAY_MILLIS);
    });
  });
}
