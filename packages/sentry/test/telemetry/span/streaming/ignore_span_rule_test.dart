import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('IgnoreSpanRule', () {
    group('nameContains', () {
      group('with string pattern', () {
        test('matches when name contains substring', () {
          final rule = IgnoreSpanRule.nameContains('http');

          expect(rule.appliesToName('http.client'), isTrue);
          expect(rule.appliesToName('my-http-request'), isTrue);
          expect(rule.appliesToName('send-http'), isTrue);
        });

        test('does not match when name lacks substring', () {
          final rule = IgnoreSpanRule.nameContains('http');

          expect(rule.appliesToName('db.query'), isFalse);
          expect(rule.appliesToName('file.read'), isFalse);
        });

        test('matches exact name', () {
          final rule = IgnoreSpanRule.nameContains('http');

          expect(rule.appliesToName('http'), isTrue);
        });

        test('does not match empty name', () {
          final rule = IgnoreSpanRule.nameContains('http');

          expect(rule.appliesToName(''), isFalse);
        });
      });

      group('with regex pattern', () {
        test('matches when name contains regex match', () {
          final rule = IgnoreSpanRule.nameContains(RegExp(r'http\.\w+'));

          expect(rule.appliesToName('http.client'), isTrue);
          expect(rule.appliesToName('prefix-http.get-suffix'), isTrue);
        });

        test('does not match when regex does not match', () {
          final rule = IgnoreSpanRule.nameContains(RegExp(r'http\.\w+'));

          expect(rule.appliesToName('http.'), isFalse);
          expect(rule.appliesToName('db.query'), isFalse);
        });
      });
    });

    group('nameEquals', () {
      test('matches when name equals value exactly', () {
        final rule = IgnoreSpanRule.nameEquals('http.client');

        expect(rule.appliesToName('http.client'), isTrue);
      });

      test('does not match partial names', () {
        final rule = IgnoreSpanRule.nameEquals('http.client');

        expect(rule.appliesToName('http.client.get'), isFalse);
        expect(rule.appliesToName('http'), isFalse);
        expect(rule.appliesToName('my-http.client'), isFalse);
      });

      test('is case-sensitive', () {
        final rule = IgnoreSpanRule.nameEquals('HTTP.client');

        expect(rule.appliesToName('http.client'), isFalse);
        expect(rule.appliesToName('HTTP.client'), isTrue);
      });

      test('does not match empty name', () {
        final rule = IgnoreSpanRule.nameEquals('http.client');

        expect(rule.appliesToName(''), isFalse);
      });

      test('matches empty value against empty name', () {
        final rule = IgnoreSpanRule.nameEquals('');

        expect(rule.appliesToName(''), isTrue);
      });
    });

    group('nameStartsWith', () {
      group('with string pattern', () {
        test('matches when name starts with prefix', () {
          final rule = IgnoreSpanRule.nameStartsWith('http');

          expect(rule.appliesToName('http.client'), isTrue);
          expect(rule.appliesToName('http'), isTrue);
          expect(rule.appliesToName('http.get'), isTrue);
        });

        test('does not match when name does not start with prefix', () {
          final rule = IgnoreSpanRule.nameStartsWith('http');

          expect(rule.appliesToName('my-http'), isFalse);
          expect(rule.appliesToName('db.query'), isFalse);
        });
      });

      group('with regex pattern', () {
        test('matches when name starts with regex match', () {
          final rule = IgnoreSpanRule.nameStartsWith(RegExp(r'(http|grpc)\.'));

          expect(rule.appliesToName('http.client'), isTrue);
          expect(rule.appliesToName('grpc.call'), isTrue);
        });

        test('does not match when regex matches later in name', () {
          final rule = IgnoreSpanRule.nameStartsWith(RegExp(r'http\.'));

          expect(rule.appliesToName('prefix-http.client'), isFalse);
        });
      });
    });

    group('nameEndsWith', () {
      test('matches when name ends with suffix', () {
        final rule = IgnoreSpanRule.nameEndsWith('.query');

        expect(rule.appliesToName('db.query'), isTrue);
        expect(rule.appliesToName('sql.query'), isTrue);
        expect(rule.appliesToName('.query'), isTrue);
      });

      test('does not match when name does not end with suffix', () {
        final rule = IgnoreSpanRule.nameEndsWith('.query');

        expect(rule.appliesToName('db.query.execute'), isFalse);
        expect(rule.appliesToName('query'), isFalse);
      });

      test('matches exact name equal to suffix', () {
        final rule = IgnoreSpanRule.nameEndsWith('query');

        expect(rule.appliesToName('query'), isTrue);
      });

      test('does not match empty name', () {
        final rule = IgnoreSpanRule.nameEndsWith('.query');

        expect(rule.appliesToName(''), isFalse);
      });
    });
  });
}
