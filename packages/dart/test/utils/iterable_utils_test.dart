import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('SentryIterableUtils', () {
    group('firstOrNull', () {
      test('returns null for a null iterable', () {
        final iterable = null as Iterable<int>?;

        expect(iterable.firstOrNull, isNull);
      });

      test('returns null for an empty iterable', () {
        expect(<int>[].firstOrNull, isNull);
      });

      test('returns the first item', () {
        expect([1, 2, 3].firstOrNull, 1);
      });
    });

    group('firstWhereOrNull', () {
      test('returns null for a null iterable', () {
        final iterable = null as Iterable<int>?;

        expect(iterable.firstWhereOrNull((item) => item.isEven), isNull);
      });

      test('returns null when no item matches', () {
        expect(
          [1, 3, 5].firstWhereOrNull((item) => item.isEven),
          isNull,
        );
      });

      test('returns the first matching item', () {
        expect(
          [1, 2, 4].firstWhereOrNull((item) => item.isEven),
          2,
        );
      });
    });
  });
}
