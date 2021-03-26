import 'package:sentry/src/transport/rate_limit.dart';
import 'package:sentry/src/transport/rate_limit_category.dart';
import 'package:test/test.dart';

void main() {
  group('parseRateLimitHeader', () {
    test('single rate limit with single category', () {
      final sut = RateLimit.parseRateLimitHeader('50:transaction');

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].durationInMillis, 50);
    });

    test('single rate limit with multiple categories', () {
      final sut = RateLimit.parseRateLimitHeader('50:transaction;session');

      expect(sut.length, 2);

      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].durationInMillis, 50);

      expect(sut[1].category, RateLimitCategory.session);
      expect(sut[1].durationInMillis, 50);
    });

    test('don`t apply rate limit for unknown categories ', () {
      final sut = RateLimit.parseRateLimitHeader('50:somethingunknown');

      expect(sut.length, 0);
    });

    test('apply all if there are no categories', () {
      final sut = RateLimit.parseRateLimitHeader('50');

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.all);
      expect(sut[0].durationInMillis, 50);
    });

    test('multiple rate limits', () {
      final sut = RateLimit.parseRateLimitHeader('50:transaction, 70:session');

      expect(sut.length, 2);

      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].durationInMillis, 50);

      expect(sut[1].category, RateLimitCategory.session);
      expect(sut[1].durationInMillis, 70);
    });

    test('ignore case', () {
      final sut = RateLimit.parseRateLimitHeader('50:TRANSACTION');

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].durationInMillis, 50);
    });
  });
}
