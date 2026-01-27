import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/span/ignore_span_filter.dart';
import 'package:test/test.dart';

void main() {
  group('$IgnoreSpanFilter', () {
    group('when using name filter', () {
      test('throws ArgumentError when where filter has no name or attributes',
          () {
        expect(
          () => IgnoreSpanFilter.where(),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError when where filter has empty attributes', () {
        expect(
          () => IgnoreSpanFilter.where(attributes: {}),
          throwsArgumentError,
        );
      });
    });
  });

  group('isSpanIgnored', () {
    group('with NameMatcher.contains', () {
      test('matches when span name contains the value', () {
        final result = isSpanIgnored(
          'GET /healthcheck',
          {},
          [IgnoreSpanFilter.name(NameMatcher.contains('health'))],
        );

        expect(result, isTrue);
      });

      test('does not match when span name does not contain the value', () {
        final result = isSpanIgnored(
          'GET /users',
          {},
          [IgnoreSpanFilter.name(NameMatcher.contains('health'))],
        );

        expect(result, isFalse);
      });

      test('is case sensitive', () {
        final result = isSpanIgnored(
          'GET /HEALTHCHECK',
          {},
          [IgnoreSpanFilter.name(NameMatcher.contains('health'))],
        );

        expect(result, isFalse);
      });
    });

    group('with NameMatcher.regexp', () {
      test('matches when span name matches regex', () {
        final result = isSpanIgnored(
          'GET /api/123',
          {},
          [IgnoreSpanFilter.name(NameMatcher.regexp(RegExp(r'^GET /api/\d+$')))],
        );

        expect(result, isTrue);
      });

      test('does not match when span name does not match regex', () {
        final result = isSpanIgnored(
          'POST /api/123',
          {},
          [IgnoreSpanFilter.name(NameMatcher.regexp(RegExp(r'^GET /api/\d+$')))],
        );

        expect(result, isFalse);
      });

      test('supports case insensitive regex', () {
        final result = isSpanIgnored(
          'GET /HEALTH',
          {},
          [
            IgnoreSpanFilter.name(
                NameMatcher.regexp(RegExp(r'health', caseSensitive: false)))
          ],
        );

        expect(result, isTrue);
      });
    });

    group('with exact attribute matching (raw values)', () {
      test('matches string attribute exactly', () {
        final result = isSpanIgnored(
          'span',
          {'http.method': SentryAttribute.string('GET')},
          [
            IgnoreSpanFilter.where(
              attributes: {'http.method': 'GET'},
            )
          ],
        );

        expect(result, isTrue);
      });

      test('matches integer attribute exactly', () {
        final result = isSpanIgnored(
          'span',
          {'http.status_code': SentryAttribute.int(200)},
          [
            IgnoreSpanFilter.where(
              attributes: {'http.status_code': 200},
            )
          ],
        );

        expect(result, isTrue);
      });

      test('matches boolean attribute exactly', () {
        final result = isSpanIgnored(
          'span',
          {'is_cached': SentryAttribute.bool(true)},
          [
            IgnoreSpanFilter.where(
              attributes: {'is_cached': true},
            )
          ],
        );

        expect(result, isTrue);
      });

      test('matches double attribute exactly', () {
        final result = isSpanIgnored(
          'span',
          {'duration': SentryAttribute.double(1.5)},
          [
            IgnoreSpanFilter.where(
              attributes: {'duration': 1.5},
            )
          ],
        );

        expect(result, isTrue);
      });

      test('does not match when values differ', () {
        final result = isSpanIgnored(
          'span',
          {'http.status_code': SentryAttribute.int(500)},
          [
            IgnoreSpanFilter.where(
              attributes: {'http.status_code': 200},
            )
          ],
        );

        expect(result, isFalse);
      });

      test('does not match when attribute is missing', () {
        final result = isSpanIgnored(
          'span',
          {},
          [
            IgnoreSpanFilter.where(
              attributes: {'http.method': 'GET'},
            )
          ],
        );

        expect(result, isFalse);
      });
    });

    group('with AttrMatcher.contains', () {
      test('matches when string attribute contains the value', () {
        final result = isSpanIgnored(
          'span',
          {'http.url': SentryAttribute.string('https://example.com/api/health')},
          [
            IgnoreSpanFilter.where(
              attributes: {'http.url': AttrMatcher.contains('/health')},
            )
          ],
        );

        expect(result, isTrue);
      });

      test('does not match non-string attributes', () {
        final result = isSpanIgnored(
          'span',
          {'http.status_code': SentryAttribute.int(200)},
          [
            IgnoreSpanFilter.where(
              attributes: {'http.status_code': AttrMatcher.contains('200')},
            )
          ],
        );

        expect(result, isFalse);
      });
    });

    group('with AttrMatcher.regexp', () {
      test('matches when string attribute matches regex', () {
        final result = isSpanIgnored(
          'span',
          {'http.url': SentryAttribute.string('https://example.com/v2/users')},
          [
            IgnoreSpanFilter.where(
              attributes: {'http.url': AttrMatcher.regexp(RegExp(r'/v\d+/'))},
            )
          ],
        );

        expect(result, isTrue);
      });

      test('does not match non-string attributes', () {
        final result = isSpanIgnored(
          'span',
          {'http.status_code': SentryAttribute.int(200)},
          [
            IgnoreSpanFilter.where(
              attributes: {'http.status_code': AttrMatcher.regexp(RegExp(r'2\d\d'))},
            )
          ],
        );

        expect(result, isFalse);
      });
    });

    group('with combined name and attributes filter', () {
      test('matches when both name and all attributes match', () {
        final result = isSpanIgnored(
          'GET /healthz',
          {
            'http.method': SentryAttribute.string('GET'),
            'http.status_code': SentryAttribute.int(200),
          },
          [
            IgnoreSpanFilter.where(
              name: NameMatcher.contains('/health'),
              attributes: {
                'http.method': 'GET',
                'http.status_code': 200,
              },
            )
          ],
        );

        expect(result, isTrue);
      });

      test('does not match when name matches but attributes do not', () {
        final result = isSpanIgnored(
          'GET /healthz',
          {
            'http.method': SentryAttribute.string('POST'),
          },
          [
            IgnoreSpanFilter.where(
              name: NameMatcher.contains('/health'),
              attributes: {
                'http.method': 'GET',
              },
            )
          ],
        );

        expect(result, isFalse);
      });

      test('does not match when attributes match but name does not', () {
        final result = isSpanIgnored(
          'GET /users',
          {
            'http.method': SentryAttribute.string('GET'),
          },
          [
            IgnoreSpanFilter.where(
              name: NameMatcher.contains('/health'),
              attributes: {
                'http.method': 'GET',
              },
            )
          ],
        );

        expect(result, isFalse);
      });
    });

    group('with multiple filters', () {
      test('matches if any filter matches', () {
        final result = isSpanIgnored(
          'GET /metrics',
          {},
          [
            IgnoreSpanFilter.name(NameMatcher.contains('health')),
            IgnoreSpanFilter.name(NameMatcher.contains('metrics')),
          ],
        );

        expect(result, isTrue);
      });

      test('does not match if no filter matches', () {
        final result = isSpanIgnored(
          'GET /users',
          {},
          [
            IgnoreSpanFilter.name(NameMatcher.contains('health')),
            IgnoreSpanFilter.name(NameMatcher.contains('metrics')),
          ],
        );

        expect(result, isFalse);
      });
    });

    group('with empty filters list', () {
      test('does not match any span', () {
        final result = isSpanIgnored(
          'any-span',
          {'any': SentryAttribute.string('value')},
          [],
        );

        expect(result, isFalse);
      });
    });
  });
}
