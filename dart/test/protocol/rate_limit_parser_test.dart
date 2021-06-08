import 'package:sentry/src/transport/rate_limit_parser.dart';
import 'package:sentry/src/transport/rate_limit_category.dart';
import 'package:test/test.dart';

void main() {
  group('parseRateLimitHeader', () {
    test('single rate limit with single category', () {
      final sut = RateLimitParser('50:transaction').parseRateLimitHeader();

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].duration.inMilliseconds, 50000);
    });

    test('single rate limit with multiple categories', () {
      final sut =
          RateLimitParser('50:transaction;session').parseRateLimitHeader();

      expect(sut.length, 2);
      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].duration.inMilliseconds, 50000);
      expect(sut[1].category, RateLimitCategory.session);
      expect(sut[1].duration.inMilliseconds, 50000);
    });

    test('don`t apply rate limit for unknown categories ', () {
      final sut = RateLimitParser('50:somethingunknown').parseRateLimitHeader();

      expect(sut.length, 0);
    });

    test('apply all if there are no categories', () {
      final sut = RateLimitParser('50::key').parseRateLimitHeader();

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.all);
      expect(sut[0].duration.inMilliseconds, 50000);
    });

    test('multiple rate limits', () {
      final sut =
          RateLimitParser('50:transaction, 70:session').parseRateLimitHeader();

      expect(sut.length, 2);
      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].duration.inMilliseconds, 50000);
      expect(sut[1].category, RateLimitCategory.session);
      expect(sut[1].duration.inMilliseconds, 70000);
    });

    test('multiple rate limits with same category', () {
      final sut = RateLimitParser('50:transaction, 70:transaction')
          .parseRateLimitHeader();

      expect(sut.length, 2);
      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].duration.inMilliseconds, 50000);
      expect(sut[1].category, RateLimitCategory.transaction);
      expect(sut[1].duration.inMilliseconds, 70000);
    });

    test('ignore case', () {
      final sut = RateLimitParser('50:TRANSACTION').parseRateLimitHeader();

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].duration.inMilliseconds, 50000);
    });

    test('un-parseable returns default duration', () {
      final sut = RateLimitParser('foobar:transaction').parseRateLimitHeader();

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.transaction);
      expect(sut[0].duration.inMilliseconds,
          RateLimitParser.httpRetryAfterDefaultDelay.inMilliseconds);
    });
  });

  group('parseRetryAfterHeader', () {
    test('null returns default category all with default duration', () {
      final sut = RateLimitParser(null).parseRetryAfterHeader();

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.all);
      expect(sut[0].duration.inMilliseconds,
          RateLimitParser.httpRetryAfterDefaultDelay.inMilliseconds);
    });

    test('parseable returns default category with duration in millis', () {
      final sut = RateLimitParser('8').parseRetryAfterHeader();

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.all);
      expect(sut[0].duration.inMilliseconds, 8000);
    });

    test('un-parseable returns default category with default duration', () {
      final sut = RateLimitParser('foobar').parseRetryAfterHeader();

      expect(sut.length, 1);
      expect(sut[0].category, RateLimitCategory.all);
      expect(sut[0].duration.inMilliseconds,
          RateLimitParser.httpRetryAfterDefaultDelay.inMilliseconds);
    });
  });
}
