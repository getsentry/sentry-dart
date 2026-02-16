import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('IgnoreSpanRule', () {
    group('nameContains', () {
      group('with string pattern', () {
        test('matches when name contains substring', () {
          final rule = IgnoreSpanRule.nameContains('http');

          expect(rule.nameMatches('http.client'), isTrue);
          expect(rule.nameMatches('my-http-request'), isTrue);
          expect(rule.nameMatches('send-http'), isTrue);
        });

        test('does not match when name lacks substring', () {
          final rule = IgnoreSpanRule.nameContains('http');

          expect(rule.nameMatches('db.query'), isFalse);
          expect(rule.nameMatches('file.read'), isFalse);
        });

        test('matches exact name', () {
          final rule = IgnoreSpanRule.nameContains('http');

          expect(rule.nameMatches('http'), isTrue);
        });

        test('does not match empty name', () {
          final rule = IgnoreSpanRule.nameContains('http');

          expect(rule.nameMatches(''), isFalse);
        });
      });

      group('with regex pattern', () {
        test('matches when name contains regex match', () {
          final rule = IgnoreSpanRule.nameContains(RegExp(r'http\.\w+'));

          expect(rule.nameMatches('http.client'), isTrue);
          expect(rule.nameMatches('prefix-http.get-suffix'), isTrue);
        });

        test('does not match when regex does not match', () {
          final rule = IgnoreSpanRule.nameContains(RegExp(r'http\.\w+'));

          expect(rule.nameMatches('http.'), isFalse);
          expect(rule.nameMatches('db.query'), isFalse);
        });
      });
    });

    group('nameEquals', () {
      test('matches when name equals value exactly', () {
        final rule = IgnoreSpanRule.nameEquals('http.client');

        expect(rule.nameMatches('http.client'), isTrue);
      });

      test('does not match partial names', () {
        final rule = IgnoreSpanRule.nameEquals('http.client');

        expect(rule.nameMatches('http.client.get'), isFalse);
        expect(rule.nameMatches('http'), isFalse);
        expect(rule.nameMatches('my-http.client'), isFalse);
      });

      test('is case-sensitive', () {
        final rule = IgnoreSpanRule.nameEquals('HTTP.client');

        expect(rule.nameMatches('http.client'), isFalse);
        expect(rule.nameMatches('HTTP.client'), isTrue);
      });

      test('does not match empty name', () {
        final rule = IgnoreSpanRule.nameEquals('http.client');

        expect(rule.nameMatches(''), isFalse);
      });

      test('matches empty value against empty name', () {
        final rule = IgnoreSpanRule.nameEquals('');

        expect(rule.nameMatches(''), isTrue);
      });
    });

    group('nameStartsWith', () {
      group('with string pattern', () {
        test('matches when name starts with prefix', () {
          final rule = IgnoreSpanRule.nameStartsWith('http');

          expect(rule.nameMatches('http.client'), isTrue);
          expect(rule.nameMatches('http'), isTrue);
          expect(rule.nameMatches('http.get'), isTrue);
        });

        test('does not match when name does not start with prefix', () {
          final rule = IgnoreSpanRule.nameStartsWith('http');

          expect(rule.nameMatches('my-http'), isFalse);
          expect(rule.nameMatches('db.query'), isFalse);
        });
      });

      group('with regex pattern', () {
        test('matches when name starts with regex match', () {
          final rule =
              IgnoreSpanRule.nameStartsWith(RegExp(r'(http|grpc)\.'));

          expect(rule.nameMatches('http.client'), isTrue);
          expect(rule.nameMatches('grpc.call'), isTrue);
        });

        test('does not match when regex matches later in name', () {
          final rule = IgnoreSpanRule.nameStartsWith(RegExp(r'http\.'));

          expect(rule.nameMatches('prefix-http.client'), isFalse);
        });
      });
    });

    group('nameEndsWith', () {
      test('matches when name ends with suffix', () {
        final rule = IgnoreSpanRule.nameEndsWith('.query');

        expect(rule.nameMatches('db.query'), isTrue);
        expect(rule.nameMatches('sql.query'), isTrue);
        expect(rule.nameMatches('.query'), isTrue);
      });

      test('does not match when name does not end with suffix', () {
        final rule = IgnoreSpanRule.nameEndsWith('.query');

        expect(rule.nameMatches('db.query.execute'), isFalse);
        expect(rule.nameMatches('query'), isFalse);
      });

      test('matches exact name equal to suffix', () {
        final rule = IgnoreSpanRule.nameEndsWith('query');

        expect(rule.nameMatches('query'), isTrue);
      });

      test('does not match empty name', () {
        final rule = IgnoreSpanRule.nameEndsWith('.query');

        expect(rule.nameMatches(''), isFalse);
      });
    });
  });
}
